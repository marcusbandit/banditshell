import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var item

    readonly property bool hovered: mouse.containsMouse
    readonly property bool urgent: Tray.urgent(root.item)

    property bool longPressed: false

    signal activated

    signal requested(bool deliberate)

    readonly property alias drawn: drawing

    implicitWidth: drawing.width
    implicitHeight: drawing.height

    readonly property color markColour: root.urgent ? Appearance.colour.accent : root.hovered ? Appearance.colour.text : Appearance.colour.textDim

    Item {
        id: drawing

        anchors.centerIn: parent
        width: Appearance.sizes.traySlot
        height: Appearance.sizes.traySlot

        AppMark {
            anchors.centerIn: parent
            size: Appearance.sizes.trayIcon
            spec: Tray.markFor(root.item)
            color: root.markColour

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.trayGap / 2
        anchors.bottomMargin: -Appearance.sizes.trayGap / 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onEntered: root.requested(false)

        onPressed: root.longPressed = false

        onPressAndHold: {
            root.longPressed = true;
            root.requested(true);
        }

        onClicked: event => {

            if (root.longPressed) {
                root.longPressed = false;
                return;
            }

            if (event.button === Qt.MiddleButton)
                Tray.secondary(root.item);
            else if (event.button === Qt.RightButton)
                root.requested(true);
            else if (!Tray.activate(root.item))

                root.requested(true);
        }

        onWheel: event => {
            Tray.scroll(root.item, event.angleDelta.y);
            event.accepted = true;
        }
    }
}
