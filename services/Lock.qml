pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Singleton {
    id: root

    property bool active: false

    property bool secure: false

    property bool hinted: false

    readonly property bool busy: pam.active

    property string message: ""

    property bool failed: false

    property string pending: ""

    readonly property int freeAttempts: 3
    readonly property int firstWait: 5000
    readonly property int longestWait: 60000

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

    function lock(): void {
        if (root.active)
            return;
        root.message = "";
        root.failed = false;
        root.pending = "";
        root.active = true;
    }

    function release(): void {
        if (!root.active)
            return;
        root.finish();
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
        root.pending = "";
        root.message = "";
        root.failed = false;
        attempts.failures = 0;
        attempts.retryAt = 0;
        root.secure = false;
        root.active = false;
        if (root.hinted)
            root.tellLogind(false);
        root.letSleep();
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
        if (!root.sleeping || (root.active && !root.secure))
            return;
        sleepCap.stop();
        inhibitor.running = false;
    }

    function submit(secret: string): bool {
        if (!root.active || root.busy || !secret)
            return false;

        root.tick();
        if (attempts.retryAt > root.now)
            return false;

        root.pending = secret;
        root.failed = false;
        root.message = "checking";

        if (!pam.start()) {
            root.pending = "";
            root.failed = true;
            root.message = "cannot reach PAM";
        }
        return true;
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

    function tellLogind(on: bool): void {
        root.hinted = on;
        root.sendHint();
    }

    function sendHint(): void {
        if (!root.sessionPath)
            return;
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
        if (root.hinted)
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
        onTriggered: root.tick()
    }

    Process {
        id: hint
    }

    Process {
        id: lookup

        running: true
        command: ["busctl", "--json=short", "call", "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "GetSession", "s", root.sessionId || "auto"]

        stdout: StdioCollector {
            id: lookupReply
        }

        onExited: code => {
            if (code === 0)
                root.placeSession(lookupReply.text);
        }

        onRunningChanged: if (!lookup.running && !root.sessionPath)
            lookupRetry.restart()
    }

    Timer {
        id: lookupRetry

        interval: 5000
        onTriggered: lookup.running = true
    }

    Process {
        id: probe

        command: ["busctl", "--json=short", "get-property", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "LockedHint"]

        stdout: StdioCollector {
            id: probeReply
        }

        onExited: code => {
            if (code === 0 && root.reply(probeReply.text) === true)
                root.lock();
        }
    }

    Process {
        id: monitor

        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]

        stdout: SplitParser {
            onRead: line => root.hear(line)
        }

        onRunningChanged: if (!monitor.running)
            monitorRestart.restart()
    }

    Timer {
        id: monitorRestart

        interval: root.monitorDelay
        onTriggered: {
            root.monitorDelay = Math.min(root.monitorDelay * 2, root.slowestRestart);
            monitor.running = true;
        }
    }

    Timer {
        running: monitor.running
        interval: root.slowestRestart
        onTriggered: root.monitorDelay = root.quickestRestart
    }

    Process {
        id: inhibitor

        running: true
        command: ["systemd-inhibit", "--what=sleep", "--mode=delay", "--who=banditshell", "--why=locking the screen", "cat"]
        stdinEnabled: true

        onRunningChanged: if (!inhibitor.running && !root.sleeping)
            inhibitorRestart.restart()
    }

    Timer {
        id: inhibitorRestart

        interval: root.inhibitorDelay
        onTriggered: {
            root.inhibitorDelay = Math.min(root.inhibitorDelay * 2, root.slowestRestart);
            if (!root.sleeping)
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
        user: root.user

        onResponseRequiredChanged: {
            if (!pam.responseRequired)
                return;
            pam.respond(root.pending);
            root.pending = "";
        }

        onCompleted: res => {
            root.pending = "";

            if (res === PamResult.Success) {
                root.release();
                return;
            }

            root.failed = true;

            if (res === PamResult.Error) {
                root.message = "authentication error";
                return;
            }

            root.message = res === PamResult.MaxTries ? "too many attempts" : "not your password";
            root.countFailure();
        }

        onError: err => {
            root.pending = "";
            root.failed = true;
            root.message = `pam error: ${PamError.toString(err)}`;
        }
    }
}
