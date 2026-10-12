pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property string screen: Config.values.stream.screen

    readonly property bool enabled: Config.values.stream.enabled && root.screen !== ""

    readonly property bool connected: Quickshell.screens.some(s => s.name === root.screen)

    readonly property int reserve: Appearance.sizes.streamHeight + (Appearance.bare ? Appearance.sizes.gap : 0)

    function shows(name: string): bool {
        return root.enabled && name === root.screen;
    }

    function floats(name: string): bool {
        return root.enabled && name !== root.screen;
    }

    function setOn(name: string): void {
        Config.setMany([["stream.screen", name], ["stream.enabled", true]]);
    }

    function setOff(): void {
        Config.set("stream.enabled", false);
    }
}
