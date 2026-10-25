import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content
import "../../services/dates.js" as Dates

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

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    WallClock {
        id: clock

        precision: WallClock.Minutes
        enabled: root.watched
    }

    Flickable {
        id: scroller

        anchors.fill: parent
        contentHeight: root.natural
        interactive: root.natural > height
        boundsBehavior: Flickable.StopAtBounds
        clip: interactive

        WheelStep {
            flick: scroller
        }

        Column {
            id: column

            x: root.pad
            y: Appearance.padding.large
            width: root.width - root.pad * 2
            spacing: Appearance.padding.card

            TaskHeader {
                width: parent.width
                icon: "calendar_month"
                title: TimeFormat.dateText(clock.date, "day") ?? ""
                subtitle: `${(TimeFormat.dateText(clock.date, "headline") ?? "").split(" ")[0]} · week ${Dates.isoWeek(clock.date)}`
                onClosed: root.hide()
            }

            CalendarMenu {
                width: parent.width
            }
        }
    }
}
