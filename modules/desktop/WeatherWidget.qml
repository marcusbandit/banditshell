pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/weather.js" as Forecast
import "weather-facts.js" as Facts

DeskWidget {
    id: root

    readonly property real pad: Appearance.padding.card
    readonly property var days: Weather.forecastReady ? Forecast.upcoming(Weather.forecast, clock.date.getTime()) : []
    readonly property var today: root.days.length > 0 && Forecast.isToday(root.days[0], clock.date.getTime()) ? root.days[0] : null
    readonly property var facts: Facts.facts(Weather.current, Weather.imperial)
    readonly property var slots: Facts.hours(Weather.wttrData, clock.date.getTime(), Weather.imperial, 8)
    readonly property var span: Forecast.weekRange(root.days.slice(0, 7))
    readonly property string range: root.today ? `H ${root.today.high}°  L ${root.today.low}°` : ""

    key: "weather"
    fallbackSize: "medium"

    WallClock {
        id: clock

        precision: WallClock.Minutes
    }

    small: Item {
        implicitWidth: smallRow.implicitWidth + root.pad * 2
        implicitHeight: smallRow.implicitHeight + Appearance.padding.normal * 2

        Row {
            id: smallRow

            x: root.pad
            y: Appearance.padding.normal
            spacing: Appearance.padding.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.icon
                size: Math.round(Appearance.font.iconSize * 1.6)
                fill: 1
                color: Appearance.colour.text
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.temperature
                font.family: Appearance.font.lock
                font.pixelSize: Appearance.font.size.large
                font.weight: Font.DemiBold
            }
        }
    }

    medium: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 22) + root.pad * 2
        implicitHeight: now.implicitHeight + root.pad * 2

        Now {
            id: now

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
        }
    }

    large: Item {
        implicitWidth: Math.round(Appearance.font.size.small * 28) + root.pad * 2
        implicitHeight: body.implicitHeight + root.pad * 2

        Column {
            id: body

            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2
            spacing: Appearance.padding.large

            Now {
                width: parent.width
            }

            Row {
                id: hourly

                readonly property real cell: root.slots.length > 0 ? Math.floor(width / root.slots.length) : 0

                width: parent.width
                visible: root.slots.length > 0

                Repeater {
                    model: root.slots

                    delegate: Column {
                        id: slot

                        required property var modelData

                        width: hourly.cell
                        spacing: Appearance.padding.hair

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: TimeFormat.clock(slot.modelData.hour, 0).replace(/:00/, "")
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                        }

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: Weather.iconFor(slot.modelData.code, slot.modelData.hour < 6 || slot.modelData.hour >= 20)
                            fill: 1
                            color: Appearance.colour.textDim
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${slot.modelData.temp}°`
                            font.weight: Font.DemiBold
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: slot.modelData.rain >= 20 ? `${slot.modelData.rain}%` : " "
                            color: Appearance.colour.textFaint
                            font.pixelSize: Appearance.font.size.small
                        }
                    }
                }
            }

            Column {
                width: parent.width
                visible: root.days.length > 1
                spacing: Appearance.padding.small

                Repeater {
                    model: root.days.slice(0, 7)

                    delegate: Item {
                        id: dayRow

                        required property var modelData
                        required property int index

                        readonly property var bar: Forecast.barOf(dayRow.modelData, root.span)

                        width: parent.width
                        height: Math.max(dayName.implicitHeight, dayIcon.height)

                        StyledText {
                            id: dayName

                            width: Math.round(Appearance.font.size.small * 4)
                            anchors.verticalCenter: parent.verticalCenter
                            text: dayRow.index === 0 && root.today ? "Today" : Qt.locale().dayName(Forecast.dateOf(dayRow.modelData.date).getDay(), Locale.ShortFormat)
                            color: Appearance.colour.textDim
                        }

                        Icon {
                            id: dayIcon

                            x: dayName.width
                            anchors.verticalCenter: parent.verticalCenter
                            name: dayRow.modelData.icon
                            fill: 1
                            color: Appearance.colour.textDim
                        }

                        StyledText {
                            id: dayLow

                            x: dayIcon.x + dayIcon.width + Appearance.padding.normal
                            width: Math.round(Appearance.font.size.small * 2.2)
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: `${dayRow.modelData.low}°`
                            color: Appearance.colour.textFaint
                        }

                        Item {
                            id: track

                            x: dayLow.x + dayLow.width + Appearance.padding.normal
                            width: dayHigh.x - x - Appearance.padding.normal
                            height: 4
                            anchors.verticalCenter: parent.verticalCenter

                            SquircleRect {
                                anchors.fill: parent
                                pill: "object"
                                color: Appearance.colour.fill
                            }

                            SquircleRect {
                                x: track.width * dayRow.bar.from
                                width: Math.max(track.height, track.width * (dayRow.bar.to - dayRow.bar.from))
                                height: track.height
                                pill: "object"
                                color: Appearance.colour.textDim
                            }
                        }

                        StyledText {
                            id: dayHigh

                            anchors.right: parent.right
                            width: Math.round(Appearance.font.size.small * 2.2)
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: Text.AlignRight
                            text: `${dayRow.modelData.high}°`
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }
        }
    }

    component Now: Column {
        spacing: Appearance.padding.normal

        StyledText {
            width: parent.width
            text: Weather.place
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }

        Row {
            spacing: Appearance.padding.normal

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: Weather.icon
                size: Math.round(Appearance.font.iconSize * 2.6)
                fill: 1
                color: Appearance.colour.text
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: Weather.temperature
                font.family: Appearance.font.lock
                font.pixelSize: Appearance.font.size.display
                font.weight: Font.DemiBold
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                leftPadding: Appearance.padding.small

                StyledText {
                    text: Weather.summary.trim()
                }

                StyledText {
                    visible: root.range !== ""
                    text: root.range
                    color: Appearance.colour.textDim
                }
            }
        }

        Row {
            spacing: Appearance.padding.large
            visible: !!root.facts

            Fact {
                icon: "thermostat"
                text: root.facts?.feels ? `Feels like ${root.facts.feels}` : ""
            }

            Fact {
                icon: "air"
                text: root.facts?.wind ?? ""
            }

            Fact {
                icon: "humidity_percentage"
                text: root.facts?.humidity ?? ""
            }
        }
    }

    component Fact: Row {
        id: fact

        property string icon: ""
        property string text: ""

        visible: fact.text !== ""
        spacing: Appearance.padding.hair

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: fact.icon
            size: Appearance.icon.small
            color: Appearance.colour.textFaint
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: fact.text
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }
    }
}
