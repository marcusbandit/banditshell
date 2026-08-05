pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

// WHETHER THE SCREEN IS LOCKED, and everything that decides it.
//
// Here rather than in the thing that draws it, for the same reason Power is:
// four different things ask for a lock (the power panel, the CLI, a keybind,
// and logind on behalf of a lid switch or a suspend), and a state that lives in
// a surface is a state that does not exist until that surface does.
//
// It is also the only file that knows a password. `pending` holds one for the
// few microseconds between Enter and PAM asking for it, and is cleared the
// instant it is handed over; nothing else in the shell ever sees it, and the
// field that took it clears itself on the same keystroke.
//
// THE ONE RULE FOR EVERYTHING BELOW: a lock screen that cannot be released is
// worse than no lock screen at all, because the way out is a TTY. So every
// path that could get stuck is either absent (there is no exit animation
// between "PAM said yes" and the lock coming down) or has a way past it that
// does not involve this process being healthy (logind's Unlock, which arrives
// over the system bus and is honoured below).
Singleton {
    id: root

    // The one piece of state. modules/lock/LockScreen.qml follows it onto the
    // compositor; nothing else may write it except through lock() and release().
    property bool active: false

    // PAM, mid-question. The field goes quiet rather than queueing keystrokes:
    // a second Enter while the first is still being checked is a second full
    // attempt, and pam_faillock counts it.
    readonly property bool busy: pam.active

    // What to say under the field. "" is the resting state.
    property string message: ""

    // Whether that message is a refusal rather than a remark. Only this earns
    // the accent; see modules/lock/LockSurface.qml.
    property bool failed: false

    // PAM has stopped answering, which on this stack means pam_faillock has
    // seen enough. The screen stays up and the field stops taking guesses,
    // because offering a box that cannot succeed is a lie.
    property bool exhausted: false

    // The password, held between pressing Enter and PAM asking for it.
    property string pending: ""

    readonly property string user: Quickshell.env("USER")

    // OUR session's object path on the system bus, worked out rather than
    // hardcoded: logind escapes the session id into the path, and a shell that
    // assumed session 2 would listen to someone else's lock on any box where it
    // is not. Path elements cannot start with a digit, so systemd writes the
    // whole id as "_" followed by the hex of each character: "2" is "_32",
    // "10" is "_3130".
    //
    // "auto" is logind's own name for "whichever session is asking", and is the
    // honest fallback for the case where the shell was started somewhere that
    // XDG_SESSION_ID did not reach.
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

    // Everything that takes the screen down goes through here, including PAM
    // succeeding, so there is exactly one place that can be wrong about it.
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
        // `exhausted` is checked here rather than only in the field, because the
        // field is one of several things that can call this and the refusal
        // belongs to the state, not to the widget.
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

    // Tell logind what the screen is doing. Nothing in this shell reads it, but
    // the rest of the system does: it is how `loginctl` can say whether a
    // session is locked, and how anything that cares (a status tool, a remote
    // session, a future idle daemon) finds out without asking the shell.
    //
    // Fire and forget. It is a courtesy to other software, and a lock screen
    // must not wait on a bus call to put itself up.
    function tellLogind(on: bool): void {
        hint.command = ["busctl", "call", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "SetLockedHint", "b", on ? "true" : "false"];
        hint.running = true;
    }

    Process {
        id: hint
    }

    // WAS THE SCREEN LOCKED WHEN THIS PROCESS LAST STOPPED EXISTING?
    //
    // If the shell is restarted while the session is locked - a crash, a reload,
    // `banditshell restart` from a TTY - the compositor keeps the session locked
    // whether or not anything is drawing, because the protocol requires it. What
    // it does NOT do is put the field back, so without this the screen comes
    // back locked with nothing to type into and the only way out is a TTY.
    //
    // Asking logind rather than remembering it in a file: the hint is the
    // system's own answer and survives exactly the events that would destroy a
    // file we wrote, which are the same events this is here for.
    Process {
        id: probe

        running: true
        command: ["busctl", "get-property", "org.freedesktop.login1", root.sessionPath, "org.freedesktop.login1.Session", "LockedHint"]

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "b true")
                root.lock()
        }
    }

    // LOGINCTL, HEARD RATHER THAN POLLED.
    //
    // `loginctl lock-session` is how everything else on the system asks for a
    // lock: services/Power.qml's own entry, a lid switch, systemd before it
    // suspends. All any of them does is emit a signal on the system bus, and
    // Quickshell 0.3 has no DBus binding in QML, so this listens through a pipe.
    //
    // `busctl monitor` is the obvious tool for it and is refused: BecomeMonitor
    // is privileged, and a user session is not allowed to eavesdrop. gdbus asks
    // for a plain match instead, which it is allowed, and prints one line per
    // signal.
    //
    // Unlock is honoured as well as Lock, and that is deliberate. It makes
    // `loginctl unlock-session` the documented way back in from a TTY or an SSH
    // session, which is a far better recovery path than killing the shell and
    // leaving the compositor holding a lock nothing is drawing. It costs
    // nothing at the keyboard: reaching the system bus at all means already
    // running as this user, which is the thing the locked screen is preventing.
    Process {
        id: logind

        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1"]

        stdout: SplitParser {
            onRead: line => {
                // Matched against OUR session's path. --dest narrows this to
                // logind, not to us, so on a box with a second session every
                // one of its locks would arrive here too.
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
        // Resolved against the shell root, so the config that ships with the
        // repo is the config that is used. See assets/pam.d/banditshell.
        configDirectory: Quickshell.shellPath("assets/pam.d")
        user: root.user

        // The password is handed over HERE rather than at start(), because PAM
        // decides when it wants one and a stack can ask for none, one, or
        // several. Cleared on the same line it is used: the window in which this
        // shell holds a plaintext password is this function.
        onResponseRequiredChanged: {
            if (!pam.responseRequired)
                return;
            pam.respond(root.pending);
            root.pending = "";
        }

        // PAM's own words, kept only when they say something the shell cannot
        // work out for itself. "Password: " is a prompt for a field that is
        // already visibly a password field; "The account is locked due to N
        // failed logins" is the one thing a person needs and cannot guess.
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
                // Only if pam had nothing better to say; onMessageChanged above
                // may already have put the faillock countdown here.
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
