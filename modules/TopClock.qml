import QtQuick
import Quickshell
import qs.config
import qs.components

// The original summon-on-intent widget: cursor to the top-centre edge, the time
// slides down out of the frame. The first proof of the interaction model.
Item {
    id: root

    // True while the clock should be shown. The window needs this to decide
    // whether `reveal` is part of its input mask.
    readonly property bool active: zone.containsMouse || pillZone.containsMouse
    readonly property Item maskItem: reveal

    property int border: Appearance.sizes.border

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        // Only tick while it is being looked at. A seconds clock bound to a
        // visible label wakes the render thread once a second whether or not
        // anything is on screen, and every one of those frames now redraws the
        // whole chassis field and hands the compositor a new surface to blur.
        enabled: root.active
    }

    // Summon zone: a strip of the invisible ring at top-centre. It sits inside
    // the ring, which is already masked, so it needs no mask entry of its own.
    MouseArea {
        id: zone

        hoverEnabled: true
        height: root.border
        width: pill.width
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // Clipping container. The pill lives *behind* the screen edge at y = -height
    // and slides down into view, so it reads as emerging from a frame that is
    // never actually drawn.
    Item {
        id: reveal

        clip: true

        anchors.top: parent.top
        anchors.topMargin: root.border
        anchors.horizontalCenter: parent.horizontalCenter

        width: pill.width
        height: pill.height

        G2Rect {
            id: pill

            y: -height

            width: label.implicitWidth + Appearance.padding.huge * 2
            height: label.implicitHeight + Appearance.padding.huge * 2

            // Square where it meets the screen edge, rounded where it meets the
            // desktop. It is flush against the edge but not at a screen corner,
            // so these stay convex.
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: Appearance.rounding.normal
            bottomRightRadius: Appearance.rounding.normal

            color: Appearance.colour.surface

            StyledText {
                id: label

                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                font.pixelSize: Appearance.font.size.large
            }
        }

        MouseArea {
            id: pillZone

            anchors.fill: parent
            hoverEnabled: true
        }

        states: State {
            name: "shown"
            when: root.active

            PropertyChanges {
                pill.y: 0
            }
        }

        transitions: [
            Transition {
                to: "shown"

                NumberAnimation {
                    property: "y"
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutExpo
                }
            },
            Transition {
                from: "shown"

                NumberAnimation {
                    property: "y"
                    duration: Appearance.anim.slow
                    easing.type: Easing.InQuad
                }
            }
        ]
    }
}
