import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/weather.js" as Forecast

WidgetCard {
    id: root

    readonly property var days: Weather.forecastReady ? Forecast.upcoming(Weather.forecast, clock.date.getTime()) : []
    readonly property var today: root.days.length > 0 && Forecast.isToday(root.days[0], clock.date.getTime()) ? root.days[0] : null

    WallClock {
        id: clock

        precision: WallClock.Minutes
    }

    title: Weather.place

    Item {
        width: parent.width
        height: Math.max(mark.height, words.implicitHeight)

        Icon {
            id: mark

            anchors.verticalCenter: parent.verticalCenter
            name: Weather.icon
            size: Math.round(Appearance.font.iconSize * 3)
            fill: 1
            color: Appearance.colour.accent
        }

        StyledText {
            id: degrees

            x: mark.width + Appearance.padding.card
            anchors.verticalCenter: parent.verticalCenter
            text: Weather.temperature
            font.family: Appearance.font.lock
            font.pixelSize: Appearance.font.size.display
            font.weight: Font.DemiBold
        }

        Column {
            id: words

            x: degrees.x + degrees.width + Appearance.padding.card
            width: parent.width - x
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: Weather.summary.trim()
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: !!root.today
                text: root.today ? `${root.today.high}° high, ${root.today.low}° low` : ""
                color: Appearance.colour.textFaint
                elide: Text.ElideRight
            }
        }
    }
}
