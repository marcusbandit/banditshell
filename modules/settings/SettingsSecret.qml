pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Row {
    id: root

    property string text: ""
    property bool alarm: false
    property bool shown: false
    property real boxWidth: 200
    property real boxHeight: 32

    signal edited(string text)
    signal accepted(string text)

    readonly property alias editing: input.activeFocus

    function take(): void {
        input.forceActiveFocus();
    }

    spacing: 2

    Item {
        id: box

        anchors.verticalCenter: parent.verticalCenter
        width: root.boxWidth
        height: root.boxHeight

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.fill
            stroke: input.activeFocus ? Appearance.colour.accent : "transparent"
            strokeWidth: input.activeFocus ? Appearance.stroke.ring : 0
        }

        Item {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.normal
            anchors.rightMargin: Appearance.padding.normal
            clip: true

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7
                visible: !root.shown && input.length > 0

                Repeater {
                    model: Math.min(input.length, 16)

                    delegate: SquircleRect {
                        required property int index

                        width: 9
                        height: 9
                        pill: "object"
                        color: root.alarm ? Appearance.colour.alarm : Appearance.colour.accent
                        scale: grow.value

                        Follow {
                            id: grow

                            target: 1
                            speed: Appearance.animation.trackSpeed
                            epsilon: Appearance.animation.fadeEpsilon
                        }
                    }
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: root.shown && input.length > 0
                text: input.text
                color: Appearance.colour.text
                elide: Text.ElideRight
                width: parent.width
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.length === 0
                text: "password"
                color: Appearance.colour.textFaint
            }
        }

        TextInput {
            id: input

            anchors.fill: parent
            opacity: 0
            text: root.text
            echoMode: TextInput.Password
            font.pixelSize: Appearance.font.size.small

            onTextEdited: root.edited(input.text)
            onAccepted: root.accepted(input.text)
            onActiveFocusChanged: activeFocus ? Prompts.request(root) : Prompts.release(root)
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.IBeamCursor
            onClicked: input.forceActiveFocus()
        }
    }

    SettingsTool {
        anchors.verticalCenter: parent.verticalCenter
        icon: root.shown ? "visibility_off" : "visibility"
        tip: root.shown ? "hide" : "show"
        onClicked: root.shown = !root.shown
    }

    Component.onDestruction: Prompts.release(root)
}
