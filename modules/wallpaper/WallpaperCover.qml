pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string output

    property bool wanted: false

    property real goal: 0
    readonly property real progress: sweep.value
    property real seed: 0
    property bool waited: false

    readonly property bool ready: view.item ? (view.item.front.ready || view.item.front.blank) : false
    readonly property bool showing: root.wanted && (root.ready || root.waited)

    function open(): void {
        if (root.progress === 0)
            root.seed = Math.random() * 6.283;
        root.goal = 1;
    }

    function close(): void {
        root.waited = false;
        root.goal = 0;
    }

    onShowingChanged: if (root.showing)
        root.open()

    onWantedChanged: {
        if (root.wanted)
            patience.restart();
        else
            root.close();
    }

    visible: root.progress > 0

    layer.enabled: root.visible && root.progress < 1
    layer.effect: RevealMask {
        progress: root.progress
        aspect: root.width / Math.max(1, root.height)
        origin: Qt.point(0.5, 1)
        seed: root.seed
    }

    Follow {
        id: sweep

        target: root.goal
        speed: 5000 / Math.max(1, Appearance.sizes.wallpaperReveal) / (root.goal > 0 ? 1 : 0.6)
        epsilon: Appearance.animation.fadeEpsilon
    }

    Timer {
        id: patience

        interval: 1500
        onTriggered: root.waited = true
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
    }

    Loader {
        id: view

        anchors.fill: parent
        active: root.wanted || root.progress > 0

        sourceComponent: WallpaperView {
            opacity: Wallpaper.enabled ? 1 : 0

            output: root.output
            playing: Wallpaper.enabled && Config.values.wallpaper.animate
        }
    }
}
