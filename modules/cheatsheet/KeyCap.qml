pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property real units: 1
    property real span: 1
    property real pitch: 0
    property real seam: 0

    property real foot: 0

    property string label: ""
    property string glyph: ""

    property bool blocked: false

    property bool lit: false
    property bool latched: false
    property bool selected: false

    signal tapped

    readonly property real headHeight: root.foot > 0 ? root.pitch : root.span * root.pitch - root.seam

    readonly property real radius: Appearance.rounding.small

    readonly property color fill: root.blocked ? "transparent" : root.latched ? Appearance.colour.accentFill : root.lit ? Appearance.colour.fillStronger : Appearance.colour.fill
    readonly property color ink: root.latched || root.lit ? Appearance.colour.text : Appearance.colour.textGhost

    readonly property color edge: root.selected ? Appearance.colour.accent : root.blocked ? Appearance.colour.separator : "transparent"
    readonly property real edgeWidth: root.selected || root.blocked ? Appearance.font.stem : 0

    width: root.units * root.pitch - root.seam
    height: root.span * root.pitch - root.seam

    SquircleRect {
        id: head

        width: parent.width
        height: root.headHeight

        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius

        bottomRightRadius: root.foot > 0 ? 0 : root.radius

        color: root.fill
        stroke: root.edge
        strokeWidth: root.edgeWidth

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.fast
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
            font.strikeout: root.blocked
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.glyph && !root.label

            glyph: root.glyph
            size: Appearance.font.size.small
            color: root.ink
        }

        Item {
            id: pair

            readonly property real gap: Appearance.padding.small / 2

            anchors.centerIn: parent
            width: Math.min(sigil.implicitWidth + pair.gap + word.implicitWidth, head.width - Appearance.padding.small * 2)
            height: head.height
            visible: !!root.glyph && !!root.label

            Icon {
                id: sigil

                anchors.verticalCenter: parent.verticalCenter

                glyph: root.glyph
                size: Appearance.font.size.small
                color: root.ink
            }

            StyledText {
                id: word

                anchors.verticalCenter: parent.verticalCenter
                x: sigil.implicitWidth + pair.gap
                width: Math.max(0, pair.width - word.x)

                elide: Text.ElideRight

                text: root.label
                color: root.ink
                font.strikeout: root.blocked
            }
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
        height: (root.span - 1) * root.pitch - root.seam
        visible: root.foot > 0

        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius

        color: root.fill
        stroke: root.edge
        strokeWidth: root.edgeWidth

        Behavior on color {
            ColorAnimation {
                duration: Appearance.animation.fast
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.tapped()
        }
    }
}
