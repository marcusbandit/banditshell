import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property GlassSource backdrop: null
    property point origin: Qt.point(0, 0)
    property string pill: ""
    property real radius: Appearance.rounding.normal
    property real power: Appearance.rounding.power
    property real raise: 0
    property color fallback: Appearance.colour.island

    default property alias content: inner.data

    readonly property bool glassy: root.backdrop?.ready ?? false
    readonly property real floorLevel: 0.55 + 0.15 * root.raise

    Loader {
        anchors.fill: parent
        active: root.glassy

        sourceComponent: Glass {
            backdrop: root.backdrop
            origin: root.origin
            radius: root.pill === "object" ? Math.min(root.width, root.height) / 2 : root.radius
            power: root.pill === "object" ? 2 : root.power
            bezel: Math.min(Appearance.padding.large * 1.25, Math.min(root.width, root.height) * 0.3)
            frosting: root.raise
            sheen: 0.14 + 0.1 * root.raise
            shade: Appearance.light ? 1 - root.floorLevel : 1
            lift: Appearance.light ? root.floorLevel : 0.025 + 0.035 * root.raise
            ceiling: Appearance.light ? 1 : 0.32 - 0.12 * root.raise
            saturation: 0.9 - 0.2 * root.raise
        }
    }

    SquircleRect {
        anchors.fill: parent
        visible: !root.glassy && root.pill === "object"
        pill: "object"
        color: root.fallback
        rim: 1
    }

    SquircleRect {
        anchors.fill: parent
        visible: !root.glassy && root.pill !== "object"
        radius: root.radius
        cornerPower: root.power
        color: root.fallback
        rim: 1
    }

    Item {
        id: inner

        anchors.fill: parent
    }
}
