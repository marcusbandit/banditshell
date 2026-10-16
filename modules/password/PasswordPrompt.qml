pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Item {
    id: root

    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property var source: Polkit.active ? Polkit : PasswordRequest.active ? PasswordRequest : Keyring

    readonly property bool open: root.source.active && root.source.screenName === root.screenName

    readonly property Item maskItem: catcher

    readonly property bool needsKeyboard: root.open

    readonly property bool asksForSecret: root.source.kind === "password"

    readonly property string goLabel: root.source.continueLabel || (root.asksForSecret ? "unlock" : "continue")
    readonly property string stopLabel: root.source.cancelLabel || "cancel"

    function answer(): void {
        if (root.asksForSecret) {
            field.submit();
            return;
        }
        root.source.confirm();
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
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

        speed: Appearance.animation.resizeSpeed
        target: body.implicitHeight + Appearance.padding.huge * 2

        onTargetChanged: if (!root.open)
            tall.snap()
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            root.source.refuse();
            event.accepted = true;
        }
    }

    onOpenChanged: {
        if (!root.open)
            Qt.callLater(field.clear);
        else if (!root.asksForSecret)
            Qt.callLater(keys.forceActiveFocus);
    }

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

        onClicked: root.source.refuse()
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

        SquircleRect {
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
                    text: root.source.title || "Keyring"
                    font.pixelSize: Appearance.font.size.normal
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: !!root.source.requester
                    text: root.source.requester
                    color: Appearance.colour.textFaint
                }

                BalancedText {
                    width: parent.width
                    visible: !!root.source.message
                    text: root.source.message
                    color: Appearance.colour.textDim
                }

                BalancedText {
                    width: parent.width
                    visible: !!root.source.description
                    text: root.source.description
                    color: Appearance.colour.textFaint
                }

                SecretField {
                    id: field

                    width: parent.width
                    visible: root.asksForSecret
                    placeholder: root.source.placeholder ?? (Keyring.passwordNew ? "new password" : "password")
                    busy: root.source.busy ?? false
                    alarm: !!root.source.warning

                    onAccepted: secret => root.source.submit(secret)
                    onCancelled: root.source.refuse()

                    readonly property int asked: Keyring.asked + Polkit.asked + PasswordRequest.asked
                    onAskedChanged: field.clear()
                }

                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: !!root.source.warning
                    text: root.source.warning
                    color: Appearance.colour.alarm
                }

                Item {
                    width: parent.width
                    height: Math.max(choice.height, choiceLabel.implicitHeight)
                    visible: !!root.source.choiceLabel

                    Toggle {
                        id: choice

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.source.choiceChosen

                        onToggled: root.source.choose(!root.source.choiceChosen)
                    }

                    BalancedText {
                        id: choiceLabel

                        anchors.left: choice.right
                        anchors.right: parent.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.source.choiceLabel
                        color: Appearance.colour.textDim

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.source.choose(!root.source.choiceChosen)
                        }
                    }
                }

                ButtonPair {
                    anchors.right: parent.right

                    actions: [
                        {
                            text: root.stopLabel
                        },
                        {
                            text: root.goLabel
                        }
                    ]
                    primary: 1

                    onTriggered: index => {
                        if (index === 0)
                            root.source.refuse();
                        else
                            root.answer();
                    }
                }
            }
        }
    }
}
