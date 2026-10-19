pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Item {
    id: root

    required property real inset

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property var source: Polkit.active ? Polkit : PasswordRequest.active ? PasswordRequest : Keyring

    readonly property bool open: root.source.active && root.source.screenName === root.screenName

    readonly property Item maskItem: catcher

    readonly property bool needsKeyboard: root.open

    readonly property bool shown: reveal.value > 0.001

    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(panel.width, panel.height) / 2)
        }
    ]

    readonly property string sourceName: root.source === Polkit ? "Polkit" : root.source === PasswordRequest ? "Wi-Fi" : "Keyring"
    readonly property string sourceIcon: root.source === Polkit ? "admin_panel_settings" : root.source === PasswordRequest ? "wifi_password" : "key"

    readonly property bool asksForSecret: root.source.kind === "password"

    readonly property string goLabel: root.sentence(root.source.continueLabel || (root.asksForSecret ? "unlock" : "continue"))
    readonly property string stopLabel: root.sentence(root.source.cancelLabel || "cancel")

    function sentence(text: string): string {
        const plain = text.replace(/_/g, "");
        return plain.charAt(0).toUpperCase() + plain.slice(1);
    }

    function takeKeys(): void {
        if (root.asksForSecret)
            field.land();
        else
            keys.forceActiveFocus();
    }

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

    Follow {
        id: tall

        speed: Appearance.animation.resizeSpeed
        target: panel.implicitHeight
        epsilon: 0.5

        onTargetChanged: if (!root.open)
            tall.snap()
    }

    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (!event.isAutoRepeat)
                    root.answer();
                event.accepted = true;
                return;
            }
            if (event.key !== Qt.Key_Escape)
                return;
            Appearance.instantly();
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

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.source.refuse()
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real centredY: Math.max(root.inset, (root.height - panel.height) / 2)

        x: (root.width - width) / 2
        y: panel.bandY + (panel.centredY - panel.bandY) * reveal.value
        width: Math.min(Appearance.sizes.launcherWidth, root.width - root.inset * 2)

        implicitHeight: Appearance.padding.large * 2 + layout.implicitHeight
        height: tall.value * reveal.value

        visible: panel.height > 0
        enabled: root.open

        MouseArea {
            anchors.fill: parent
        }

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: layout

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: panel.width - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                Item {
                    id: header

                    width: parent.width
                    height: Math.max(glyph.implicitHeight, Appearance.font.line.normal)

                    Icon {
                        id: glyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.sizes.launcherIcon
                        size: Appearance.font.size.normal
                        name: root.asksForSecret ? "lock" : root.sourceIcon
                        color: root.source.warning ? Appearance.colour.alarm : Appearance.colour.textFaint
                    }

                    SecretField {
                        id: field

                        anchors.left: glyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        height: parent.height
                        visible: root.asksForSecret

                        framed: false
                        textSize: Appearance.font.size.normal
                        markSize: Appearance.font.size.normal
                        placeholder: root.sentence(root.source.placeholder ?? (Keyring.passwordNew ? "new password" : "password"))
                        busy: root.source.busy ?? false
                        alarm: !!root.source.warning

                        onAccepted: secret => root.source.submit(secret)
                        onCancelled: root.source.refuse()

                        readonly property int asked: Keyring.asked + Polkit.asked + PasswordRequest.asked
                        onAskedChanged: field.clear()
                    }

                    StyledText {
                        anchors.left: glyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.asksForSecret
                        text: root.source.title || root.sourceName
                        font.pixelSize: Appearance.font.size.normal
                        elide: Text.ElideRight
                    }
                }

                Separator {
                    width: parent.width
                }

                Column {
                    id: page

                    x: Appearance.padding.normal
                    width: parent.width - Appearance.padding.normal * 2
                    topPadding: Appearance.padding.small
                    bottomPadding: Appearance.padding.small
                    spacing: Appearance.padding.large

                    Column {
                        width: page.width
                        spacing: Appearance.padding.hair

                        StyledText {
                            width: page.width
                            text: root.source.title || root.sourceName
                            font.pixelSize: Appearance.font.size.large
                            font.bold: true
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: page.width
                            visible: text !== ""
                            text: root.source.requester
                            color: Appearance.colour.textFaint
                            elide: Text.ElideRight
                        }
                    }

                    Column {
                        width: page.width
                        spacing: Appearance.padding.normal
                        visible: !!root.source.message || !!root.source.description || !!root.source.warning

                        StyledText {
                            width: page.width
                            visible: text !== ""
                            text: root.source.message
                            font.pixelSize: Appearance.font.size.normal
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: page.width
                            visible: text !== ""
                            text: root.source.description
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.textDim
                            wrapMode: Text.Wrap
                        }

                        StyledText {
                            width: page.width
                            visible: text !== ""
                            text: root.source.warning
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.alarm
                            wrapMode: Text.Wrap
                        }
                    }

                    Item {
                        width: page.width
                        height: Math.max(choice.height, choiceLabel.implicitHeight)
                        visible: !!root.source.choiceLabel

                        Toggle {
                            id: choice

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.source.choiceChosen

                            onToggled: root.source.choose(!root.source.choiceChosen)
                        }

                        StyledText {
                            id: choiceLabel

                            anchors.left: choice.right
                            anchors.right: parent.right
                            anchors.leftMargin: Appearance.padding.normal
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.source.choiceLabel
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.textDim
                            wrapMode: Text.Wrap

                            TapHandler {
                                onTapped: root.source.choose(!root.source.choiceChosen)
                            }
                        }
                    }
                }

                Separator {
                    width: parent.width
                }

                Item {
                    width: parent.width
                    height: Appearance.font.line.small + Appearance.padding.small

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.padding.normal

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.sourceIcon
                            size: Appearance.font.size.normal
                            color: Appearance.colour.accent
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.sourceName
                            color: Appearance.colour.textFaint
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.small
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.padding.normal

                        Action {
                            label: root.goLabel
                            cap: "↵"
                            strong: true

                            onPressed: root.answer()
                        }

                        Rule {}

                        Action {
                            label: root.stopLabel
                            cap: "Esc"

                            onPressed: root.source.refuse()
                        }
                    }
                }
            }
        }
    }

    component Action: Row {
        id: action

        property string label: ""
        property string cap: ""
        property bool strong: false

        signal pressed

        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.normal

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: action.label
            color: action.strong || actionHover.hovered ? Appearance.colour.text : Appearance.colour.textDim
        }

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            text: action.cap
            lit: actionHover.hovered
        }

        HoverHandler {
            id: actionHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: action.pressed()
        }
    }

    component Rule: Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 1
        height: Appearance.font.line.small
        color: Appearance.colour.separator
    }

    component KeyCap: Item {
        id: cap

        property string text: ""
        property bool lit: false

        width: Math.max(height, capText.implicitWidth + Appearance.padding.normal * 2)
        height: capText.implicitHeight + Appearance.padding.hair * 2

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: cap.lit ? Appearance.colour.accent : Appearance.colour.fill
        }

        StyledText {
            id: capText

            anchors.centerIn: parent
            text: cap.text
            color: cap.lit ? Appearance.colour.accentText : Appearance.colour.textDim
        }
    }
}
