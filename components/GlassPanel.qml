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

    readonly property GlassSource found: Backdrops.on(root.QsWindow.window ?? null)
    readonly property GlassSource source: root.backdrop ?? root.found
    readonly property var place: Place.placeOf(root)
    readonly property var sourcePlace: root.source ? Place.placeOf(root.source) : null
    readonly property point placed: root.place && root.sourcePlace ? root.mapToItem(root.source, 0, 0) : Qt.point(0, 0)

    readonly property bool glassy: root.source?.ready ?? false
    readonly property real depth: root.layered ? 1 : 0
    readonly property GlassSource sampled: root.glassy && root.place.shown ? root.source : null

    onSampledChanged: Backdrops.hold(root, root.sampled)
    Component.onDestruction: Backdrops.hold(root, null)

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
        color: root.source ? Appearance.colour.readableSurface : Appearance.colour.pane
        rim: 1
    }

    Item {
        id: inner

        anchors.fill: parent
    }
}
