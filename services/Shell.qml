pragma Singleton

import QtQuick
import Quickshell

// The shell's own registry: which ShellWindows exist, one per screen.
//
// It is here rather than passed down because the things that need it (the IPC
// handler, later keybinds) sit outside the window tree entirely, and threading a
// reference from shell.qml through every layer to reach them would couple files
// that have nothing else to say to each other.
//
// Windows register themselves on creation and drop out on destruction, so
// plugging a monitor in or out needs no bookkeeping anywhere else.
Singleton {
    id: root

    property var windows: []

    function register(win: var): void {
        if (!root.windows.includes(win))
            root.windows = [...root.windows, win];
    }

    function unregister(win: var): void {
        root.windows = root.windows.filter(w => w !== win);
    }

    // Without a screen name, THE ONE THE KEYBOARD IS ON.
    //
    // A CLI invocation and a keybind both arrive without a screen and both mean
    // "here". This used to answer with the first window that registered, which
    // is Quickshell.screens order, which is a fact about how the outputs were
    // enumerated and about nothing else. On one monitor that is indistinguishable
    // from the right answer, which is exactly why it survived this long; on two
    // it opens the launcher you just asked for on the monitor you are not
    // looking at.
    //
    // services/Hypr.qml already had the answer and said so: focusedScreen is
    // "what 'the screen' means to anything summoned by a keybind rather than
    // reached for with the cursor". This is the caller that sentence was about.
    //
    // A NAMED screen is still exact or nothing. Callers turn the null into "no
    // shell window on screen: DP-2", and a name that quietly resolved to some
    // other monitor would report success while drawing somewhere else.
    function forScreen(name: string): var {
        if (name)
            return root.windows.find(w => w.screen?.name === name) ?? null;

        // The first window is the last resort, not the default: it covers the
        // moment before the compositor has told anyone which monitor is focused.
        return root.windows.find(w => w.screen?.name === Hypr.focusedScreen) ?? root.windows[0] ?? null;
    }

    // Without a screen name, but about a thing that may ALREADY BE UP: the
    // window that is showing it.
    //
    // forScreen("") above answers "here", and "here" is the right answer for a
    // summon: `launcher open` with no screen means the monitor you are looking
    // at, and it should keep following the focus wherever the focus goes. It is
    // the wrong answer for a TOGGLE. A toggle is a question about a panel that
    // may already exist somewhere, and "here" moves while the panel stays where
    // it was drawn: open the launcher, glance at the other monitor (follow_mouse
    // hands the focus over on the way there), press the same bind again, and an
    // answer of "here" opens a SECOND launcher on the screen you drifted onto
    // instead of putting away the one you were looking at. The verbs that only
    // READ have the same shape for the same reason: a status line that consults
    // the focused window reports "closed" while the panel is plainly out on the
    // next monitor over, and `launcher scrub` drives a rail that exists only
    // inside the launcher that is open.
    //
    // The focused window WINS when it is showing the thing too, so two panels of
    // one kind (a named `open` on one screen, a keybind on another) resolve to
    // the one in front of you rather than to whichever screen registered first.
    // With nothing showing it anywhere this falls back to "here", which is what
    // makes a toggle that finds nothing open one where you are standing.
    //
    // NOT FOR FURNITURE that exists on every screen at once. The tray's pin and
    // the notch's are per-screen facts about per-screen objects: "toggle the
    // notch" with no name means the notch on this monitor, and there is no
    // single instance for this function to go looking for.
    function showing(pick: var): var {
        const here = root.forScreen("");
        if (here && pick(here))
            return here;
        return root.windows.find(w => pick(w)) ?? here;
    }

    function screenNames(): var {
        return root.windows.map(w => w.screen?.name ?? "?");
    }
}
