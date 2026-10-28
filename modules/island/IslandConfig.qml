import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.25

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property string home: Quickshell.env("HOME") ?? ""
    readonly property string shownPath: root.home && Config.path.startsWith(root.home + "/") ? "~" + Config.path.slice(root.home.length) : Config.path
    readonly property string where: Config.problemLine > 0 ? `Line ${Config.problemLine}, column ${Config.problemColumn}` : Config.problem || "It can't be read"
    readonly property int snippetChars: Math.max(8, Math.floor((column.width - Appearance.padding.normal * 2) / Math.max(1, metrics.advanceWidth("M"))))
    readonly property string snippet: Config.unreadable ? Config.problemSnippet(root.snippetChars) : ""

    implicitHeight: Appearance.padding.large + column.implicitHeight + root.pad

    property bool leaving: false

    function leave(): void {
        if (root.leaving)
            return;
        root.leaving = true;
        root.hide();
    }

    onWatchedChanged: if (root.watched)
        root.leaving = false

    Connections {
        target: Config

        function onUnreadableChanged(): void {
            if (!Config.unreadable && root.watched)
                root.leave();
        }
    }

    FontMetrics {
        id: metrics

        font: code.font
    }

    Column {
        id: column

        x: root.pad
        y: Appearance.padding.large
        width: root.width - root.pad * 2
        spacing: Appearance.padding.normal

        Item {
            width: parent.width
            height: Math.max(badge.height, shut.implicitHeight)

            Icon {
                id: badge

                anchors.verticalCenter: parent.verticalCenter
                name: "warning"
                size: Appearance.font.line.small
                fill: 1
                color: Appearance.colour.warning
            }

            StyledText {
                anchors.left: badge.right
                anchors.leftMargin: Appearance.padding.small
                anchors.right: shut.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Config broken"
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            Button {
                id: shut

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "close"
                style: "bare"
                onClicked: root.leave()
            }
        }

        StyledText {
            width: parent.width
            text: root.where
            font.pixelSize: Appearance.font.size.large
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            visible: Config.problemReason !== ""
            text: Config.problemReason
            color: Appearance.colour.warning
            wrapMode: Text.Wrap
        }

        Item {
            width: parent.width
            height: code.implicitHeight + Appearance.padding.normal * 2
            visible: root.snippet !== ""

            SquircleRect {
                anchors.fill: parent
                color: Appearance.colour.fill
            }

            StyledText {
                id: code

                x: Appearance.padding.normal
                y: Appearance.padding.normal
                width: parent.width - Appearance.padding.normal * 2
                text: root.snippet
                textFormat: Text.PlainText
                font.family: Appearance.font.family
                wrapMode: Text.NoWrap
                clip: true
            }
        }

        StyledText {
            width: parent.width
            text: root.shownPath
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
            elide: Text.ElideLeft
        }

        StyledText {
            width: parent.width
            text: `Changes aren't saved until it's fixed. The shell runs on ${Config.everRead ? "your last good settings" : "the defaults"}.`
            wrapMode: Text.Wrap
        }

        Button {
            anchors.right: parent.right
            text: "Open config.json"
            icon: "open_in_new"
            style: "accent"
            onClicked: {
                root.leave();
                System.openWith(Config.path);
            }
        }
    }
}
