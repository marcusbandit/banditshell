import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    readonly property real stageHeight: 200
    readonly property bool shown: SettingsState.v("weatherShow")
    readonly property bool imperial: SettingsState.v("weatherUnits") === "imperial"
    readonly property bool lost: SettingsState.weatherPlaceTrouble !== ""
    readonly property string sample: root.imperial ? "54°F" : "12°C"

    WallClock {
        id: clock

        precision: WallClock.Minutes
    }

    Item {
        id: island

        x: (root.width - width) / 2
        y: Appearance.padding.card
        width: Math.min(root.width - Appearance.padding.card * 2, 300)
        height: face.height + Appearance.padding.card * 2

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: Appearance.colour.surfaceSolid
        }

        Item {
            id: face

            readonly property real line: time.y + time.baselineOffset

            x: Appearance.padding.card
            y: Appearance.padding.card
            width: parent.width - Appearance.padding.card * 2
            height: face.line

            TextMetrics {
                id: clockInk

                font: time.font
                text: time.text
            }

            StyledText {
                id: time

                x: -clockInk.tightBoundingRect.x
                y: -(time.baselineOffset + clockInk.tightBoundingRect.y)
                text: `${TimeFormat.hourPart(clock.date)}:${TimeFormat.minutePart(clock.date)}`
                font.pixelSize: Appearance.font.size.display
            }

            StyledText {
                anchors.right: parent.right
                y: 0
                text: TimeFormat.dateText(clock.date, "brief")?.toLowerCase() ?? ""
                color: Appearance.colour.textDim
            }

            Row {
                anchors.right: parent.right
                y: face.line - temperature.baselineOffset
                spacing: Appearance.padding.hair
                visible: root.shown

                Icon {
                    anchors.verticalCenter: temperature.verticalCenter
                    name: root.lost ? "wrong_location" : "partly_cloudy_day"
                    size: Appearance.font.size.small
                    color: root.lost ? Appearance.colour.alarm : Appearance.colour.textDim
                }

                StyledText {
                    id: temperature

                    text: root.lost ? "" : root.sample
                    color: Appearance.colour.textDim
                }
            }
        }
    }

    SceneCaption {
        text: !root.shown ? "off · only the clock" : root.lost ? "place not found" : `beside the clock · in ${root.imperial ? "°F" : "°C"}`
    }
}
