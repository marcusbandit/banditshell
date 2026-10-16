pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import "../files/markdown.js" as Markdown
import "../../services/assistant.js" as Logic

Item {
    id: root

    property string typed: ""
    property real iconSize: Appearance.sizes.launcherIcon
    property real rowHeight: Appearance.sizes.rowHeight
    property real bodyLimit: Appearance.font.line.normal * 12

    readonly property bool current: Assistant.shownFor(root.typed.trim())
    readonly property bool recalled: !root.current && Assistant.following && Assistant.answeredTurns > 0 && Logic.askOf(root.typed) !== null
    readonly property bool shown: root.current || root.recalled
    property bool released: false

    readonly property bool holds: root.current && !root.released && Assistant.finished && !Assistant.streaming && !!Assistant.result
    readonly property bool busy: root.current && !root.released && Assistant.streaming
    readonly property bool rewriting: Assistant.kind === "rewrite"
    readonly property bool replacing: root.rewriting && Assistant.typeable
    readonly property bool waiting: Assistant.streaming && !Assistant.answer.trim()

    readonly property real textLeft: Appearance.padding.normal * 2 + root.iconSize

    signal copied
    signal replaced
    signal continued

    function primary(): void {
        if (root.replacing)
            root.replaced();
        else
            root.copied();
    }

    onTypedChanged: root.released = false

    visible: root.shown
    implicitHeight: root.shown ? layout.implicitHeight + Appearance.padding.small * 2 : 0
    height: implicitHeight

    property int waited: 0

    Timer {
        interval: 1000
        repeat: true
        running: root.waiting && root.visible
        onRunningChanged: root.waited = 0
        onTriggered: root.waited += 1
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        opacity: root.holds ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.fade.fast
            }
        }
    }

    Column {
        id: layout

        y: Appearance.padding.small
        width: parent.width
        spacing: Appearance.padding.small

        Item {
            width: parent.width
            height: root.rowHeight - Appearance.padding.small * 2

            Icon {
                id: glyph

                anchors.left: parent.left
                anchors.leftMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                size: root.iconSize
                name: root.rewriting ? Assistant.action?.icon ?? "auto_awesome" : "auto_awesome"
                color: Assistant.streaming ? Appearance.colour.accent : Appearance.colour.textDim

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.animation.fast
                    }
                }
            }

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: root.textLeft
                anchors.right: status.left
                anchors.rightMargin: Appearance.padding.large
                anchors.verticalCenter: parent.verticalCenter
                text: Assistant.question
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            StyledText {
                id: status

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter
                text: root.waiting && root.waited > 0 ? `${Assistant.modelName} · ${root.waited} s` : Assistant.modelName
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }
        }

        Flickable {
            id: scroller

            x: root.textLeft
            width: parent.width - root.textLeft - Appearance.padding.normal
            height: Math.min(body.implicitHeight, root.recalled ? metrics.lineSpacing * 2 : root.bodyLimit)
            visible: body.text !== ""
            contentHeight: body.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            clip: true

            property bool pinned: true

            onMovementEnded: scroller.pinned = scroller.contentY >= scroller.contentHeight - scroller.height - 2
            onContentHeightChanged: if (scroller.pinned && Assistant.streaming)
                scroller.contentY = Math.max(0, scroller.contentHeight - scroller.height)

            Connections {
                target: Assistant

                function onStartedAtChanged(): void {
                    scroller.pinned = true;
                    scroller.contentY = 0;
                    root.released = false;
                }
            }

            FontMetrics {
                id: metrics

                font: body.font
            }

            Text {
                id: body

                width: scroller.width
                text: Assistant.error ? Assistant.error : root.rewriting ? (Assistant.finished ? Assistant.result.trim() : Assistant.answer) : Markdown.inert(Markdown.flattenHeadings(Assistant.answer.trim()))
                textFormat: Assistant.error || root.rewriting ? Text.PlainText : Text.MarkdownText
                wrapMode: Text.Wrap
                font.family: Appearance.font.family
                font.pixelSize: Appearance.font.size.normal
                renderType: Text.NativeRendering
                color: Assistant.error ? Appearance.colour.alarm : root.recalled ? Appearance.colour.textFaint : Appearance.colour.text
                linkColor: Appearance.colour.accent

                onLinkActivated: link => {
                    if (Logic.webLink(link))
                        Quickshell.execDetached(["xdg-open", link]);
                }
            }
        }

        Row {
            x: root.textLeft
            spacing: Appearance.padding.small
            visible: !root.recalled && (Assistant.finished || Assistant.streaming)

            Button {
                visible: root.replacing && Assistant.finished
                icon: "find_replace"
                text: "Replace selection"
                style: root.holds ? "tonal" : "outlined"
                size: 0
                onClicked: root.replaced()
            }

            Button {
                visible: Assistant.finished
                icon: "content_copy"
                text: "Copy"
                style: root.holds && !root.replacing ? "tonal" : "outlined"
                size: 0
                onClicked: root.copied()
            }

            Button {
                visible: !root.rewriting && Assistant.finished
                icon: "forum"
                text: "Continue in chat"
                style: "outlined"
                size: 0
                onClicked: root.continued()
            }

            Button {
                visible: Assistant.streaming
                icon: "stop"
                text: "Stop"
                style: "outlined"
                size: 0
                onClicked: Assistant.stop()
            }

            Button {
                visible: !root.rewriting && !Assistant.streaming && Assistant.answeredTurns > 1
                icon: "restart_alt"
                text: "New chat"
                style: "outlined"
                size: 0
                onClicked: Assistant.newChat()
            }
        }
    }
}
