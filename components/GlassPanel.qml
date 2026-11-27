import QtQuick
import Quickshell
import qs.config
import "glass-place.js" as Place

Item {
    id: root

    property string pill: ""
    property real radius: root.pill !== "" ? Math.min(root.width, root.height) / 2 : Appearance.rounding.large
    property GlassSource backdrop: null
    property point origin: root.placed
    property real raise: 1
    property bool layered: root.place.beneath

    default property alias content: inner.data

    readonly property var host: root.QsWindow.window ?? null
    readonly property var hostAt: Place.windowOffset(root.host, ExclusionMode.Ignore)
    readonly property GlassSource found: root.hostAt ? Backdrops.on(root.host?.screen?.name ?? "") : null
    readonly property GlassSource source: root.backdrop ?? root.found
    readonly property var place: Place.placeOf(root)
    readonly property point placed: {
        const source = root.source;
        const at = source ? Place.originOn(root.hostAt, root.place, Place.windowOffset(source.QsWindow.window ?? null, ExclusionMode.Ignore), Place.placeOf(source)) : null;
        return at ? Qt.point(at.x, at.y) : Qt.point(0, 0);
    }

    readonly property bool glassy: root.source?.ready ?? false
    readonly property real depth: root.layered ? 1 : 0

    Loader {
        anchors.fill: parent
        active: root.glassy

        sourceComponent: Glass {
            backdrop: root.source
            origin: root.origin
            radius: root.radius
            power: root.pill === "object" ? 2 : Appearance.rounding.power
            frosting: Math.min(1, 0.85 * root.raise + 0.15 * root.depth)
            sheen: 0.14 + 0.1 * root.raise + 0.06 * root.depth
            lift: 0.025 + 0.035 * root.raise + 0.035 * root.depth
            ceiling: 0.5 - 0.15 * root.raise
            saturation: 0.9 - 0.2 * root.raise - 0.1 * root.depth
        }
    }

    SquircleRect {
        anchors.fill: parent
        visible: !root.glassy
        radius: root.radius
        cornerPower: root.pill === "object" ? 2 : Appearance.rounding.power
        color: Appearance.colour.pane
        rim: 1
    }

    Item {
        id: inner

        anchors.fill: parent
    }
}
