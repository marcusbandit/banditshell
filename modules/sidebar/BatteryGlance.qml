import QtQuick
import qs.config
import qs.services

QtObject {
    readonly property bool shown: Battery.available && Config.values.sidebar.status.battery
    readonly property real level: Battery.percentage
    readonly property int percent: Battery.percent
    readonly property bool charging: Battery.charging
    readonly property bool low: Battery.low
    readonly property string icon: Battery.icon()

    readonly property color colour: low ? Appearance.colour.alarm : charging ? Appearance.colour.accent : Appearance.colour.text
    readonly property color labelColour: low ? Appearance.colour.alarm : Appearance.colour.textDim
}
