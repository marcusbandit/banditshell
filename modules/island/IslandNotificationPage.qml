import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.notifications

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    property var entry: null
    readonly property real span: 1

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real natural: Appearance.padding.large + column.implicitHeight + root.pad

    readonly property bool gone: !root.entry || root.entry.leaving || !Notifications.history.includes(root.entry)

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    function forget(): void {
        Notifications.forget(root.entry);
    }

    onWatchedChanged: {
        if (root.watched)
            Notifications.pause(root);
        else
            Notifications.resume(root);
    }

    onGoneChanged: if (root.gone && root.watched)
        root.hide()

    onEntryChanged: if (root.entry)
        root.entry.unfolded = true

    Component.onDestruction: Notifications.resume(root)

    Flickable {
        id: scroller

        anchors.fill: parent
        contentHeight: root.natural
        interactive: root.natural > height
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

        WheelStep {
            flick: scroller
        }

        Column {
            id: column

            x: root.pad
            y: Appearance.padding.large
            width: root.width - root.pad * 2
            spacing: Appearance.padding.card

            TaskHeader {
                width: parent.width
                icon: "notifications"
                title: "Notification"
                onClosed: root.hide()
            }

            NotificationCard {
                width: parent.width
                entry: root.gone ? null : root.entry
                density: "page"
                visible: !!entry

                onReleased: root.forget()
                onKept: root.forget()
            }

            Item {
                width: parent.width
                implicitHeight: dismiss.implicitHeight

                Button {
                    id: dismiss

                    anchors.right: parent.right
                    size: 0
                    style: "ring"
                    icon: "delete"
                    text: "dismiss"

                    onClicked: root.forget()
                }
            }
        }
    }
}
