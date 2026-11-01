pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "month.js" as Month

WidgetCard {
    id: root

    property bool running: true

    property int shownYear: clock.date.getFullYear()
    property int shownMonth: clock.date.getMonth()
    readonly property int todayKey: Month.keyOf(clock.date)
    readonly property real cell: Math.floor(root.width - root.pad * 2) / 7

    function page(by: int): void {
        const to = Month.shifted(root.shownYear, root.shownMonth, by);
        root.shownYear = to.year;
        root.shownMonth = to.month;
    }

    WallClock {
        id: clock

        precision: WallClock.Minutes
        enabled: root.running
        onDateChanged: if (!wander.running) {
            root.shownYear = clock.date.getFullYear();
            root.shownMonth = clock.date.getMonth();
        }
    }

    Timer {
        id: wander

        interval: 60000
        onTriggered: {
            root.shownYear = clock.date.getFullYear();
            root.shownMonth = clock.date.getMonth();
        }
    }

    WheelHandler {
        property real gathered: 0

        onWheel: event => {
            gathered += event.angleDelta.y;
            while (Math.abs(gathered) >= 120) {
                root.page(gathered < 0 ? 1 : -1);
                gathered -= gathered < 0 ? -120 : 120;
            }
            wander.restart();
        }
    }

    Item {
        width: parent.width
        height: 28

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Month.title(root.shownYear, root.shownMonth)
            font.pixelSize: Appearance.font.size.normal
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Arrow {
                icon: "chevron_left"
                onClicked: {
                    root.page(-1);
                    wander.restart();
                }
            }

            Arrow {
                icon: "chevron_right"
                onClicked: {
                    root.page(1);
                    wander.restart();
                }
            }
        }
    }

    Grid {
        columns: 7

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            delegate: StyledText {
                required property string modelData

                width: root.cell
                height: Math.round(root.cell * 0.6)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: Appearance.colour.textFaint
            }
        }

        Repeater {
            model: Month.cells(root.shownYear, root.shownMonth)

            delegate: Item {
                id: day

                required property var modelData

                readonly property bool today: day.modelData.key === root.todayKey

                width: root.cell
                height: Math.round(root.cell * 0.72)

                SquircleRect {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, parent.height) - 4
                    height: width
                    pill: "object"
                    visible: day.today
                    color: Appearance.colour.accent
                }

                StyledText {
                    anchors.centerIn: parent
                    text: day.modelData.day
                    font.weight: day.today ? Font.DemiBold : Font.Normal
                    color: day.today ? Appearance.colour.accentText : day.modelData.inMonth ? Appearance.colour.text : Appearance.colour.textFaint
                    opacity: day.modelData.inMonth || day.today ? 1 : 0.5
                }
            }
        }
    }

    component Arrow: Item {
        id: arrow

        property string icon: ""

        signal clicked

        width: 28
        height: 28

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            opacity: lit.value

            Follow {
                id: lit

                target: arrowHover.hovered ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }
        }

        Icon {
            anchors.centerIn: parent
            name: arrow.icon
            color: Appearance.colour.textDim
        }

        HoverHandler {
            id: arrowHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: arrow.clicked()
        }
    }
}
