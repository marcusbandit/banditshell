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

    property bool exhausted: false

    property string pending: ""

    readonly property string user: Quickshell.env("USER")

    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID")

    property string sessionPath: ""

    readonly property int quickestRestart: 1000
    readonly property int slowestRestart: 60000

    property int monitorDelay: root.quickestRestart

    function lock(): void {
        if (root.active)
            return;
        root.message = "";
        root.failed = false;
        root.exhausted = false;
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
    }

    function finish(): void {
        pam.abort();
        root.pending = "";
        root.message = "";
        root.failed = false;
        root.secure = false;
        root.active = false;
        if (root.hinted)
            root.tellLogind(false);
    }

    function submit(secret: string): void {

        if (!root.active || root.busy || root.exhausted)
            return;

        root.pending = secret;
        root.failed = false;
        root.message = "checking";

        if (!pam.start()) {
            root.pending = "";
            root.failed = true;
            root.message = "cannot reach PAM";
        }
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
        const [, path, interfaceName, member] = heard;
        if (!root.sessionPath || path !== root.sessionPath || interfaceName !== "org.freedesktop.login1.Session")
            return;
        if (member === "Lock")
            root.lock();
        else if (member === "Unlock")
            root.release();
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

        onMessageChanged: {
            if (pam.message.startsWith("The account is locked") || pam.message.endsWith(" left to unlock)"))
                root.message = pam.message;
        }

        onCompleted: res => {
            root.pending = "";

            if (res === PamResult.Success) {
                root.release();
                return;
            }

            root.failed = true;

            if (res === PamResult.MaxTries) {
                root.exhausted = true;
                root.message = "too many attempts";
            } else if (res === PamResult.Error) {
                root.message = "authentication error";
            } else if (!root.message || root.message === "checking") {

                root.message = "not your password";
            }
        }

        onError: err => {
            root.pending = "";
            root.failed = true;
            root.message = `pam error: ${PamError.toString(err)}`;
        }
    }
}
