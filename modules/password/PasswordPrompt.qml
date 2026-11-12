pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "../../services/password-asks.js" as PasswordAsks

Item {
    id: root

    required property real inset

    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property var source: PasswordAsks.current(Polkit, PasswordRequest, Keyring) ?? Keyring

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

    readonly property string home: Quickshell.env("HOME") ?? ""

    readonly property var ask: PasswordAsks.describe(root.source === Polkit ? {
        source: "polkit",
        message: Polkit.message,
        actionId: Polkit.actionId,
        identity: Polkit.identity,
        label: Polkit.label,
        inputPrompt: Polkit.inputPrompt,
        warning: Polkit.warning,
        user: Quickshell.env("USER") ?? ""
    } : root.source === PasswordRequest ? {
        source: "request",
        title: PasswordRequest.title,
        message: PasswordRequest.message,
        secret: PasswordRequest.secret,
        facts: PasswordRequest.facts,
        hint: PasswordRequest.hint,
        placeholder: PasswordRequest.placeholder,
        warning: PasswordRequest.warning
    } : {
        source: "keyring",
        kind: Keyring.kind,
        title: Keyring.title,
        message: Keyring.message,
        description: Keyring.description,
        warning: Keyring.warning,
        choiceLabel: Keyring.choiceLabel,
        passwordNew: Keyring.passwordNew,
        requester: Keyring.requester,
        cause: Keyring.cause,
        command: Keyring.callerCommand,
        home: root.home
    })

    readonly property bool asksForSecret: root.source.kind === "password"

    readonly property color tone: root.ask.family === "admin" ? Appearance.colour.warning : Appearance.colour.accent

    readonly property real factLabelWidth: Math.max(0, ...root.ask.facts.map(fact => factMetrics.advanceWidth(fact[0])))
    readonly property real detailLabelWidth: Math.max(0, ...root.ask.details.map(detail => detailMetrics.advanceWidth(detail[0])))

    readonly property string goLabel: root.sentence(root.source.continueLabel || (root.asksForSecret ? "unlock" : "continue"))
    readonly property string stopLabel: root.sentence(root.source.cancelLabel || "cancel")

    property bool detailed: false

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
        if (!root.open) {
            Qt.callLater(field.clear);
            root.detailed = false;
        } else if (!root.asksForSecret) {
            Qt.callLater(keys.forceActiveFocus);
        }
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
                    width: layout.width
                    height: Math.max(glyph.implicitHeight, Appearance.font.line.normal)

                    Icon {
                        id: glyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.sizes.launcherIcon
                        size: Appearance.font.size.normal
                        name: root.ask.glyph
                        fallback: "password"
                        color: root.ask.warning ? Appearance.colour.alarm : root.tone
                    }

                    SecretField {
                        id: field

                        anchors.left: glyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        height: parent.height
                        visible: root.asksForSecret

                        framed: false
                        capsLock: Keymap.capsLock
                        onCapsAsked: Keymap.refresh()
                        textSize: Appearance.font.size.normal
                        markSize: Appearance.font.size.normal
                        placeholder: root.ask.placeholder || "Password"
                        busy: root.source.busy ?? false
                        alarm: !!root.ask.warning

                        onAccepted: secret => root.source.submit(secret)
                        onCancelled: root.source.refuse()

                        readonly property int asked: Keyring.asked + Polkit.asked + PasswordRequest.asked
                        onAskedChanged: field.clear()
                    }

                    StyledText {
                        anchors.left: glyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !root.asksForSecret
                        text: root.ask.secret
                        font.pixelSize: Appearance.font.size.normal
                        elide: Text.ElideRight
                    }
                }

                Separator {
                    width: layout.width
                }

                Column {
                    id: page

                    x: Appearance.padding.normal
                    width: layout.width - Appearance.padding.normal * 2
                    topPadding: Appearance.padding.small
                    bottomPadding: Appearance.padding.small
                    spacing: Appearance.padding.card

                    StyledText {
                        width: page.width
                        visible: root.asksForSecret
                        text: root.ask.secret
                        font.pixelSize: Appearance.font.size.large
                        font.bold: true
                        wrapMode: Text.Wrap
                    }

                    Column {
                        width: page.width
                        visible: root.ask.facts.length > 0
                        spacing: Appearance.padding.small

                        Repeater {
                            model: root.ask.facts

                            Item {
                                id: fact

                                required property var modelData

                                width: page.width
                                height: factValue.implicitHeight

                                StyledText {
                                    text: fact.modelData[0]
                                    font.pixelSize: Appearance.font.size.normal
                                    color: Appearance.colour.textFaint
                                }

                                StyledText {
                                    id: factValue

                                    x: root.factLabelWidth + Appearance.padding.large
                                    width: page.width - x
                                    text: fact.modelData[1]
                                    font.pixelSize: Appearance.font.size.normal
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }

                    StyledText {
                        width: page.width
                        visible: text !== ""
                        text: root.ask.warning || root.ask.hint
                        font.pixelSize: root.asksForSecret ? Appearance.font.size.small : Appearance.font.size.normal
                        color: root.ask.warning ? Appearance.colour.alarm : root.asksForSecret ? Appearance.colour.textDim : Appearance.colour.text
                        wrapMode: Text.Wrap
                    }

                    Row {
                        visible: !!root.ask.choice
                        spacing: Appearance.padding.normal

                        Toggle {
                            id: choice

                            anchors.verticalCenter: parent.verticalCenter
                            checked: root.source.choiceChosen

                            onToggled: root.source.choose(!root.source.choiceChosen)
                        }

                        StyledText {
                            width: Math.min(implicitWidth, page.width - choice.width - Appearance.padding.normal)
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.ask.choice
                            color: Appearance.colour.textDim
                            elide: Text.ElideRight

                            TapHandler {
                                onTapped: root.source.choose(!root.source.choiceChosen)
                            }
                        }
                    }

                    Column {
                        width: page.width
                        visible: root.detailed
                        spacing: Appearance.padding.small

                        Repeater {
                            model: root.ask.details

                            Item {
                                id: detail

                                required property var modelData

                                width: page.width
                                height: detailValue.implicitHeight

                                StyledText {
                                    text: detail.modelData[0]
                                    color: Appearance.colour.textFaint
                                }

                                StyledText {
                                    id: detailValue

                                    x: root.detailLabelWidth + Appearance.padding.large
                                    width: page.width - x
                                    text: detail.modelData[1]
                                    color: Appearance.colour.textDim
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                }

                Separator {
                    width: layout.width
                }

                Item {
                    width: layout.width
                    height: Appearance.font.line.small + Appearance.padding.small

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Appearance.padding.small
                        visible: root.ask.details.length > 0

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: root.detailed ? "expand_less" : "expand_more"
                            size: Appearance.font.size.normal
                            color: moreHover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.detailed ? "Hide details" : "Details"
                            color: moreHover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
                        }

                        HoverHandler {
                            id: moreHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: root.detailed = !root.detailed
                        }
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
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

    FontMetrics {
        id: factMetrics

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
    }

    FontMetrics {
        id: detailMetrics

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
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
