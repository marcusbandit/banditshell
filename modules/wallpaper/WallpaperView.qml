pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string output

    property bool playing: false
    property bool audible: false

    readonly property string wanted: Wallpaper.shownOn(root.output)

    property bool showB: false
    readonly property WallpaperSource front: showB ? b : a
    readonly property WallpaperSource back: showB ? a : b

    function load(): void {
        const path = root.wanted;
        if (!path || front.path === path)
            return;

        if (front.path === "") {
            front.path = path;
            return;
        }

        back.path = path;
        root.settled(back);
    }

    function settled(slot: var): void {
        if (!slot || !back)
            return;
        if (slot.ready && slot === back && slot.path === root.wanted) {
            showB = !showB;

            root.seed = Math.random() * 6.283;

            if (Wallpaper.previewOn(root.output) === slot.path) {
                sweep.stop();
                root.reveal = 1;
            } else {
                sweep.restart();
            }
            retire.restart();
        }
    }

    function replay(): void {
        if (!front.path)
            return;
        back.path = "";
        root.seed = Math.random() * 6.283;
        sweep.restart();
    }

    Timer {
        id: retire

        interval: Appearance.sizes.wallpaperReveal * 1.25

        onTriggered: {
            if (root.back.path !== root.wanted)
                root.back.path = "";
        }
    }

    Component.onCompleted: load()

    onWantedChanged: root.load()

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

    WallpaperSource {
        id: a

        anchors.fill: parent
        z: root.showB ? 0 : 1

        playing: root.playing && root.front === a
        audible: root.audible

        layer.enabled: root.front === a && sweep.running
        layer.effect: RevealMask {
            progress: root.reveal
            aspect: root.width / Math.max(1, root.height)
            origin: Wallpaper.originOn(root.output)
            seed: root.seed
        }

        onReadyChanged: root.settled(a)
    }

    WallpaperSource {
        id: b

        anchors.fill: parent
        z: root.showB ? 1 : 0

        playing: root.playing && root.front === b
        audible: root.audible

        layer.enabled: root.front === b && sweep.running
        layer.effect: RevealMask {
            progress: root.reveal
            aspect: root.width / Math.max(1, root.height)
            origin: Wallpaper.originOn(root.output)
            seed: root.seed
        }

        onReadyChanged: root.settled(b)
    }
}
