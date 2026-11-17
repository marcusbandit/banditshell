import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Column {
    id: root

    property var row: ({})

    width: parent ? parent.width : 0

    SettingsRowFrame {
        width: root.width
        visible: !Battery.available
        off: true
        icon: "battery_unknown"
        label: "No battery"
        detail: "this machine runs on mains · these come back when one shows up"
    }

    SettingsRowFrame {
        width: root.width
        visible: Battery.available
        interactive: false
        icon: Battery.icon()
        label: `${Battery.percent}% · ${Battery.state}`
        detail: Battery.timeLabel() || Battery.note
        onPointed: SettingsView.hovered = root.row
    }

    SettingsRowFrame {
        width: root.width
        visible: Battery.available
        interactive: false
        icon: "health_and_safety"
        label: "Health"
        detail: Battery.healthKnown ? `${Math.round(Battery.health)}% of new${Battery.cycles > 0 ? ` · ${Battery.cycles} cycles` : ""}` : "not known yet"
        onPointed: SettingsView.hovered = root.row
    }

    SettingsRowFrame {
        width: root.width
        visible: Battery.available
        interactive: false
        icon: "electric_bolt"
        label: Battery.flow === "in" ? "Charging at" : Battery.flow === "out" ? "Drawing" : "Power"
        detail: Battery.flow === "idle" ? "idle" : `${Battery.rate.toFixed(1)} W`
        onPointed: SettingsView.hovered = root.row
    }
}
