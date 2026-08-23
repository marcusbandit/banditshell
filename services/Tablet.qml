pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// IS THE MACHINE FOLDED OVER, and how does the shell find out.
//
// A convertible's hinge is an evdev SWITCH (SW_TABLET_MODE), and a switch is not
// a key: it has a STATE rather than an event, and the two halves of knowing it
// come from two different places.
//
//   the CHANGES come from the compositor. Hyprland already holds these devices
//   open and can bind to the transition, so `switch:on:` / `switch:off:` binds
//   in ~/.config/hypr/lua/binds.lua call the CLI and land in the IPC handler.
//   Nothing here polls, and nothing here needs read access to /dev/input.
//
//   the STATE AT STARTUP comes from scripts/tablet-state.py, once, because a
//   transition that happened before the shell existed is not something the
//   compositor can replay. A shell restarted while folded would otherwise sit
//   in laptop mode until the hinge next moved.
//
// AND THE PROBE IS ALLOWED TO FAIL. It needs the `input` group, which this user
// has (granted 2026-08-17, deliberately: it is read access to every evdev node).
// It can still come back `unknown`, and the commonest reason is not permission
// at all but timing: group membership applies at LOGIN, so a session started
// before the grant goes on being denied until the next one. The startup
// assumption is then "not folded" and the next fold corrects it, which costs one
// gesture. The script's own header argues this at length.
//
// AND THE HINGE ALONE IS NOT THE ANSWER, which is the thing this file learned
// late. The Yoga's switch does not report an ANGLE, it reports "outside the
// laptop range", and a lid shut flat is outside that range in exactly the way a
// lid folded all the way back is. Closing the machine to walk away therefore
// trips SW_TABLET_MODE, and the shell used to believe it: the board came up, the
// exclusive zone reflowed every window, and all of that was waiting on a screen
// that had just been shut. 0 degrees and 360 are indistinguishable to the
// firmware, so they are told apart here, by the one device that can: SW_LID.
//
// The lid is therefore a VETO and not a second opinion. `hinge` is what the
// switch said and `folded` is what the shell believes, and the only difference
// between them is that a closed lid means no.
//
// WHAT IT DELIBERATELY DOES NOT DO IS DISABLE THE PHYSICAL KEYBOARD. On this
// chassis the embedded controller already stops reporting the internal keyboard
// and touchpad past the tablet threshold, so there is nothing for the shell to
// switch off, and reaching for the compositor's device config to do it anyway
// would be a second opinion about a question the firmware has already answered.
// If a future machine needs it, it belongs in the compositor's config and not
// here: this file is a fact about the hinge, not a policy about input.
//
// A Singleton because the fact outlives every widget that reacts to it, and
// because the IPC handler that writes it sits outside the window tree entirely
// (DESIGN.md 8, the same reason Lock and Shell are singletons).
Singleton {
    id: root

    // The hinge, as the switch reported it. RAW: this is the device's opinion
    // and not the shell's, because on this chassis the two differ every time
    // the lid is shut. Read `folded` for the belief.
    property bool hinge: false

    // The lid, which is the only thing that can tell 0 degrees from 360.
    // Assumed OPEN, because that is the state a shell is overwhelmingly likely
    // to be starting in and because the wrong guess here is the harmless one:
    // it leaves the old behaviour rather than suppressing a real fold.
    property bool lidClosed: false

    // The same pair `known`/`source` keep for the hinge, and for the same
    // reason: a lid that has never reported is `open` by assumption, and a lid
    // bind that has stopped firing looks exactly like a machine nobody has
    // closed. `status` prints both so the two can be told apart.
    property bool lidKnown: false
    property string lidSource: "default"

    // IS THE MACHINE FOLDED OVER, the instant both devices are consulted. A
    // hinge past the threshold with the lid SHUT is a laptop being closed, not
    // a tablet being made, and nothing downstream should act on it.
    readonly property bool folding: root.hinge && !root.lidClosed

    // IS THE MACHINE FOLDED OVER, as the rest of the shell should ask it, once
    // the two switches have stopped arguing.
    //
    // WHY THIS IS NOT JUST `folding`. Shutting the lid trips BOTH switches, and
    // nothing orders them: libinput delivers them in whatever order the kernel
    // queued them, and the compositor runs a bind per event. If the fold lands
    // first the shell sees a genuine fold for the few milliseconds before the
    // lid vetoes it, which is long enough to show the board and to hand
    // FrameExclusions an exclusive zone, so closing the machine would flash the
    // keyboard up and reflow every window on the way out. Waiting lets the
    // second event arrive before anyone acts on the first.
    //
    // ONLY ON THE WAY IN. Coming out of tablet mode is not a race (nothing
    // vetoes "flat") and it is the case where the real keyboard is already back
    // under the fingers, so it is answered at once. The wait is imperceptible
    // against a gesture that takes about a second of wrist.
    property bool folded: false

    onFoldingChanged: {
        if (root.folding) {
            settle.restart();
        } else {
            settle.stop();
            root.folded = false;
        }
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: root.folded = root.folding
    }

    // WHETHER ANYONE HAS ACTUALLY SAID SO. `folded` is false both when the
    // machine is flat and when nothing has been able to tell us, and those are
    // different facts: the first is an answer and the second is a default. The
    // CLI prints which one it is, because a `tablet status` that said "flat"
    // while the device was folded in someone's hands would be the single most
    // confusing thing this service could do.
    property bool known: false

    // Where the belief came from, for the same reason: "probe", "compositor" or
    // "cli". A fold that never reaches the shell is a broken switch bind, and
    // this is how that gets diagnosed without a debugger.
    property string source: "default"

    // DOES THE BOARD TAKE UP ROOM, or does it sit over the window.
    //
    // Docked, the keyboard reserves an exclusive zone and every window on the
    // screen is laid out above it, so nothing you are typing into can be behind
    // it. Floating, it overlays, which is what a phone does and what you want
    // when the thing underneath is a page being read rather than a form being
    // filled.
    //
    // IT LIVES HERE RATHER THAN ON THE PANEL because the surface that has to act
    // on it is not the panel: an exclusive zone belongs to a one-edge window and
    // the board is drawn in the four-edge one, so modules/FrameExclusions.qml is
    // what actually reserves the space (the same split, and the same reason, as
    // the chassis's own bands). Two files on opposite sides of the window tree
    // need one answer, which is the definition of state that belongs in a
    // service.
    property bool docked: Config.values.tablet.docked

    function setDocked(value: bool): void {
        root.docked = value;
    }

    function setFolded(value: bool, from: string): void {
        root.known = true;
        root.source = from;
        root.hinge = value;
    }

    // THE LID DOES NOT SET `known`, because `known` is about the hinge. A lid
    // that has reported itself says nothing about whether the fold switch has
    // ever been heard from, and `status` would start claiming an answer it does
    // not have.
    function setLidClosed(value: bool, from: string): void {
        root.lidKnown = true;
        root.lidSource = from;
        root.lidClosed = value;
    }

    // THE CLI'S WAY IN, and the compositor's. Kept as one function taking a
    // word rather than three, so that `banditshell tablet on|off|toggle` and the
    // two switch binds all go through the same door and cannot drift apart.
    function apply(verb: string, from: string): string {
        if (verb === "on")
            root.setFolded(true, from);
        else if (verb === "off")
            root.setFolded(false, from);
        else if (verb === "toggle")
            root.setFolded(!root.hinge, from);
        else
            return `not a tablet verb: ${verb}`;
        // REPORTS `folding` RATHER THAN `folded`, because `folded` is still
        // settling at the instant this returns and a caller would always be
        // told the previous answer. It is still the BELIEF and not the switch:
        // a caller that folds the machine with the lid shut is told "flat"
        // rather than being told "folded" and then seeing nothing happen.
        return root.folding ? "folded" : "flat";
    }

    // THE LID'S WAY IN, and the same one door for the compositor and the CLI as
    // above. Separate from `apply` rather than a fourth verb on it, because a
    // handler that took `on|off|closed|open` would let `tablet on` and
    // `tablet closed` look like variations on one thing when they are facts
    // about two different devices.
    function applyLid(verb: string, from: string): string {
        if (verb === "closed")
            root.setLidClosed(true, from);
        else if (verb === "open")
            root.setLidClosed(false, from);
        else if (verb === "toggle")
            root.setLidClosed(!root.lidClosed, from);
        else
            return `not a lid verb: ${verb}`;
        return root.lidClosed ? "closed" : "open";
    }

    // ONCE, AT STARTUP, and never again. Deliberately not a poll: everything
    // after this arrives as a transition, and a shell that also polled would be
    // asking a question it already has a live answer to.
    //
    // BOTH SWITCHES, because a shell started with the lid shut (a reload over
    // ssh, a restart on an external monitor) would otherwise assume it open and
    // let the hinge through unvetoed, which is the exact case this veto exists
    // for.
    Component.onCompleted: {
        probe.running = true;
        lidProbe.running = true;
    }

    Process {
        id: probe

        command: ["python3", Quickshell.shellPath("scripts/tablet-state.py")]

        stdout: SplitParser {
            onRead: line => {
                const word = line.trim();
                if (word === "folded" || word === "flat") {
                    // NOT THROUGH setFolded's `known`, but through it anyway:
                    // the probe is a real answer when it manages to be one.
                    root.setFolded(word === "folded", "probe");
                } else if (word === "unknown") {
                    // Left as the default, and left UNKNOWN, so `status` can say
                    // that it is guessing rather than reporting.
                    root.source = "default";
                }
            }
        }

        stderr: SplitParser {
            // Only says anything with --verbose, which this does not pass, so a
            // line here is a real error: a missing python3, or the script gone.
            onRead: line => console.warn("Tablet:", line)
        }
    }

    // THE SAME SCRIPT, ASKING THE OTHER SWITCH. Two processes rather than one
    // printing two words, because each invocation keeping to a single word is
    // what lets both of these stay a three-line SplitParser with no parsing in
    // them at all.
    Process {
        id: lidProbe

        command: ["python3", Quickshell.shellPath("scripts/tablet-state.py"), "--lid"]

        stdout: SplitParser {
            onRead: line => {
                const word = line.trim();
                if (word === "closed" || word === "open")
                    root.setLidClosed(word === "closed", "probe");
                else if (word === "unknown")
                    root.lidSource = "default";
            }
        }

        stderr: SplitParser {
            onRead: line => console.warn("Tablet(lid):", line)
        }
    }
}
