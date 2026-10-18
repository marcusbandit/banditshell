import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/weather.js" as Forecast

Item {
    id: root

    property bool watched: false
    property real maxHeight: 0
    readonly property real span: 1.5

    signal hide
    signal act(var notice)
    signal open(string key)

    readonly property real pad: Appearance.padding.card
    readonly property real natural: Appearance.padding.large + column.implicitHeight + root.pad
    readonly property var days: Weather.forecast
    readonly property var range: Forecast.weekRange(root.days)
    readonly property real barWidth: Appearance.padding.small
    readonly property real barHeight: Appearance.font.line.normal * 3

    implicitHeight: root.maxHeight > 0 ? Math.min(root.natural, root.maxHeight) : root.natural

    onWatchedChanged: if (root.watched)
        Weather.refresh()

    Component.onCompleted: if (root.watched)
        Weather.refresh()

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
                icon: Weather.icon
                title: Weather.ready ? `${Weather.temperature} ${Weather.summary.trim()}` : "Weather"
                subtitle: Weather.place
                onClosed: root.hide()
            }

            StyledText {
                width: parent.width
                visible: !Weather.forecastReady
                text: Weather.wanted ? "Loading the forecast" : "Weather is turned off in settings"
                color: Appearance.colour.textDim
            }

            Row {
                id: strip

                width: parent.width
                visible: Weather.forecastReady

                Repeater {
                    model: root.days

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property var bar: Forecast.barOf(cell.modelData, root.range)
                        readonly property real fillHeight: Math.max(root.barWidth, (cell.bar.to - cell.bar.from) * root.barHeight)

                        width: strip.width / Math.max(1, root.days.length)
                        height: stack.implicitHeight

                        Column {
                            id: stack

                            width: parent.width
                            spacing: Appearance.padding.small

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: cell.index === 0 ? "Today" : Qt.locale().dayName(Forecast.dateOf(cell.modelData.date).getDay(), Locale.ShortFormat)
                                color: cell.index === 0 ? Appearance.colour.text : Appearance.colour.textDim
                                elide: Text.ElideRight
                            }

                            Item {
                                width: parent.width
                                height: Appearance.font.line.large

                                Icon {
                                    anchors.centerIn: parent
                                    name: cell.modelData.icon
                                    size: Appearance.font.line.large
                                    fill: 1
                                    color: Appearance.colour.accent
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: `${cell.modelData.high}°`
                                font.pixelSize: Appearance.font.size.normal
                                color: Appearance.colour.text
                            }

                            Item {
                                width: parent.width
                                height: root.barHeight

                                SquircleRect {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: root.barWidth
                                    height: parent.height
                                    radius: height / 2
                                    cornerPower: 2
                                    color: Appearance.colour.fillStrong

                                    SquircleRect {
                                        width: parent.width
                                        height: cell.fillHeight
                                        y: Math.min(parent.height - height, (1 - cell.bar.to) * parent.height)
                                        radius: height / 2
                                        cornerPower: 2
                                        color: Appearance.colour.accent
                                    }
                                }
                            }

                            StyledText {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: `${cell.modelData.low}°`
                                font.pixelSize: Appearance.font.size.normal
                                color: Appearance.colour.textDim
                            }

                            StyledText {
                                width: parent.width
                                height: Appearance.font.line.small
                                horizontalAlignment: Text.AlignHCenter
                                text: Forecast.rainText(cell.modelData)
                                color: Appearance.colour.textFaint
                            }
                        }
                    }
                }
            }
        }
    }
}
