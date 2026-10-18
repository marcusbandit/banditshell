import QtQuick
import qs.config
import qs.services
import qs.modules.menu.content

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.25

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real natural: Appearance.padding.large + column.implicitHeight + root.pad

    readonly property color tone: Update.state === Update.failed ? Appearance.colour.updateFailed : Update.state === Update.downloaded ? Appearance.colour.updateReady : Update.state === Update.available ? Appearance.colour.updateAvailable : Appearance.colour.accent

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    property bool shown: false

    onWatchedChanged: {
        Qt.callLater(() => root.shown = root.watched);
        if (root.watched && !Update.checking && !Update.busy)
            Update.check();
    }

    Component.onCompleted: Qt.callLater(() => root.shown = root.watched)

    Flickable {
        anchors.fill: parent
        contentHeight: root.natural
        interactive: root.natural > height
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

        Column {
            id: column

            x: root.pad
            y: Appearance.padding.large
            width: root.width - root.pad * 2
            spacing: Appearance.padding.card

            TaskHeader {
                width: parent.width
                icon: Update.state === Update.failed ? "error" : Update.state === Update.downloaded ? "restart_alt" : "system_update_alt"
                tone: root.tone
                title: "BanditShell"
                subtitle: Update.checking ? "Checking GitHub" : Update.checkedAt.getTime() > 0 ? `${Update.branch} · checked ${Update.ago(Update.checkedAt)}` : Update.branch
                onClosed: root.hide()
            }

            UpdateMenu {
                width: parent.width
                showing: root.shown
            }
        }
    }
}
