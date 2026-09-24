pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// A ROW OF RELATED PRESSES, JOINED AS ONE SHAPE.
//
// Pill is one press; this is several that belong together, drawn as ONE
// object with parts rather than as pills sitting near each other. The join is
// the point: one plate, one radius, and a member that lights inside it under
// the cursor, so the eye reads "these are this thing's choices" and not
// "three buttons that happen to be adjacent". The neighbours it replaced
// drifted within a week - different heights, different radii, one of them the
// same fill as the card it sat on.
//
// It owns nothing. Like Pill and Toggle, a press is asked for, not taken:
// `triggered(index)` goes out and the caller answers. No checked state here
// either - a member that STAYS lit is a choice, and a choice is Segments,
// whose thumb is this plate with an opinion.
//
// Members are flush, and the boundary between them shows on hover, not at
// rest: the group is one object until the hand says otherwise, which is the
// same "alive on contact" the chassis itself obeys.
Item {
    id: root

    // The presses, in order: { text, icon }. Either field may be empty; a
    // member with neither is a target worth nothing and is the caller's bug,
    // not this file's.
    property var actions: []

    property real labelSize: Appearance.font.size.small
    property bool interactive: true

    signal triggered(int index)

    implicitWidth: row.width
    implicitHeight: Math.max(Appearance.sizes.minTarget, Math.round(labelSize * 4 / 3) + Appearance.padding.small * 2)
    width: implicitWidth
    height: implicitHeight

    opacity: root.interactive ? 1 : 0.45

    // The plate. Same fill a Pill rests on, one radius, no internal lines:
    // the members are held by proximity the way the chassis holds its panels.
    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fillStrong
    }

    Row {
        id: row

        Repeater {
            model: root.actions

            delegate: Item {
                id: member

                required property var modelData
                required property int index

                readonly property bool hasText: (modelData.text ?? "") !== ""
                readonly property bool hasIcon: (modelData.icon ?? "") !== ""
                readonly property real markSpan: member.hasIcon ? root.labelSize + (member.hasText ? Appearance.padding.small : 0) : 0

                readonly property bool hovered: root.interactive && press.containsMouse
                readonly property bool pressed: root.interactive && press.pressed

                TextMetrics {
                    id: ink

                    font.family: Appearance.font.family
                    font.pixelSize: root.labelSize
                    text: member.hasText ? member.modelData.text : ""
                }

                width: (member.hasText ? Math.ceil(ink.width) : 0) + member.markSpan + Appearance.padding.normal * 2
                height: root.height

                // The member's answer to being found. Interior edges stay
                // square - the fill must run INTO the plate's ends, not
                // curl inside them - so the rounding is per corner: full at
                // the group's two ends, nothing where the member meets its
                // neighbour.
                G2Rect {
                    anchors.fill: parent
                    visible: member.hovered || member.pressed
                    radius: height / 2
                    topLeftRadius: member.index === 0 ? height / 2 : 0
                    bottomLeftRadius: member.index === 0 ? height / 2 : 0
                    topRightRadius: member.index === root.actions.length - 1 ? height / 2 : 0
                    bottomRightRadius: member.index === root.actions.length - 1 ? height / 2 : 0
                    color: Appearance.colour.fillStronger
                }

                // Pressing it MOVES it, as Pill moves: the content, not the
                // fill, and about the member's own middle.
                scale: member.pressed ? 0.96 : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }

                Row {
                    anchors.centerIn: parent
                    spacing: member.hasText && member.hasIcon ? Appearance.padding.small : 0

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: member.hasIcon
                        name: member.hasIcon ? member.modelData.icon : ""
                        size: root.labelSize
                        color: Appearance.colour.text
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: member.hasText
                        text: member.hasText ? member.modelData.text : ""
                        font.pixelSize: root.labelSize
                        color: Appearance.colour.text
                    }
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.triggered(member.index)
                }
            }
        }
    }
}
