import QtQuick
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
    readonly property string where: Config.problemLine > 0 ? `Line ${Config.problemLine}, column ${Config.problemColumn}` : Config.problem || "It can't be read"

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

    Column {
        id: column

        x: root.pad
        y: Appearance.padding.large
        width: root.width - root.pad * 2
        spacing: Appearance.padding.card

        TaskHeader {
            width: parent.width
            icon: "warning"
            tone: Appearance.colour.warning
            title: "Config broken"
            subtitle: root.where
            onClosed: root.leave()
        }

        StyledText {
            width: parent.width
            text: Config.path
            color: Appearance.colour.textDim
            wrapMode: Text.WrapAnywhere
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
