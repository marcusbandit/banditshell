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

    // Without a screen name, the first one. Callers that do not care which
    // screen (a CLI invocation, usually) should not have to name one.
    function forScreen(name: string): var {
        if (!name)
            return root.windows[0] ?? null;
        return root.windows.find(w => w.screen?.name === name) ?? null;
    }

    function screenNames(): var {
        return root.windows.map(w => w.screen?.name ?? "?");
    }
}
