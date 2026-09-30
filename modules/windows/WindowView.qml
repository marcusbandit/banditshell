pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Wayland
import qs.config
import qs.components

Item {
    id: root

    property var window: null

    property real radius: Appearance.sizes.windowRadius

    property bool live: false

    readonly property bool ready: view.hasContent

    ScreencopyView {
        id: view

        anchors.fill: parent

        captureSource: root.window?.wayland ?? null
        live: root.live

        paintCursor: false

        layer.enabled: true
        visible: false
    }

    SquircleRect {
        id: mask

        anchors.fill: parent
        radius: root.radius

        color: "white"
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent

        source: view
        maskEnabled: true
        maskSource: mask
        visible: root.ready
    }
}
