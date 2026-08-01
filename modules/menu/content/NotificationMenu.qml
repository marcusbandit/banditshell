pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

// The hub: everything that has arrived and not been dismissed.
//
// Popups are the thing you might catch; this is the thing you come back to. It
// shows the same notifications with the timing removed, because "when it
// disappears" is a property of a popup and not of a notification.
Column {
    id: root

    spacing: Appearance.padding.small

    Item {
        width: parent.width
        implicitHeight: title.implicitHeight

        StyledText {
            id: title

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: Notifs.count ? `${Notifs.count} notification${Notifs.count === 1 ? "" : "s"}` : "nothing waiting"
            color: Appearance.colour.textDim
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifs.any
            text: "clear all"
            font.pixelSize: Appearance.font.size.small
            color: clearPress.containsMouse ? Appearance.colour.text : Appearance.colour.textFaint

            MouseArea {
                id: clearPress

                anchors.fill: parent
                anchors.margins: -Appearance.padding.small
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifs.clear()
            }
        }
    }

    Separator {
        width: parent.width
        visible: Notifs.any
    }

    Repeater {
        model: Notifs.history

        delegate: MenuRow {
            id: row

            required property var modelData

            readonly property var n: modelData.notification
            readonly property bool urgent: n?.urgency === NotificationUrgency.Critical

            width: root.width
            icon: Notifs.icon(n)
            label: n?.summary ?? ""
            // App and body on one line: the hub is a list, and a list whose rows
            // are three lines tall stops being scannable at about four entries.
            detail: [n?.appName, n?.body].filter(s => s).join(" - ")
            selected: row.urgent

            onActivated: Notifs.dismiss(modelData)
        }
    }
}
