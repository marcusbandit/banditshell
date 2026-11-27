import QtQuick
import qs.config

Item {
    id: root

    property string pill: ""
    property real radius: root.pill !== "" ? Math.min(root.width, root.height) / 2 : Appearance.rounding.large
    property GlassSource backdrop: null
    property point origin: Qt.point(0, 0)
    property real raise: 1

    default property alias content: inner.data

    readonly property bool glassy: root.backdrop?.ready ?? false

    Loader {
        anchors.fill: parent
        active: root.glassy

        sourceComponent: Glass {
            backdrop: root.backdrop
            origin: root.origin
            radius: root.radius
            power: root.pill === "object" ? 2 : Appearance.rounding.power
            frosting: 0.85 * root.raise
            sheen: 0.14 + 0.1 * root.raise
            lift: 0.025 + 0.035 * root.raise
            ceiling: 0.5 - 0.15 * root.raise
            saturation: 0.9 - 0.2 * root.raise
        }
    }

    SquircleRect {
        anchors.fill: parent
        visible: !root.glassy
        radius: root.radius
        cornerPower: root.pill === "object" ? 2 : Appearance.rounding.power
        color: Appearance.colour.readableSurface
        rim: 1
    }

    Item {
        id: inner

        anchors.fill: parent
    }
}
