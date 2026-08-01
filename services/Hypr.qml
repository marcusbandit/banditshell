pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.config

// Adapter over Quickshell's Hyprland IPC.
//
// Widgets read this, never `Hyprland` directly. All the "how do we know" logic
// (which events force a refresh, id arithmetic, what counts as occupied) lives
// here, so the widgets stay purely visual.
Singleton {
    id: root

    // Workspaces always shown, even when empty.
    readonly property int persistentCount: Appearance.sizes.wsPersistent

    readonly property int activeId: Hyprland.focusedWorkspace?.id ?? 1

    // { id: windowCount } for every workspace Hyprland currently knows about.
    // Special workspaces have negative ids and are left out.
    readonly property var windows: {
        const out = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id > 0)
                out[ws.id] = ws.lastIpcObject?.windows ?? 0;
        return out;
    }

    // How many slots to render. Always enough for the persistent set, the
    // focused workspace, and the highest live one. Derived from the data, never
    // a hardcoded list of slots.
    readonly property int count: Math.max(persistentCount, activeId, ...Object.keys(windows).map(Number))

    function occupied(id: int): bool {
        return (windows[id] ?? 0) > 0;
    }

    function switchTo(id: int): void {
        Hyprland.dispatch(`workspace ${id}`);
    }

    // Hyprland pushes an event stream over its socket. Quickshell keeps its own
    // model in sync for some of it, but window counts only update when asked.
    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            const n = event.name;
            if (n.includes("workspace") || n.includes("window") || n.includes("mon"))
                Hyprland.refreshWorkspaces();
        }
    }
}
