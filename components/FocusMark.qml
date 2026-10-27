import QtQuick
import qs.config

SquircleRect {
    id: root

    property bool shown: false

    property real around: Appearance.rounding.normal

    readonly property int reach: Appearance.padding.hair

    anchors.fill: parent
    anchors.margins: -root.reach

    radius: root.pill !== "" ? Math.min(root.width, root.height) / 2 : root.around + root.reach
    stroke: Appearance.colour.accent
    strokeWidth: root.shown ? Appearance.stroke.ring : 0
    visible: root.shown
}
