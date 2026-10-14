pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string output

    property bool wanted: false

    property real progress: 0
    property real seed: 0
    property bool waited: false

    readonly property bool ready: view.item ? (view.item.front.ready || view.item.front.blank) : false
    readonly property bool showing: root.wanted && (root.ready || root.waited)

    function open(): void {
        closing.stop();
        if (root.progress === 0)
            root.seed = Math.random() * 6.283;
        if (root.progress < 1)
            opening.start();
    }

    function close(): void {
        opening.stop();
        root.waited = false;
        if (root.progress > 0)
            closing.start();
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

    NumberAnimation {
        id: opening

        target: root
        property: "progress"
        to: 1
        duration: Appearance.sizes.wallpaperReveal
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closing

        target: root
        property: "progress"
        to: 0
        duration: Math.round(Appearance.sizes.wallpaperReveal * 0.6)
        easing.type: Easing.OutCubic
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
