import QtQuick
import qs.config
import qs.components
import qs.services

// Battery. This one is real, and adapts to what the machine actually has.
//
// On a desktop it says so rather than drawing an empty battery, because UPower
// hands over a display device whether or not there is a battery behind it and
// the difference between "0%" and "none" matters.
Column {
    id: root

    spacing: Appearance.padding.normal

    // THE LEVEL, DRAWN. The tank says the percentage as a height and as a
    // number, so the headline beside it does not have to: it says the two things
    // a height cannot, which are which direction the level is going and how long
    // it has left. The read-only Slider that used to sit under this went with
    // the icon, being a third telling of the one fact the tank draws.
    Row {
        width: parent.width
        visible: Battery.available
        spacing: Appearance.padding.large

        BatteryTank {
            id: tank

            level: Battery.percentage
            charging: Battery.charging
        }

        // WHATEVER THE TANK LEAVES, and stated rather than implied: this is a
        // fixed-width panel with a fixed-width tank in it, so the column beside
        // it has exactly one width it can be, and a line of text that works it
        // out from its own length instead runs off the end of the menu. "plugged
        // in" at the 18px tier is wider than what is left.
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - tank.width - parent.spacing
            spacing: Appearance.padding.small

            StyledText {
                width: parent.width
                text: Battery.state
                color: Battery.low ? Appearance.colour.accent : Appearance.colour.text
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                text: Battery.timeLabel() || "fully charged"
                color: Appearance.colour.textDim
                elide: Text.ElideRight
            }
        }
    }

    // A desktop, which UPower still hands a display device for; see the note on
    // Battery.available.
    Column {
        visible: !Battery.available
        spacing: 0

        StyledText {
            text: "no battery"
            font.pixelSize: Appearance.font.size.large
        }

        StyledText {
            text: "this machine runs on mains"
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
        }
    }

    Separator {
        width: parent.width
        visible: Battery.available
    }

    Repeater {
        // No `schedule` row: the estimate is the headline's second line now, and
        // a menu that says the same thing twice reads as two facts.
        model: !Battery.available ? [] : [
            {
                icon: "bolt",
                label: Battery.rate > 0 ? `${Battery.rate.toFixed(1)} W` : "idle",
                detail: Battery.charging ? "charging" : "draw"
            },
            {
                icon: "favorite",
                label: Battery.health > 0 ? `${Math.round(Battery.health)}%` : "unknown",
                detail: "health"
            }
        ]

        delegate: MenuRow {
            required property var modelData

            width: root.width
            interactive: false
            icon: modelData.icon
            label: modelData.label
            detail: modelData.detail
        }
    }
}
