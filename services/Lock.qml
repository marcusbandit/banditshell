pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam
import qs.config
import "lock-hint.js" as LockHint

Singleton {
    id: root

    property bool active: false

    property bool opening: false

    property bool secure: false

    property bool hinted: false

    property bool toldLogind: false

    readonly property string recordPath: Quickshell.env("XDG_RUNTIME_DIR") ? `${Quickshell.env("XDG_RUNTIME_DIR")}/banditshell-lock-hint.json` : ""

    readonly property bool busy: pam.active

    readonly property int typed: entry.secret.length

    property string message: ""

    property bool failed: false

    property bool awake: true

    readonly property int restAfter: Config.values.lock.restAfter * 1000

    signal sent(int marks)
    signal refused

    readonly property int freeAttempts: 3
    readonly property int firstWait: 5000
    readonly property int longestWait: 60000

    readonly property int verdictWait: Config.values.lock.verdict
    readonly property int foldDeadline: 2000
    readonly property int xrayDeadline: 400
    readonly property int xrayLinger: 1000

    property real now: Date.now()

    readonly property int waitSeconds: Math.max(0, Math.ceil((attempts.retryAt - root.now) / 1000))
    readonly property bool waiting: root.waitSeconds > 0

    readonly property string user: Quickshell.env("USER")

    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID")

    property string sessionPath: ""

    readonly property int quickestRestart: 1000
    readonly property int slowestRestart: 60000

    property int monitorDelay: root.quickestRestart

    property int inhibitorDelay: root.quickestRestart

    property bool sleeping: false

    readonly property int sleepDeadline: 3000

    property bool arming: false

    property bool releasing: false

    property bool seeingThrough: false

    QtObject {
        id: entry

        property string secret: ""
        property string answer: ""
        property var queue: []
        property bool judged: false
    }

    function forget(): void {
        entry.secret = "";
        entry.answer = "";
        entry.queue = [];
        entry.judged = false;
        verdict.stop();
    }

    Connections {
        target: SessionControl

        function onLockRequested(): void {
            root.lock();
        }
    }

    Binding {
        target: SessionControl
        property: "sleeping"
        value: root.sleeping
    }

    function lock(): void {
        if (root.opening || root.releasing) {
            root.opening = false;
            root.releasing = false;
            fold.stop();
            return;
        }
        if (root.active || root.arming)
            return;
        if (root.sleeping) {
            root.relock();
            return;
        }
        root.forget();
        root.message = "";
        root.failed = false;
        root.stir();
        root.arming = true;
        root.seeThrough(true, () => {
            if (!root.arming) {
                root.seeThrough(false, null);
                return;
            }
            root.arming = false;
            root.active = true;
        });
    }

    function relock(): void {
        if (root.active || root.arming)
            return;
        root.forget();
        root.message = "";
        root.failed = false;
        root.stir();
        if (root.seeingThrough)
            root.seeThrough(false, null);
        root.active = true;
    }

    function release(): void {
        if (root.arming) {
            root.arming = false;
            return;
        }
        if (!root.active || root.opening || root.releasing)
            return;
        pam.abort();
        root.forget();
        root.releasing = true;
        root.seeThrough(true, () => {
            if (!root.active)
                return;
            if (!root.releasing) {
                root.seeThrough(false, null);
                return;
            }
            root.releasing = false;
            root.opening = true;
            fold.restart();
        });
    }

    function covered(): void {
        if (root.active && !root.opening && root.seeingThrough)
            root.seeThrough(false, null);
    }

    function opened(): void {
        if (root.opening)
            root.finish();
    }

    function seeThrough(on: bool, then: var): void {
        const command = CompositorSync.lockXrayCommand(on);
        root.seeingThrough = on && command.length > 0;
        if (!command.length) {
            if (then)
                then();
            return;
        }
        if (!on) {
            Quickshell.execDetached(command);
            return;
        }
        xray.after = then;
        xray.command = command;
        xray.running = true;
        xrayCap.restart();
    }

    function observe(locked: bool, secure: bool): void {
        root.secure = root.active && locked && secure;
        if (root.active && !locked) {
            root.finish();
            return;
        }
        if (root.secure && !root.hinted)
            root.tellLogind(true);
        root.letSleep();
    }

    function finish(): void {
        pam.abort();
        root.forget();
        fold.stop();
        root.message = "";
        root.failed = false;
        attempts.failures = 0;
        attempts.retryAt = 0;
        root.secure = false;
        root.opening = false;
        root.releasing = false;
        root.active = false;
        if (root.hinted)
            root.tellLogind(false);
        root.letSleep();
        if (root.seeingThrough)
            xrayRest.restart();
    }

    function prepareForSleep(going: bool): void {
        root.sleeping = going;
        if (!going) {
            sleepCap.stop();
            inhibitor.running = true;
            return;
        }
        root.lock();
        sleepCap.restart();
        root.letSleep();
    }

    function letSleep(): void {
        if (!root.sleeping || root.arming || (root.active && !root.secure))
            return;
        sleepCap.stop();
        inhibitor.running = false;
    }

    function stir(): void {
        root.awake = true;
        rest.restart();
    }

    function type(text: string): void {
        root.stir();
        if (!root.active || root.opening || !text || /[\u0000-\u001f\u007f-\u009f]/.test(text))
            return;
        entry.secret += text;
    }

    function erase(all: bool): void {
        root.stir();
        entry.secret = all ? "" : entry.secret.slice(0, -1);
    }

    function enter(): bool {
        root.stir();
        if (!root.active || root.opening || !entry.secret)
            return false;

        root.tick();
        if (root.waiting)
            return false;

        const secret = entry.secret;
        entry.secret = "";
        root.sent(secret.length);

        if (pam.active)
            entry.queue = entry.queue.concat([secret]);
        else
            root.check(secret);
        return true;
    }

    function check(secret: string): void {
        entry.answer = secret;
        entry.judged = false;
        verdict.restart();

        if (!pam.start()) {
            entry.answer = "";
            root.refuse("couldn't check the password, try again", false);
        }
    }

    function next(): void {
        if (!root.active || root.opening || pam.active || !entry.queue.length)
            return;
        root.tick();
        if (root.waiting)
            return;
        const secret = entry.queue[0];
        entry.queue = entry.queue.slice(1);
        root.check(secret);
    }

    function refuse(text: string, counts: bool): void {
        verdict.stop();
        entry.judged = true;
        root.failed = true;
        root.message = text;
        if (counts)
            root.countFailure();
        root.refused();
    }

    function settle(text: string, counts: bool): void {
        entry.answer = "";
        if (!root.active || root.opening || root.releasing)
            return;
        if (!entry.judged)
            root.refuse(text, counts);
        Qt.callLater(root.next);
    }

    function tick(): void {
        root.now = Date.now();
        attempts.retryAt = Math.min(attempts.retryAt, root.now + root.longestWait);
    }

    function countFailure(): void {
        attempts.failures += 1;
        const beyond = attempts.failures - root.freeAttempts;
        if (beyond < 0)
            return;
        root.now = Date.now();
        attempts.retryAt = root.now + Math.min(root.firstWait * Math.pow(2, beyond), root.longestWait);
    }

    Timer {
        id: rest

        interval: root.restAfter
        onTriggered: root.awake = false
    }

    Timer {
        id: verdict

        interval: root.verdictWait
        onTriggered: if (pam.active && !entry.judged)
            root.refuse("wrong password", true)
    }

    Timer {
        id: fold

        interval: root.foldDeadline
        onTriggered: root.opened()
    }

    Process {
        id: xray

        property var after: null

        function proceed(): void {
            xrayCap.stop();
            const then = xray.after;
            xray.after = null;
            if (then)
                then();
        }

        onRunningChanged: if (!xray.running)
            xray.proceed()
    }

    Timer {
        id: xrayCap

        interval: root.xrayDeadline
        onTriggered: xray.proceed()
    }

    Timer {
        id: xrayRest

        interval: root.xrayLinger
        onTriggered: if (!root.active)
            root.seeThrough(false, null)
    }

    function tellLogind(on: bool): void {
        root.hinted = on;
        root.toldLogind = true;
        root.sendHint();
    }

    function sendHint(): void {
        if (!root.sessionPath)
            return;
        if (root.recordPath)
            record.setText(LockHint.recordText(root.sessionPath, root.hinted));
        if (hint.running) {
            hint.stale = true;
            return;
        }
        hint.command = ["busctl", "call", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "SetLockedHint", "b", root.hinted ? "true" : "false"];
        hint.running = true;
    }

    function reply(text: string): var {
        try {
            return JSON.parse(text)?.data;
        } catch (e) {
            return undefined;
        }
    }

    function placeSession(text: string): void {
        const path = root.reply(text)?.[0];
        if (typeof path !== "string" || !path.startsWith("/org/freedesktop/login1/session/"))
            return;
        root.sessionPath = path;
        probe.running = true;
        if (root.toldLogind)
            root.sendHint();
    }

    function hear(line: string): void {
        const heard = /^(\/[\w\/]*): ([\w.]+)\.(\w+) \((.*)\)$/.exec(line);
        if (!heard)
            return;
        const [, path, interfaceName, member, body] = heard;
        if (path === "/org/freedesktop/login1" && interfaceName === "org.freedesktop.login1.Manager" && member === "PrepareForSleep") {
            root.prepareForSleep(body.startsWith("true"));
            return;
        }
        if (!root.sessionPath || path !== root.sessionPath || interfaceName !== "org.freedesktop.login1.Session")
            return;
        if (member === "Lock")
            root.lock();
        else if (member === "Unlock")
            root.release();
    }

    PersistentProperties {
        id: attempts

        reloadableId: "lockAttempts"

        property int failures: 0
        property real retryAt: 0

        onReloaded: root.tick()
    }

    Timer {
        running: attempts.retryAt > root.now
        interval: 250
        repeat: true
        onTriggered: {
            root.tick();
            root.next();
        }
    }

    Process {
        id: hint

        property bool stale: false

        onRunningChanged: if (!hint.running && hint.stale) {
            hint.stale = false;
            root.sendHint();
        }
    }

    Process {
        id: lookup

        running: SessionControl.logind
        command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "GetSession", "s", root.sessionId || "auto"]

        stdout: StdioCollector {
            id: lookupReply
        }

        onExited: code => {
            if (code === 0)
                root.placeSession(lookupReply.text);
        }

        onRunningChanged: if (!lookup.running && !root.sessionPath && SessionControl.logind)
            lookupRetry.restart()
    }

    Timer {
        id: lookupRetry

        interval: 5000
        onTriggered: if (SessionControl.logind)
            lookup.running = true
    }

    Process {
        id: probe

        command: ["busctl", "--json=short", "get-property", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "LockedHint"]

        stdout: StdioCollector {
            id: probeReply
        }

        onExited: code => {
            if (code !== 0)
                return;
            if (root.recordPath)
                record.reload();
            const told = root.recordPath ? LockHint.readRecord(record.text(), root.sessionPath) : null;
            const action = LockHint.onStart(root.reply(probeReply.text), told, root.active || root.arming);
            if (action === "relock")
                root.relock();
            else if (action === "clear")
                root.tellLogind(false);
        }
    }

    FileView {
        id: record

        path: root.recordPath
        blockLoading: true
        blockWrites: true
        printErrors: false
    }

    Process {
        id: monitor

        running: SessionControl.logind
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]

        stdout: SplitParser {
            onRead: line => root.hear(line)
        }

        onRunningChanged: if (!monitor.running && SessionControl.logind)
            monitorRestart.restart()
    }

    Timer {
        id: monitorRestart

        interval: root.monitorDelay
        onTriggered: {
            root.monitorDelay = Math.min(root.monitorDelay * 2, root.slowestRestart);
            monitor.running = SessionControl.logind;
        }
    }

    Timer {
        running: monitor.running
        interval: root.slowestRestart
        onTriggered: root.monitorDelay = root.quickestRestart
    }

    Process {
        id: inhibitor

        running: SessionControl.logind
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=banditshell", "--why=locking the screen", "cat"]
        stdinEnabled: true

        onRunningChanged: if (!inhibitor.running && !root.sleeping && SessionControl.logind)
            inhibitorRestart.restart()
    }

    Timer {
        id: inhibitorRestart

        interval: root.inhibitorDelay
        onTriggered: {
            root.inhibitorDelay = Math.min(root.inhibitorDelay * 2, root.slowestRestart);
            if (!root.sleeping && SessionControl.logind)
                inhibitor.running = true;
        }
    }

    Timer {
        running: inhibitor.running
        interval: root.slowestRestart
        onTriggered: root.inhibitorDelay = root.quickestRestart
    }

    Timer {
        id: sleepCap

        interval: root.sleepDeadline
        onTriggered: inhibitor.running = false
    }

    PamContext {
        id: pam

        config: "banditshell"

        configDirectory: Quickshell.shellPath("assets/pam.d")

        onResponseRequiredChanged: {
            if (!pam.responseRequired)
                return;
            pam.respond(entry.answer);
            entry.answer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                verdict.stop();
                root.release();
                return;
            }

            if (res === PamResult.Error)
                root.settle("couldn't check the password, try again", false);
            else
                root.settle(res === PamResult.MaxTries ? "too many tries" : "wrong password", true);
        }

        onError: err => {
            console.warn(`Lock: PAM failed: ${PamError.toString(err)}`);
            root.settle("couldn't check the password, try again", false);
        }
    }
}
