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

    property double quietAt: Date.now()
    readonly property var quietChoices: Notifications.hushChoices(root.quietAt)

    Timer {
        interval: 10000
        repeat: true
        running: !root.quiet && root.visible
        triggeredOnStart: true
        onTriggered: root.quietAt = Date.now()
    }

    readonly property real deckRoom: root.maxHeight > 0 ? Math.max(0, root.maxHeight - root.topInset - header.implicitHeight - controls.implicitHeight - root.gap * 3 - root.pad) : 100000

    readonly property real bottomInset: Notifications.history.length > 0 ? Math.max(0, Appearance.padding.small - Appearance.stroke.line - deck.footerShown) : root.pad
    readonly property real natural: root.topInset + column.implicitHeight + root.bottomInset

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
            icon: root.quiet ? "do_not_disturb_on" : "notifications"
            title: "Notifications"
            subtitle: root.subtitle
            onClosed: root.hide()
        }

        Item {
            id: controls

            width: parent.width
            implicitHeight: root.quiet ? quietOff.implicitHeight : quietChoices.implicitHeight

            StyledText {
                id: quietLabel

                anchors.left: parent.left
                y: (Math.max(Appearance.sizes.minTarget, Appearance.button.height(0)) - implicitHeight) / 2
                visible: !root.quiet
                text: "Quiet"
                color: Appearance.colour.textDim
            }

            Column {
                id: quietChoices

                anchors.left: quietLabel.right
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                visible: !root.quiet
                spacing: Appearance.padding.small * 1.5

                Flow {
                    width: parent.width
                    spacing: Appearance.padding.small

                    Repeater {
                        model: root.quietChoices

                        delegate: Button {
                            required property var modelData

                            size: 0
                            style: "ring"
                            text: modelData.text
                            detail: modelData.detail
                            onClicked: Notifications.quietTill(modelData.until)
                        }
                    }
                }

                Button {
                    size: 0
                    style: "ring"
                    text: "until I turn it off"
                    onClicked: Notifications.quietTill(0)
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.right: quietOff.left
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: quietOff.verticalCenter
                visible: root.quiet
                text: Notifications.quietLine || "Quiet"
                elide: Text.ElideRight
            }

            Button {
                id: quietOff

                anchors.right: parent.right
                visible: root.quiet
                size: 0
                style: "ring"
                text: "turn off"
                onClicked: Notifications.setQuiet(false, "")
            }
        }

        StyledText {
            visible: root.total === 0
            text: "Nothing new"
            color: Appearance.colour.textDim
        }

        AlertDeck {
            id: deck

            x: -root.pad
            width: root.width
            visible: Notifications.history.length > 0
            groups: Notifications.byApp(Notifications.history)
            fanned: 1
            maxHeight: root.deckRoom
            liftsAway: false

            onDismissed: entry => Notifications.forget(entry)
            onKept: entry => Notifications.forget(entry)
            onLifted: root.hide()
        }
    }
}
