pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.1

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real topInset: Appearance.padding.large
    readonly property real gap: Appearance.padding.card

    readonly property int total: Notifications.history.filter(e => !e.leaving).length
    readonly property bool quiet: Notifications.quiet

    readonly property string subtitle: {
        const count = `${root.total} notification${root.total === 1 ? "" : "s"}`;
        return root.quiet ? `${count} · quiet mode on` : count;
    }

    readonly property real deckRoom: root.maxHeight > 0 ? Math.max(0, root.maxHeight - root.topInset - header.implicitHeight - controls.implicitHeight - root.gap * 3 - root.pad) : 100000

    readonly property real natural: root.topInset + column.implicitHeight + root.pad

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    onWatchedChanged: {
        if (root.watched)
            Notifications.pause(root);
        else
            Notifications.resume(root);
    }

    Component.onCompleted: if (root.watched)
        Notifications.pause(root)

    Component.onDestruction: Notifications.resume(root)

    Column {
        id: column

        x: root.pad
        y: root.topInset
        width: root.width - root.pad * 2
        spacing: root.gap

        TaskHeader {
            id: header

            width: parent.width
            icon: "notifications"
            title: "Notifications"
            subtitle: root.subtitle
            onClosed: root.hide()
        }

        Item {
            id: controls

            width: parent.width
            implicitHeight: quietButton.implicitHeight

            Button {
                id: quietButton

                size: 0
                style: "plate"
                icon: "notifications_paused"
                text: "Quiet mode"
                checkable: true
                checked: Notifications.quiet

                onToggled: Notifications.setQuiet(!Notifications.quiet, "")
            }

            StyledText {
                anchors.left: quietButton.right
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                anchors.verticalCenter: quietButton.verticalCenter
                visible: root.quiet
                text: Notifications.endsNote
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: root.total === 0
            text: "Nothing new"
            color: Appearance.colour.textDim
        }

        AlertDeck {
            x: -root.pad
            width: root.width
            visible: Notifications.history.length > 0
            entries: Notifications.history
            fanned: 1
            maxHeight: root.deckRoom

            onDismissed: entry => Notifications.forget(entry)
        }
    }
}
