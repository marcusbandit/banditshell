import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property var failure: Activities.entries.find(e => e.id === "moment:wifi") ?? null
    readonly property string name: root.failure?.data?.name ?? ""

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
    onFailureChanged: if (!root.failure && root.watched)
        root.leave()

    Column {
        id: column

        x: root.pad
        y: Appearance.padding.large
        width: root.width - root.pad * 2
        spacing: Appearance.padding.card

        TaskHeader {
            width: parent.width
            icon: "signal_wifi_bad"
            tone: Appearance.colour.failed
            title: root.name || "Wi-Fi"
            subtitle: "Couldn't join"
            onClosed: root.leave()
        }

        StyledText {
            width: parent.width
            text: WifiJoin.reason(root.failure?.data?.kind ?? "")
            wrapMode: Text.Wrap
        }

        Row {
            anchors.right: parent.right
            spacing: Appearance.padding.small

            Button {
                text: "Close"
                style: "plate"
                onClicked: {
                    const failure = root.failure;
                    root.leave();
                    if (failure)
                        Activities.remove(failure.id);
                }
            }

            Button {
                text: root.failure?.data?.kind === "password" ? "Enter password" : "Try again"
                icon: "refresh"
                style: "accent"
                onClicked: {
                    const failure = root.failure;
                    root.leave();
                    if (failure)
                        Moments.retryWifi(failure);
                }
            }
        }
    }
}
