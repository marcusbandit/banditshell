import QtQuick
import qs.config
import qs.components

Grid {
    id: root

    property bool stacked: false

    readonly property BatteryGlance battery: BatteryGlance {}

    columns: root.stacked ? 1 : 2
    spacing: root.stacked ? Appearance.padding.small / 2 : Appearance.padding.small
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    visible: root.battery.shown

    BatteryMeter {
        level: root.battery.level
        charging: root.battery.charging
        low: root.battery.low
        colour: root.battery.colour
    }

    StyledText {
        text: `${root.battery.percent}%`
        font.pixelSize: Appearance.font.size.small
        color: root.battery.labelColour
    }
}
