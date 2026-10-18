import QtQuick
import qs.config
import qs.services
import qs.modules.menu.content

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.15

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real natural: Appearance.padding.large + column.implicitHeight + root.pad

    readonly property int running: Clock.timers.filter(t => !t.finished).length
    readonly property int armed: Clock.alarms.filter(a => a.armed).length

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

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
                icon: "timer"
                title: "Timers"
                subtitle: [root.running > 0 ? `${root.running} running` : "No timer running", root.armed > 0 ? `${root.armed} alarm${root.armed === 1 ? "" : "s"} set` : ""].filter(s => s).join(" · ")
                onClosed: root.hide()
            }

            ClockMenu {
                width: parent.width
            }
        }
    }
}
