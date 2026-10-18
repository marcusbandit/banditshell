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
    readonly property real natural: Appearance.padding.large + column.implicitHeight + root.pad

    readonly property var rows: Privacy.listeners
    readonly property string device: root.rows.find(r => r.device !== "")?.device ?? ""

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    onWatchedChanged: if (root.watched)
        Privacy.listen()

    Connections {
        target: Privacy
        enabled: root.watched

        function onUsagesChanged(): void {
            Privacy.listen();
        }
    }

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
                icon: "mic"
                title: "Microphone"
                subtitle: root.rows.length === 0 ? "nothing is listening" : root.device !== "" ? root.device : `${root.rows.length} listening`
                onClosed: root.hide()
            }

            Column {
                width: parent.width
                spacing: Appearance.padding.normal

                Repeater {
                    model: root.rows

                    Column {
                        id: row

                        required property var modelData

                        width: parent.width
                        spacing: Appearance.padding.hair

                        StyledText {
                            width: parent.width
                            text: row.modelData.name
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            visible: text !== ""
                            text: [row.modelData.command, row.modelData.processes > 1 ? `${row.modelData.processes} processes` : row.modelData.pid > 0 ? `pid ${row.modelData.pid}` : ""].filter(part => part !== "").join(" · ")
                            color: Appearance.colour.textDim
                            font.pixelSize: Appearance.font.size.small
                            elide: Text.ElideMiddle
                        }
                    }
                }
            }
        }
    }
}
