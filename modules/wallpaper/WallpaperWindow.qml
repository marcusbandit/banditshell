import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property string output: win.screen?.name ?? ""

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "black"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "banditshell-wallpaper"

    mask: Region {
        width: 0
        height: 0
    }

    readonly property bool bare: Hypr.windowsOn(win.output) === 0

    Connections {
        target: Wallpaper

        function onReplayRequested(screen: string): void {
            if (screen === win.output)
                view.replay();
        }
    }

    WallpaperView {
        id: view

        anchors.fill: parent
        opacity: shown.value

        output: win.output
        playing: Wallpaper.enabled && Config.values.wallpaper.animate && win.bare
        audible: Config.values.wallpaper.audio

        Follow {
            id: shown

            target: Wallpaper.enabled ? 1 : 0
            speed: Appearance.animation.settleSpeed
            epsilon: Appearance.animation.fadeEpsilon
            startsAtTarget: true
        }
    }
}
