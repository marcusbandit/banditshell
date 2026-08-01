pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Vertical workspace indicators.
//
// Slot positions come from one formula over the count, so adding a workspace
// just changes `count` (see ~/.claude/rules/math-over-hardcoding.md). Nothing
// here knows about "workspace 3" specifically.
//
// The selection is a quiet translucent fill, not a saturated block. A big
// coloured shape shouts, and the thing worth knowing is only "you are here".
Item {
    id: root

    readonly property int count: Hypr.count
    readonly property int slot: Appearance.sizes.wsSlot
    readonly property int pitch: slot + Appearance.sizes.wsGap

    function slotY(i: int): real {
        return i * pitch;
    }

    // Slot index of a workspace id. Ids are 1-based, indices 0-based.
    readonly property real activeY: slotY(Hypr.activeId - 1)

    implicitWidth: slot
    implicitHeight: count * pitch - Appearance.sizes.wsGap

    // A quiet container, so the indicators read as one control rather than a
    // column of loose numbers. No bevel, no channel: just a fill a shade above
    // the panel, which is all "these belong together" needs.
    G2Rect {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
    }

    // The "you are here" marker. Drawn before the numbers so they sit on top of
    // it, and it slides between slots rather than jumping, so switching
    // workspaces reads as one thing moving.
    Follow {
        id: slide
        target: root.activeY
    }

    Component.onCompleted: slide.snap()

    G2Rect {
        id: indicator

        y: slide.value
        width: root.slot
        height: root.slot
        radius: Appearance.rounding.normal
        color: Appearance.colour.fillStronger
    }

    Repeater {
        model: root.count

        delegate: Item {
            id: slot

            required property int index
            readonly property int wsId: index + 1
            readonly property bool isActive: Hypr.activeId === wsId
            readonly property bool isOccupied: Hypr.occupied(wsId)

            y: root.slotY(index)
            width: root.slot
            height: root.slot

            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                // A step above the group's own container fill, or hovering
                // inside the container would not read as anything.
                color: Appearance.colour.fillStrong
                opacity: mouse.containsMouse && !slot.isActive ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            // Three states, three label tiers, no colour: here, been there,
            // empty.
            StyledText {
                anchors.centerIn: parent
                text: slot.wsId
                color: slot.isActive ? Appearance.colour.text : slot.isOccupied ? Appearance.colour.textDim : Appearance.colour.textFaint

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Hypr.switchTo(slot.wsId)
            }
        }
    }
}
