pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

Singleton {
    id: root

    property bool active: false

    readonly property bool busy: pam.active

    property string message: ""

    property bool failed: false

    property bool exhausted: false

    property string pending: ""

    readonly property string user: Quickshell.env("USER")

    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID")
    readonly property string sessionPath: root.sessionId ? `/org/freedesktop/login1/session/_${Array.from(root.sessionId).map(c => c.charCodeAt(0).toString(16)).join("")}` : "/org/freedesktop/login1/session/auto"

    function lock(): void {
        if (root.active)
            return;
        root.message = "";
        root.failed = false;
        root.exhausted = false;
        root.pending = "";
        root.active = true;
        root.tellLogind(true);
    }

    function release(): void {
        if (!root.active)
            return;
        pam.abort();
        root.pending = "";
        root.message = "";
        root.failed = false;
        root.active = false;
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
        hint.command = ["busctl", "call", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "SetLockedHint", "b", on ? "true" : "false"];
        hint.running = true;
    }

    Process {
        id: hint
    }

    Process {
        id: probe

        running: true
        command: ["busctl", "get-property", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "LockedHint"]

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "b true")
                root.lock()
        }
    }

    Process {
        id: logind

        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]

        stdout: SplitParser {
            onRead: line => {

                if (!line.startsWith(`${root.sessionPath}:`))
                    return;

                if (line.includes(".Session.Lock ("))
                    root.lock();
                else if (line.includes(".Session.Unlock ("))
                    root.release();
            }
        }
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
