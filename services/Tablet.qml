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

    // The hinge, as the shell currently believes it to be.
    property bool folded: false

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
        root.folded = value;
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
            root.setFolded(!root.folded, from);
        else
            return `not a tablet verb: ${verb}`;
        return root.folded ? "folded" : "flat";
    }

    // ONCE, AT STARTUP, and never again. Deliberately not a poll: everything
    // after this arrives as a transition, and a shell that also polled would be
    // asking a question it already has a live answer to.
    Component.onCompleted: probe.running = true

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
}
