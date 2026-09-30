pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import qs.config
import qs.components
import qs.services

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

            readonly property bool urgent: modelData?.urgency === NotificationUrgency.Critical

            width: root.width
            icon: Notifs.icon(modelData)
            label: modelData?.summary ?? ""

            detail: [modelData?.appName, modelData?.brief || modelData?.body].filter(s => s).join(" - ")
            selected: row.urgent

            onActivated: Notifs.forget(modelData)
        }
    }
}
