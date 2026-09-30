pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.services

PanelWindow {
    id: win

    readonly property string output: win.screen?.name ?? ""

    readonly property string wanted: Wallpaper.shownOn(win.output)

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

    property bool showB: false
    readonly property WallpaperSource front: showB ? b : a
    readonly property WallpaperSource back: showB ? a : b

    readonly property bool bare: Hypr.windowsOn(win.output) === 0
    readonly property bool playing: Wallpaper.enabled && Config.values.wallpaper.animate && win.bare

    function load(): void {
        const path = win.wanted;
        if (!path || front.path === path)
            return;

        if (front.path === "") {
            front.path = path;
            return;
        }

        back.path = path;
        win.settled(back);
    }

    function settled(slot: var): void {
        if (!slot || !back)
            return;
        if (slot.ready && slot === back && slot.path === win.wanted) {
            showB = !showB;

            win.seed = Math.random() * 6.283;

            sweep.restart();
            retire.restart();
        }
    }

    Timer {
        id: retire

        interval: Appearance.sizes.wallpaperReveal * 1.25

        onTriggered: {
            if (win.back.path !== win.wanted)
                win.back.path = "";
        }
    }

    Component.onCompleted: load()

    onWantedChanged: win.load()

    property real reveal: 1

    property real seed: 0

    NumberAnimation on reveal {
        id: sweep

        running: false
        from: 0
        to: 1
        duration: Appearance.sizes.wallpaperReveal

        easing.type: Easing.OutCubic
    }

    Item {
        id: picture

        anchors.fill: parent
        opacity: Wallpaper.enabled ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.slow
            }
        }

        WallpaperSource {
            id: a

            anchors.fill: parent
            z: win.showB ? 0 : 1

            playing: win.playing && win.front === a
            audible: Config.values.wallpaper.audio

            layer.enabled: win.front === a && sweep.running
            layer.effect: RevealMask {
                progress: win.reveal
                aspect: win.width / Math.max(1, win.height)
                origin: Wallpaper.originOn(win.output)
                seed: win.seed
            }

            onReadyChanged: win.settled(a)
        }

        WallpaperSource {
            id: b

            anchors.fill: parent
            z: win.showB ? 1 : 0

            playing: win.playing && win.front === b
            audible: Config.values.wallpaper.audio

            layer.enabled: win.front === b && sweep.running
            layer.effect: RevealMask {
                progress: win.reveal
                aspect: win.width / Math.max(1, win.height)
                origin: Wallpaper.originOn(win.output)
                seed: win.seed
            }

            onReadyChanged: win.settled(b)
        }
    }
}
