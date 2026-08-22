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

            // THE ENTRY ITSELF, NEVER ITS `notification`.
            //
            // Every field below is the entry's own snapshot, because the
            // sender's live object is Quickshell's and it dies when the SENDER
            // says so: a close, or a replace chain ending in one, destroys it
            // and every read through the reference yields nothing afterwards.
            // Chatty apps (Discord above all, `notify-send -r`, progress
            // updates) close and replace constantly, so a list drawn through
            // that reference fills up with tombstones: a bare bell, no app, no
            // summary, no body, and a critical alert from a hung-up sender
            // stops colouring itself because its urgency went with the object.
            //
            // This is the row the popup card already learned: it was fixed
            // there and left standing here, so the SAME notification read
            // correctly as a popup and blank in the hub you go to precisely
            // because you missed the popup. See services/NotifEntry.qml, which
            // owns the copy and the argument for it, and Notifs.anyUrgent,
            // which is this read made twice wrong and now goes off the entry.
            //
            // Guarded with `?.` for the ordinary null case only, exactly as the
            // card guards `entry`: an entry is destroyed by Notifs when the
            // list drops it, and the list change tears this delegate down with
            // it, so there is no dangling-reference case here of the kind the
            // sender's object has.
            required property var modelData

            readonly property bool urgent: modelData?.urgency === NotificationUrgency.Critical

            width: root.width
            icon: Notifs.icon(modelData)
            label: modelData?.summary ?? ""
            // App and body on one line: the hub is a list, and a list whose rows
            // are three lines tall stops being scannable at about four entries.
            //
            // THE SHORT BODY when a parser knows one, because one line is the
            // hardest budget in the shell and this is the row that has always
            // been an ellipsis: a qBittorrent line spent its whole width on the
            // fansub group. See services/NotifBrief.qml.
            detail: [modelData?.appName, modelData?.brief || modelData?.body].filter(s => s).join(" - ")
            selected: row.urgent

            // FORGET, not dismiss. This list IS the hub, so there is nowhere
            // further back for a pinned notification to be kept; see
            // Notifs.forget, which is the door for exactly this.
            onActivated: Notifs.forget(modelData)
        }
    }
}
