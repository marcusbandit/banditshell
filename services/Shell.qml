pragma Singleton

import QtQuick
import Quickshell

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

    function forScreen(name: string): var {
        if (name)
            return root.windows.find(w => w.screen?.name === name) ?? null;

        return root.windows.find(w => w.screen?.name === Hypr.focusedScreen) ?? root.windows[0] ?? null;
    }

    function showing(pick: var): var {
        const here = root.forScreen("");
        if (here && pick(here))
            return here;
        return root.windows.find(w => pick(w)) ?? here;
    }

    function openPanel(name: string, args: var): void {
        const panel = root.forScreen(args.screen ?? "")?.named[name] ?? null;
        if (!panel)
            return;
        panel.show();
        const input = panel.concept?.input ?? null;
        if (input && args.text !== undefined) {
            input.text = args.text;
            input.cursorPosition = args.text.length;
        }
    }

    function togglePanel(name: string, args: var): void {
        const screen = args.screen ?? "";
        const win = screen ? root.forScreen(screen) : root.showing(w => w.named[name]?.open);
        win?.named[name]?.toggle();
    }

    function panelOpen(name: string): bool {
        return root.windows.some(w => w.named[name]?.open === true);
    }

    Component.onCompleted: Panels.adopt(root)

    function screenNames(): var {
        return root.windows.map(w => w.screen?.name ?? "?");
    }
}
