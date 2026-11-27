pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "month.js" as Month

Column {
    id: root

    required property date today

    property real span: 0
    readonly property real cell: root.span > 0 ? Math.floor((root.span - root.gutter) / 7) : Math.round(Appearance.font.size.small * 2.3)
    property int shownYear: root.today.getFullYear()
    property int shownMonth: root.today.getMonth()

    readonly property int todayKey: Month.keyOf(root.today)
    readonly property real gutter: TimeFormat.weekNumbers ? Math.round(Appearance.font.size.small * 2.2) : 0
    readonly property real rowHeight: Math.round(Math.min(root.cell, Appearance.font.size.small * 2.6) * 0.78)

    function page(by: int): void {
        const to = Month.shifted(root.shownYear, root.shownMonth, by);
        root.shownYear = to.year;
        root.shownMonth = to.month;
        wander.restart();
    }

    function home(): void {
        root.shownYear = root.today.getFullYear();
        root.shownMonth = root.today.getMonth();
    }

    onTodayChanged: if (!wander.running)
        root.home()

    spacing: Appearance.padding.small

    Timer {
        id: wander

        interval: 60000
        onTriggered: root.home()
    }

    WheelHandler {
        property real gathered: 0

        onWheel: event => {
            gathered += event.angleDelta.y;
            while (Math.abs(gathered) >= 120) {
                root.page(gathered < 0 ? 1 : -1);
                gathered -= gathered < 0 ? -120 : 120;
            }
        }
    }

    Item {
        width: root.gutter + root.cell * 7
        height: Math.round(root.cell * 0.9)

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            x: root.gutter + Math.round((root.cell - Appearance.font.size.small) / 2)
            text: Month.title(root.shownYear, root.shownMonth)
            font.weight: Font.DemiBold
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            Arrow {
                icon: "chevron_left"
                onClicked: root.page(-1)
            }

            Arrow {
                icon: "chevron_right"
                onClicked: root.page(1)
            }
        }
    }

    Row {
        Column {
            visible: TimeFormat.weekNumbers

            Item {
                width: root.gutter
                height: root.rowHeight
            }

            Repeater {
                model: TimeFormat.weekNumbers ? Month.cells(root.shownYear, root.shownMonth, TimeFormat.firstDay).filter(c => c.rowStart) : []

                delegate: StyledText {
                    required property var modelData

                    width: root.gutter
                    height: root.rowHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: TimeFormat.weekNumber(modelData.rowStart)
                    color: Appearance.colour.textFaint
                }
            }
        }

        Grid {
            columns: 7

            Repeater {
                model: TimeFormat.weekOrder

                delegate: StyledText {
                    required property int modelData

                    width: root.cell
                    height: root.rowHeight
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    text: TimeFormat.weekdayInitial(modelData)
                    color: Appearance.colour.textFaint
                }
            }

            Repeater {
                model: Month.cells(root.shownYear, root.shownMonth, TimeFormat.firstDay)

                delegate: Item {
                    id: day

                    required property var modelData

                    readonly property bool today: day.modelData.key === root.todayKey

                    width: root.cell
                    height: root.rowHeight

                    SquircleRect {
                        anchors.centerIn: parent
                        width: Math.min(parent.width, parent.height) - 2
                        height: width
                        pill: "object"
                        visible: day.today
                        color: Appearance.colour.text
                    }

                    StyledText {
                        anchors.centerIn: parent
                        text: day.modelData.day
                        font.weight: day.today ? Font.Bold : Font.Normal
                        color: day.today ? Appearance.colour.ink : day.modelData.inMonth ? Appearance.colour.text : Appearance.colour.textFaint
                        opacity: day.modelData.inMonth || day.today ? 1 : 0.5
                    }
                }
            }
        }
    }

    component Arrow: Item {
        id: arrow

        property string icon: ""

        signal clicked

        width: Math.round(root.cell * 0.9)
        height: arrow.width

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            opacity: arrowHover.hovered ? 1 : 0
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
