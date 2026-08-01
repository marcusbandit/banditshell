pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import Quickshell.Services.Notifications

// One notification, on screen.
//
// Like a menu panel it draws no background: it reports its rectangle and the
// chassis melts it in. It grows its WIDTH out of the right band for the same
// reason a menu does, so it reads as the shell swelling rather than as a card
// dropped on the desktop.
Item {
    id: root

    required property var entry
    required property real fullWidth

    signal dismissed

    readonly property var notification: entry?.notification ?? null
    readonly property bool urgent: !!notification && notification.urgency === NotificationUrgency.Critical

    property real reveal: 0

    width: fullWidth * reveal
    height: body.implicitHeight + Appearance.padding.large * 2

    Component.onCompleted: grow.target = 1

    Follow {
        id: grow

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
        onValueChanged: root.reveal = value
    }

    // Declared BEFORE the contents: a catch-all that comes last covers the
    // action buttons inside, and every one of them dismissed the notification
    // instead of doing what it said.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: root.dismissed()
    }

    // Contents at full width, clipped by the growing panel, so nothing reflows
    // while it arrives.
    Item {
        anchors.fill: parent
        clip: true

        Item {
            id: body

            x: Appearance.padding.large
            y: Appearance.padding.large
            width: root.fullWidth - Appearance.padding.large * 2
            implicitHeight: Math.max(glyph.implicitHeight, text.implicitHeight)

            Icon {
                id: glyph

                anchors.left: parent.left
                anchors.top: parent.top
                name: Notifs.icon(root.notification)
                color: root.urgent ? Appearance.colour.accent : Appearance.colour.textDim
            }

            Column {
                id: text

                anchors.left: glyph.right
                anchors.leftMargin: Appearance.padding.normal
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: 0

                StyledText {
                    width: parent.width
                    visible: !!root.notification?.appName
                    text: root.notification?.appName ?? ""
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textFaint
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    text: root.notification?.summary ?? ""
                    elide: Text.ElideRight
                }

                StyledText {
                    width: parent.width
                    visible: !!root.notification?.body
                    text: root.notification?.body ?? ""
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textDim
                    wrapMode: Text.Wrap
                    // Long bodies are common and a notification is not a document.
                    maximumLineCount: 4
                    elide: Text.ElideRight
                }

                // Whatever the sender offered. Rendered only when there is
                // something to render, so most notifications stay one block.
                Row {
                    visible: (root.notification?.actions?.length ?? 0) > 0
                    topPadding: Appearance.padding.small
                    spacing: Appearance.padding.small

                    Repeater {
                        model: root.notification?.actions ?? []

                        delegate: G2Rect {
                            required property var modelData

                            implicitWidth: actionLabel.implicitWidth + Appearance.padding.normal * 2
                            implicitHeight: actionLabel.implicitHeight + Appearance.padding.small * 2
                            width: implicitWidth
                            height: implicitHeight
                            radius: Appearance.rounding.small
                            color: actionPress.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill

                            StyledText {
                                id: actionLabel

                                anchors.centerIn: parent
                                text: modelData.text
                                font.pixelSize: Appearance.font.size.small
                            }

                            MouseArea {
                                id: actionPress

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    modelData.invoke();
                                    root.dismissed();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
