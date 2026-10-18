pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string output

    property bool wanted: false

    readonly property real progress: cover.value
    property real seed: 0
    property bool waited: false

    readonly property bool ready: view.item ? (view.item.front.ready || view.item.front.blank) : false
    readonly property bool showing: root.wanted && (root.ready || root.waited)

    function open(): void {
        if (cover.value === 0)
            root.seed = Math.random() * 6.283;
    }

    function close(): void {
        root.waited = false;
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
        id: cover

        target: root.showing ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.002
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
            playing: Wallpaper.enabled && Config.values.wallpaper.animate && !Appearance.lessMotion
        }
    }
}
