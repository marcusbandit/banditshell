pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.services

GlassSource {
    id: root

    required property string output
    property point screenOrigin: Qt.point(0, 0)
    property bool live: false
    property bool active: true
    property rect region: Qt.rect(0, 0, 0, 0)

    function within(client: var): bool {
        if (root.region.width <= 0 || root.region.height <= 0)
            return true;
        const at = client.lastIpcObject?.at ?? [0, 0];
        const span = client.lastIpcObject?.size ?? [0, 0];
        const x = at[0] - root.screenOrigin.x;
        const y = at[1] - root.screenOrigin.y;
        return x < root.region.x + root.region.width && x + span[0] > root.region.x && y < root.region.y + root.region.height && y + span[1] > root.region.y;
    }

    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === root.output) ?? null
    readonly property int workspace: root.monitor?.activeWorkspace?.id ?? Hypr.activeOn(root.output)
    readonly property string special: Hypr.specialOn(root.output)

    function rank(client: var): int {
        if (client?.workspace?.name === root.special && root.special !== "")
            return 2;
        return client?.lastIpcObject?.floating ? 1 : 0;
    }

    readonly property var shown: {
        const out = Hyprland.toplevels.values.filter(t => {
            const w = t.workspace;
            if (!w || !t.lastIpcObject?.mapped || t.lastIpcObject?.hidden)
                return false;
            return (w.id === root.workspace || (root.special !== "" && w.name === root.special)) && root.within(t);
        });
        return out.sort((a, b) => root.rank(a) - root.rank(b));
    }

    source: Wallpaper.enabled ? Wallpaper.faceOf(Wallpaper.shownOn(root.output)) : ""

    onLiveChanged: if (root.live)
        Hyprland.refreshToplevels()

    Timer {
        interval: 1500
        repeat: true
        running: root.active && !root.live && root.shown.length > 0
        onTriggered: {
            for (let i = 0; i < captures.count; i++)
                captures.itemAt(i)?.captureFrame();
        }
    }

    Repeater {
        id: captures

        model: root.active ? root.shown : []

        ScreencopyView {
            required property var modelData

            readonly property var at: modelData.lastIpcObject?.at ?? [0, 0]
            readonly property var span: modelData.lastIpcObject?.size ?? [0, 0]

            x: at[0] - root.screenOrigin.x
            y: at[1] - root.screenOrigin.y
            width: span[0]
            height: span[1]
            captureSource: modelData.wayland ?? null
            live: root.live
            paintCursor: false
        }
    }
}
