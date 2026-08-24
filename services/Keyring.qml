pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// THE KEYRING'S QUESTION, once the shell is the one asking it.
//
// gnome-keyring never draws anything. When it needs a passphrase it looks up
// `org.gnome.keyring.SystemPrompter` on the session bus and asks whoever owns
// that name to do the asking; with nobody there, D-Bus activates gcr's GTK
// dialog, which is the grey box this replaces. scripts/keyring-prompter.py owns
// the name instead and talks to this file over its pipes, so the question
// arrives here and modules/keyring/KeyringPrompt.qml draws it.
//
// A SERVICE AND NOT A PANEL, for the reason Lock and Power are: the state
// arrives from outside the shell, at a moment nothing on screen chose, and a
// state that lives in a surface does not exist until that surface does. It
// also has to survive the surface: the answer goes back over the bus whether or
// not the panel that collected it is still alive.
//
// IT IS THE SECOND FILE IN THIS SHELL THAT KNOWS A PASSWORD, and it holds one
// for less time than the first. services/Lock.qml keeps `pending` between Enter
// and PAM asking; here the secret is handed straight to the helper's stdin
// inside submit() and is not stored at all. Nothing logs it, and the field that
// took it clears itself on the same keystroke. The one thing that must never be
// added to this file is a console.log of what was typed: Quickshell writes its
// log to disk.
//
// ONE QUESTION AT A TIME, because the helper serialises them: gcr's own prompter
// runs in what it calls SINGLE mode and this keeps that, since two password
// fields on one screen is two ways to type the right secret into the wrong
// question.
Singleton {
    id: root

    // ---- WHAT IS BEING ASKED -------------------------------------------

    // Whether there is a question on screen at all. The panel follows this.
    property bool active: false

    // The helper's serial for the question. It goes back with the answer, so a
    // reply typed into a question that has since been withdrawn is dropped by
    // the helper rather than applied to whatever replaced it.
    property int serial: 0

    // HOW MANY QUESTIONS THERE HAVE BEEN, which is a different number from the
    // one above and exists because the field needs one the wire cannot supply.
    //
    // `serial` is the HELPER'S name for a question, and it is the right thing to
    // send back and the wrong thing to hang a field's "empty yourself" on: a
    // demo reuses a serial the helper could never issue, so two demos in a row
    // carried the same one and the second opened with the first one's marks
    // still in the field. That is a rejected password left sitting under
    // somebody's cursor, which is worse than it looks.
    //
    // This one only ever goes up, and it goes up for every question however it
    // arrived. The panel keys the field on it.
    property int asked: 0

    // "password" or "confirm". A confirm has no field: it is a yes/no about a
    // certificate or an unlock somebody else asked for.
    property string kind: ""

    property string title: ""
    property string message: ""
    property string description: ""

    // The one line that is a WARNING rather than a remark - "the password was
    // wrong", typically. It earns the accent; see the panel.
    property string warning: ""

    // The optional tickbox. "" means this question does not offer one, which is
    // the common case: gnome-keyring only offers "automatically unlock whenever
    // I'm logged in" on some of its unlock paths.
    property string choiceLabel: ""
    property bool choiceChosen: false

    // Whether the field is for a password being SET rather than entered. The
    // panel says so rather than silently accepting a typo nobody can correct.
    property bool passwordNew: false

    // The client's own words for the two buttons. gnome-keyring says "Unlock"
    // and "Cancel"; a certificate prompt says something else, and the panel
    // uses whatever it is told rather than a pair it made up.
    property string continueLabel: ""
    property string cancelLabel: ""

    // WHICH SCREEN IT IS DRAWN ON, latched when the question arrives and not
    // re-read after. It has to be latched: the answer is typed over some
    // seconds, and Hyprland hands the focus to whichever monitor the pointer
    // wandered onto, so a live reading would move a half-typed password to
    // another screen. Empty means "wherever Shell.forScreen decides", which is
    // the honest answer for the moment before the compositor has told anyone.
    property string screenName: ""

    // ---- WHETHER WE ARE THE PROMPTER AT ALL ----------------------------

    // The shell is the keyring's prompter right now. False means gcr's dialog
    // is what a keyring question would put on screen, which is the state the
    // CLI reports and the one worth being able to ask about.
    readonly property bool serving: helper.running && !root.blocked

    // Something else holds the bus name. Almost always gcr-prompter, activated
    // while the shell was not running; it refuses to be replaced and exits on
    // its own once idle, which is what the retry below waits for.
    property bool blocked: false

    // ---- ANSWERING -----------------------------------------------------

    function submit(secret: string): void {
        if (!root.active || root.kind !== "password")
            return;
        root.reply({
            reply: "yes",
            secret: secret
        });
    }

    // A confirm's yes. Separate from submit() because it carries no secret and
    // must not be reachable from a field.
    function confirm(): void {
        if (!root.active || root.kind !== "confirm")
            return;
        root.reply({
            reply: "yes"
        });
    }

    function refuse(): void {
        if (!root.active)
            return;
        root.reply({
            reply: "no"
        });
    }

    // The tickbox, kept here rather than in the panel because it travels with
    // the answer and the panel can be destroyed between the tick and the Enter.
    function choose(on: bool): void {
        root.choiceChosen = on;
    }

    // The one place anything is written to the helper, so there is exactly one
    // line that can be holding a secret.
    function reply(answer: var): void {
        answer.id = root.serial;
        answer.choice = root.choiceChosen;
        helper.write(JSON.stringify(answer) + "\n");
        // Cleared HERE rather than when the helper answers back: the question is
        // over the moment it has been answered, and leaving the panel up until a
        // round trip completes would leave a field somebody can type a second
        // password into.
        root.clear();
    }

    function clear(): void {
        root.active = false;
        root.kind = "";
        root.title = "";
        root.message = "";
        root.description = "";
        root.warning = "";
        root.choiceLabel = "";
        root.choiceChosen = false;
        root.passwordNew = false;
        root.continueLabel = "";
        root.cancelLabel = "";
    }

    // ---- THE HELPER ----------------------------------------------------

    function take(line: string): void {
        let event = null;
        try {
            event = JSON.parse(line);
        } catch (e) {
            console.warn(`Keyring: the prompter said something that is not JSON: ${e}`);
            return;
        }

        if (event.event === "hide") {
            // The client withdrew the question - it gave up, or it died. Only
            // for the question actually on screen: a late hide for one already
            // answered must not take down its successor.
            if (event.id === root.serial)
                root.clear();
            return;
        }

        if (event.event !== "show")
            return;

        root.serial = event.id;
        root.kind = event.kind ?? "";
        root.title = event.title ?? "";
        root.message = event.message ?? "";
        root.description = event.description ?? "";
        root.warning = event.warning ?? "";
        root.choiceLabel = event.choiceLabel ?? "";
        root.choiceChosen = event.choiceChosen ?? false;
        root.passwordNew = event.passwordNew ?? false;
        root.continueLabel = event.continueLabel ?? "";
        root.cancelLabel = event.cancelLabel ?? "";
        // The same fallback chain services/Settings.qml uses, and for the same
        // reason: an empty answer here is a question drawn on NO screen, which
        // is a keyring prompt that silently never appears.
        root.screenName = Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        root.asked += 1;
        root.active = true;
    }

    // A QUESTION NOBODY ASKED, so the card can be looked at.
    //
    // This shell's rule that anything reachable only by a gesture needs a second
    // way in (the IpcHandler notes in modules/Ipc.qml, `banditshell lockpreview`
    // for the lock screen) applies here in its strongest form: this panel cannot
    // be reached by a gesture AT ALL. It appears when an application happens to
    // want a secret, which is not a thing anybody can arrange on demand, and the
    // one way to arrange it for real - locking a keyring - costs the person
    // their session's stored passwords. So the card is checkable without that.
    //
    // The serial is deliberately one the helper cannot know about, so an answer
    // typed into a demo is dropped on the floor rather than sent to a client
    // that does not exist. See `banditshell keyring demo`.
    function demo(): void {
        root.serial = -1;
        root.kind = "password";
        root.title = "Unlock Login Keyring";
        root.message = "Authentication required";
        root.description = "The login keyring did not get unlocked when you logged into your computer.";
        root.warning = "";
        root.choiceLabel = "Automatically unlock this keyring whenever I'm logged in";
        root.choiceChosen = false;
        root.passwordNew = false;
        root.continueLabel = "Unlock";
        root.cancelLabel = "Cancel";
        root.screenName = Hypr.focusedScreen || Quickshell.screens[0]?.name || "";
        root.asked += 1;
        root.active = true;
    }

    Process {
        id: helper

        running: true
        command: ["python3", Quickshell.shellPath("scripts/keyring-prompter.py")]

        // The answer goes down here, and it is the only thing that ever does.
        stdinEnabled: true

        stdout: SplitParser {
            onRead: line => root.take(line)
        }

        // The helper's complaints, which are worth hearing: a missing python
        // module here means every keyring question on this machine silently
        // goes back to being a GTK box, and nothing else would say so.
        stderr: SplitParser {
            onRead: line => {
                if (line.includes("DeprecationWarning") || line.startsWith("  "))
                    return;
                console.warn(`Keyring: ${line}`);
            }
        }

        // EXIT CODE 3 IS "SOMEBODY ELSE HAS THE NAME", and it is the only one
        // worth coming back from. The usual cause is gcr-prompter, activated
        // while the shell was not running and holding a name it will not give
        // up; it exits once it is idle, so waiting and asking again is the whole
        // repair. Every other exit is a real failure (no python, no
        // python-gobject) and retrying it forever would be a process spawned on
        // a timer for as long as the session lasts.
        onExited: code => {
            root.clear();
            root.blocked = code === 3;
            if (root.blocked)
                retry.restart();
        }
    }

    Timer {
        id: retry

        // Long enough that a gcr dialog somebody is actually typing into gets to
        // finish, short enough that the next keyring question is ours.
        interval: 5000
        onTriggered: helper.running = true
    }
}
