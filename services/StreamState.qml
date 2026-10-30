pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string screen: Config.values.stream.screen

    readonly property bool enabled: Config.values.stream.enabled && root.screen !== ""

    Binding {
        target: Focus
        property: "offStagePinned"
        value: root.enabled
    }

    Binding {
        target: Focus
        property: "pinnedScreen"
        value: root.screen
    }

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

    readonly property string flagPath: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/hypr/streamer`

    function follow(streaming: bool): void {
        if (!Config.writable)
            return;
        if (streaming && !root.enabled && root.screen !== "")
            root.setOn(root.screen);
        else if (!streaming && root.enabled)
            root.setOff();
    }

    FileView {
        id: flag

        path: root.flagPath
        printErrors: false

        onLoaded: root.follow(true)
        onLoadFailed: root.follow(false)
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            flag.reload();
        }
    }

    Connections {
        target: Config

        function onWritableChanged(): void {
            if (Config.writable)
                flag.reload();
        }
    }

    Component.onCompleted: Obs.reach()
}
