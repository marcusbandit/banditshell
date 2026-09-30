pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property bool open: Keyring.active && Keyring.screenName === root.screenName

    readonly property Item maskItem: catcher

    readonly property bool needsKeyboard: root.open

    readonly property bool asksForSecret: Keyring.kind === "password"

    readonly property string goLabel: Keyring.continueLabel || (root.asksForSecret ? "unlock" : "continue")
    readonly property string stopLabel: Keyring.cancelLabel || "cancel"

    function answer(): void {
        if (root.asksForSecret) {
            field.submit();
            return;
        }
        Keyring.confirm();
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.open ? 1 : 0

        epsilon: 0.005
    }

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "M"
    }

    readonly property real cardWidth: Math.min(root.holeWidth - Appearance.padding.huge * 2, em.advanceWidth * 56)

    Follow {
        id: tall

        speed: Appearance.anim.resizeSpeed
        target: body.implicitHeight + Appearance.padding.huge * 2

        onTargetChanged: if (!root.open)
            tall.snap()
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            Keyring.refuse();
            event.accepted = true;
        }
    }

    onOpenChanged: if (root.open && !root.asksForSecret)
        Qt.callLater(keys.forceActiveFocus)

    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim
        opacity: reveal.value
        visible: reveal.value > 0.001
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: Keyring.refuse()
    }

    Item {
        id: card

        x: root.holeX + (root.holeWidth - root.cardWidth) / 2
        y: root.holeY + (root.holeHeight - height) / 2
        width: root.cardWidth
        height: tall.value

        visible: reveal.value > 0.001
        enabled: root.open
        opacity: reveal.value

        transformOrigin: Item.Center
        scale: 1 - (1 - reveal.value) / 12

        G2Rect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface

            stroke: Appearance.colour.seam
            strokeWidth: Appearance.sizes.seam

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Appearance.padding.huge
                anchors.rightMargin: Appearance.padding.huge
                spacing: Appearance.padding.normal

                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Keyring.title || "Keyring"
                    font.pixelSize: Appearance.font.size.normal
                }

                BalancedText {
                    width: parent.width
                    visible: !!Keyring.message
                    text: Keyring.message
                    color: Appearance.colour.textDim
                }

                BalancedText {
                    width: parent.width
                    visible: !!Keyring.description
                    text: Keyring.description
                    color: Appearance.colour.textFaint
                }

                SecretField {
                    id: field

                    width: parent.width
                    visible: root.asksForSecret
                    placeholder: Keyring.passwordNew ? "new password" : "password"
                    alarm: !!Keyring.warning

                    onAccepted: secret => Keyring.submit(secret)
                    onCancelled: Keyring.refuse()

                    readonly property int asked: Keyring.asked
                    onAskedChanged: field.clear()
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: !!Keyring.warning
                    text: Keyring.warning
                    color: Appearance.colour.alarm
                }

                Item {
                    width: parent.width
                    height: Math.max(choice.height, choiceLabel.implicitHeight)
                    visible: !!Keyring.choiceLabel

                    Toggle {
                        id: choice

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Keyring.choiceChosen

                        onToggled: Keyring.choose(!Keyring.choiceChosen)
                    }

                    BalancedText {
                        id: choiceLabel

                        anchors.left: choice.right
                        anchors.right: parent.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: Keyring.choiceLabel
                        color: Appearance.colour.textDim

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Keyring.choose(!Keyring.choiceChosen)
                        }
                    }
                }

                Row {
                    anchors.right: parent.right
                    spacing: Appearance.padding.normal

                    G2Rect {
                        width: stopMark.implicitWidth + Appearance.padding.large * 2
                        height: em.height * 2
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.fillStrong
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.sizes.seam
                        opacity: stopHit.containsMouse ? 1 : 0.75

                        StyledText {
                            id: stopMark

                            anchors.centerIn: parent
                            text: root.stopLabel
                            color: Appearance.colour.textDim
                        }

                        MouseArea {
                            id: stopHit

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Keyring.refuse()
                        }
                    }

                    G2Rect {
                        id: go

                        readonly property bool ready: !root.asksForSecret || !field.empty

                        width: goMark.implicitWidth + Appearance.padding.huge * 2
                        height: em.height * 2
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.accent
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.sizes.seam
                        opacity: go.ready ? (goHit.containsMouse ? 1 : 0.9) : 0.35

                        StyledText {
                            id: goMark

                            anchors.centerIn: parent
                            text: root.goLabel

                            color: Appearance.colour.accentText
                        }

                        MouseArea {
                            id: goHit

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: go.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.answer()
                        }
                    }
                }
            }
        }
    }
}
