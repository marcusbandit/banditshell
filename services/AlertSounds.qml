pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property var settings: Config.values.sound

    readonly property bool enabled: root.settings.alerts
    readonly property real volume: Math.max(0, Math.min(1, root.settings.alertVolume))

    readonly property var sets: ["soft", "clear", "wood"]
    readonly property var kinds: ["notification", "battery", "error"]

    readonly property string set: root.sets.includes(root.settings.alertSet) ? root.settings.alertSet : root.sets[0]

    readonly property int spacingMs: 250
    readonly property int settleMs: 300

    property double lastPlayed: 0

    function fileFor(kind: string): string {
        return Quickshell.shellPath(`assets/sounds/${root.set}/${kind}.wav`);
    }

    function play(kind: string): void {
        if (!root.enabled || root.volume <= 0 || !root.kinds.includes(kind))
            return;

        const now = Date.now();
        if (now - root.lastPlayed < root.spacingMs)
            return;
        root.lastPlayed = now;

        Quickshell.execDetached(["pw-play", "--volume", root.volume.toFixed(2), root.fileFor(kind)]);
    }

    function preview(): void {
        settle.restart();
    }

    Timer {
        id: settle

        interval: root.settleMs

        onTriggered: {
            root.lastPlayed = 0;
            root.play("notification");
        }
    }
}
