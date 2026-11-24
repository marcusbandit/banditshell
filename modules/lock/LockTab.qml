pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import qs.config
import qs.components

Item {
    id: root

    property string style: "dots"

    property bool looking: false

    property bool granted: false

    property bool canLook: false

    property real alarm: 0

    property real waitLeft: 0

    property real presence: 1

    signal asked

    readonly property bool ticks: root.style === "ticks"
    readonly property real ring: Math.round(Appearance.sizes.lockFieldHeight * 2.2)
    readonly property bool counting: countdown.value > 0.001 && open.value < 0.5
    readonly property real alarmShown: root.counting ? 0 : root.alarm
    readonly property int count: root.ticks ? 60 : 28
    readonly property real dot: Math.max(3, Math.round(root.ring / 20))
    readonly property real tickLength: Math.max(4, Math.round(root.ring * 0.09))
    readonly property real tickWidth: Math.max(2, Math.round(root.ring / 48))
    readonly property real trail: 0.5
    readonly property real turnsPerSecond: 0.8

    readonly property real bodyWidth: Math.round(root.ring * 0.3)
    readonly property real bodyHeight: Math.round(root.ring * 0.23)
    readonly property real stroke: Math.max(2, Math.round(root.ring * 0.045))
    readonly property real shackleWidth: Math.round(root.bodyWidth * 0.66)
    readonly property real shackleHeight: Math.round(root.bodyWidth * 0.5)
    readonly property real lift: Math.round(root.shackleHeight * 0.8)
    readonly property real tuck: Math.ceil(root.stroke / 2)

    property real head: 0

    implicitWidth: root.ring + Appearance.padding.huge * 2
    implicitHeight: root.ring + Appearance.padding.large * 2

    Follow {
        id: seeing

        target: root.looking ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
    }

    Follow {
        id: open

        target: root.granted ? 1 : 0
        speed: Appearance.animation.trackSpeed
        epsilon: Appearance.animation.fadeEpsilon
    }

    Follow {
        id: countdown

        target: root.waitLeft
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
    }

    Follow {
        id: pointed

        target: press.containsMouse && root.canLook ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: Appearance.animation.fadeEpsilon
    }

    FrameAnimation {
        running: seeing.value > 0.01 && !Appearance.lessMotion
        onTriggered: root.head = (root.head + frameTime * root.turnsPerSecond) % 1
    }

    Item {
        id: dial

        anchors.centerIn: parent
        width: root.ring
        height: root.ring

        Repeater {
            model: root.count

            delegate: SquircleRect {
                id: mark

                required property int index

                readonly property real at: mark.index / root.count
                readonly property real angle: mark.at * Math.PI * 2 - Math.PI / 2
                readonly property real reach: root.ring / 2 - (root.ticks ? root.tickLength / 2 : root.dot / 2)
                readonly property real behind: ((root.head - mark.at) % 1 + 1) % 1
                readonly property real swept: Appearance.lessMotion ? 0.6 : Math.sqrt(Math.max(0, 1 - mark.behind / root.trail))
                readonly property real counted: Math.max(0, Math.min(1, (countdown.value - mark.at) * root.count))
                readonly property real lit: Math.max(mark.swept * seeing.value, mark.counted, open.value)
                readonly property color litColour: root.counting ? Appearance.colour.alarm : Appearance.colour.accent

                width: root.ticks ? root.tickWidth : root.dot
                height: root.ticks ? root.tickLength : root.dot
                x: dial.width / 2 + Math.cos(mark.angle) * mark.reach - width / 2
                y: dial.height / 2 + Math.sin(mark.angle) * mark.reach - height / 2
                rotation: root.ticks ? mark.at * 360 : 0
                pill: "object"

                color: Appearance.blend(Appearance.blend(Appearance.colour.textDim, mark.litColour, mark.lit), Appearance.colour.alarm, root.alarmShown)
                opacity: Math.max(0.26 + 0.14 * pointed.value + 0.74 * mark.lit, root.alarmShown * 0.9) * (0.6 + 0.4 * root.presence)
            }
        }

        Item {
            id: glyph

            anchors.centerIn: parent
            width: root.bodyWidth
            height: root.bodyHeight + root.shackleHeight - root.tuck
            opacity: 0.6 + 0.4 * root.presence

            Shape {
                id: shackle

                x: (root.bodyWidth - shackle.width) / 2
                y: -open.value * root.lift
                width: root.shackleWidth
                height: root.shackleHeight + root.lift + root.stroke

                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    id: hoop

                    readonly property real half: root.stroke / 2
                    readonly property real bend: (root.shackleWidth - root.stroke) / 2
                    readonly property real floor: root.shackleHeight + root.tuck

                    strokeColor: Appearance.blend(Appearance.colour.text, Appearance.colour.accent, open.value)
                    strokeWidth: root.stroke
                    fillColor: "transparent"
                    capStyle: ShapePath.RoundCap
                    joinStyle: ShapePath.RoundJoin

                    startX: hoop.half
                    startY: hoop.floor + open.value * root.lift

                    PathLine {
                        x: hoop.half
                        y: hoop.half + hoop.bend
                    }

                    PathArc {
                        x: root.shackleWidth - hoop.half
                        y: hoop.half + hoop.bend
                        radiusX: hoop.bend
                        radiusY: hoop.bend
                    }

                    PathLine {
                        x: root.shackleWidth - hoop.half
                        y: hoop.floor
                    }
                }
            }

            SquircleRect {
                anchors.bottom: parent.bottom
                width: root.bodyWidth
                height: root.bodyHeight
                radius: Math.round(root.bodyHeight * 0.28)
                color: Appearance.blend(Appearance.colour.text, Appearance.colour.accent, open.value)
            }
        }
    }

    MouseArea {
        id: press

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.canLook ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.canLook)
            root.asked()
    }
}
