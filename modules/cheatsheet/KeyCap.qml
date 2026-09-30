pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property real units: 1
    property real pitch: 0
    property real seam: 0

    property real foot: 0

    property string label: ""
    property string glyph: ""

    property bool lit: false
    property bool latched: false
    property bool selected: false

    signal tapped

    readonly property real headHeight: root.foot > 0 ? root.pitch : root.pitch - root.seam

    readonly property real radius: Appearance.rounding.small

    readonly property color fill: root.latched ? Appearance.colour.accentFill : root.lit ? Appearance.colour.fillStronger : Appearance.colour.fill
    readonly property color ink: root.latched || root.lit ? Appearance.colour.text : Appearance.colour.textGhost

    width: root.units * root.pitch - root.seam
    height: (root.foot > 0 ? 2 * root.pitch : root.pitch) - root.seam

    SquircleRect {
        id: head

        width: parent.width
        height: root.headHeight

        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius

        bottomRightRadius: root.foot > 0 ? 0 : root.radius

        color: root.fill
        stroke: root.selected ? Appearance.colour.accent : "transparent"

        strokeWidth: root.selected ? Appearance.font.stem : 0

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            visible: !root.glyph

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            elide: Text.ElideRight

            text: root.label
            color: root.ink
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.glyph

            glyph: root.glyph
            size: Appearance.font.size.small
            color: root.ink
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }

    SquircleRect {
        id: leg

        x: parent.width - width
        y: root.pitch
        width: root.foot * root.pitch - root.seam
        height: root.pitch - root.seam
        visible: root.foot > 0

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius

        color: root.fill
        stroke: root.selected ? Appearance.colour.accent : "transparent"
        strokeWidth: root.selected ? Appearance.font.stem : 0

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }
}
