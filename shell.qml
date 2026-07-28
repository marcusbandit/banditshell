import QtQuick
import Quickshell

ShellRoot {
    PanelWindow {
        id: win
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        exclusiveZone: 0

        property int border: 10

        readonly property bool clockWanted: topZone.containsMouse || pillZone.containsMouse


        mask: Region {
            width: win.width
            height: win.height
            Region {
                intersection: Intersection.Subtract
                x: win.border
                y: win.border
                width: win.width - win.border * 2
                height: win.height - win.border * 2
            }
            Region {
                intersection: Intersection.Combine
                item: win.clockWanted ? pill : null
            }
        }

        SystemClock {
            id: clock
            precision: SystemClock.Seconds
        }

        MouseArea {
            id: topZone
            hoverEnabled: true
            height: win.border
            width: pill.width
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: pill
            anchors.top: parent.top
            anchors.topMargin: win.border
            anchors.horizontalCenter: parent.horizontalCenter

            width: label.implicitWidth + 40
            height: label.implicitHeight + 40
            radius: 10
            color: "#e61a1a1a"

            opacity: win.clockWanted ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 160;
                    easing.type: Easing.OutQuad
                }
            }
            MouseArea {
                id: pillZone
                anchors.fill: parent
                hoverEnabled: true
            }

            Text {
                id: label
                anchors.centerIn: parent
                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                color: "white"
                font.pixelSize: 28
                font.family: "Monocraft"
            }
        }
    }
}
