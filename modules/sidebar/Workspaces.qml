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

    // The "you are here" marker. Drawn first so the numbers sit on top of it.
    // Its y is NOT bound: the timer below drives it, so it can be animated.
    G2Rect {
        id: indicator

        width: root.slot
        height: root.slot
        radius: Appearance.rounding.small
        color: Appearance.colour.accent
    }

    // Exponential smoothing: moves fast when far, settles gently when close, and
    // is safe at any frame time (see ~/.claude/rules/animation-smoothing.md).
    // Only runs while there is distance left to cover, so an idle shell is idle.
    Timer {
        interval: 16
        repeat: true
        running: Math.abs(indicator.y - root.activeY) > 0.25

        onTriggered: {
            const dy = root.activeY - indicator.y;
            if (Math.abs(dy) < 0.25) {
                indicator.y = root.activeY;
                return;
            }
            indicator.y += dy * (1 - Math.exp(-Appearance.anim.trackSpeed * (interval / 1000)));
        }
    }

    Component.onCompleted: indicator.y = root.activeY

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

            // Hover response: the slot lights up under the cursor.
            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.small
                color: Appearance.colour.surfaceAlt
                opacity: mouse.containsMouse && !slot.isActive ? 1 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                text: slot.wsId
                color: slot.isActive ? Appearance.colour.accentText : slot.isOccupied ? Appearance.colour.text : Appearance.colour.textFaint
                scale: mouse.containsMouse ? 1.2 : 1

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
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
