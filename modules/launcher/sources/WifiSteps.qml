pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property var steps: []
    property real since: 0
    property real now: 0

    readonly property real mark: Appearance.font.size.normal + 2

    spacing: Appearance.padding.small

    Repeater {
        model: root.steps

        Item {
            id: step

            required property var modelData

            readonly property string phase: step.modelData.state
            readonly property bool active: step.phase === "active"
            readonly property bool yours: step.active && (step.modelData.key === "secret" || step.modelData.key === "portal")
            readonly property bool working: step.active && !step.yours
            readonly property bool marked: step.phase === "done" || step.phase === "failed" || step.phase === "warning"
            readonly property int seconds: step.working ? Math.max(0, Math.floor((root.now - root.since) / 1000)) : 0

            width: root.width
            height: line.height + (note.visible ? note.implicitHeight : 0)

            Item {
                id: line

                width: parent.width
                height: Math.max(root.mark, label.implicitHeight)

                ProgressRing {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !step.marked
                    size: root.mark
                    thickness: Math.max(2, Math.round(root.mark / 8))
                    value: step.yours ? 1 : step.working ? 0.28 : 0
                    colour: Appearance.colour.chosen
                    track: step.active ? Appearance.colour.fillStrong : Appearance.colour.fill

                    RotationAnimator on rotation {
                        from: 0
                        to: 360
                        duration: 900
                        loops: Animation.Infinite
                        running: step.working && !Appearance.lessMotion
                    }
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: step.marked
                    width: root.mark
                    size: root.mark
                    name: step.phase === "done" ? "check" : step.phase === "failed" ? "close" : "priority_high"
                    color: step.phase === "failed" ? Appearance.colour.alarm : step.phase === "done" ? Appearance.colour.text : Appearance.colour.textDim
                }

                StyledText {
                    id: label

                    anchors.left: parent.left
                    anchors.leftMargin: root.mark + Appearance.padding.normal
                    anchors.right: elapsed.left
                    anchors.rightMargin: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter
                    text: step.modelData.label
                    font.pixelSize: Appearance.font.size.normal
                    color: step.phase === "waiting" ? Appearance.colour.textFaint : step.phase === "failed" ? Appearance.colour.alarm : step.active ? Appearance.colour.text : Appearance.colour.textDim
                    elide: Text.ElideRight
                }

                StyledText {
                    id: elapsed

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: step.working && step.seconds >= 3
                    text: `${step.seconds} s`
                    font.pixelSize: Appearance.font.size.small
                    font.features: {
                        "tnum": 1
                    }
                    color: Appearance.colour.textFaint
                }
            }

            StyledText {
                id: note

                anchors.top: line.bottom
                x: root.mark + Appearance.padding.normal
                width: parent.width - x
                visible: step.modelData.note !== ""
                text: step.modelData.note
                font.pixelSize: Appearance.font.size.small
                color: step.phase === "failed" || step.active ? Appearance.colour.alarm : Appearance.colour.textDim
                wrapMode: Text.Wrap
            }
        }
    }
}
