import QtQuick
import qs.config
import qs.components
import qs.services

WidgetCard {
    id: root

    readonly property var today: Weather.forecastReady ? Weather.forecast[0] : null

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
