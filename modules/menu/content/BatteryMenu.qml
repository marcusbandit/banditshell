import QtQuick
import qs.config
import qs.components
import qs.services

// Battery. This one is real, and adapts to what the machine actually has.
//
// On a desktop it says so rather than drawing an empty battery, because UPower
// hands over a display device whether or not there is a battery behind it and
// the difference between "0%" and "none" matters.
//
// ONE BLOCK, not a header and then a list. Everything the menu knows fits
// beside the tank, and the tank is sized to be exactly as tall as it: a fixed
// panel with a fixed drawing in it has one honest width for whatever sits next
// to the drawing, and one honest height for the drawing. Laid out the other way
// round, with the tank at whatever size it was drawn at, the column beside it
// was two lines of text floating in the middle of an empty half-panel.
Column {
    id: root

    spacing: Appearance.padding.normal

    Row {
        width: parent.width
        visible: Battery.available
        spacing: Appearance.padding.large

        // AS TALL AS WHAT IS BESIDE IT. The tank takes a height and works its
        // own width back out of it, so this is the only number the layout has to
        // decide. Its own minimum still wins if the readouts ever get shorter
        // than the number the tank has to hold.
        BatteryTank {
            id: tank

            height: stats.implicitHeight
            level: Battery.percentage
            charging: Battery.charging
        }

        // WHATEVER THE TANK LEAVES, stated rather than implied: a line of text
        // that works its width out from its own length runs off the end of a
        // fixed panel, and "plugged in" at the 27px tier is wider than what is
        // left. Every line elides for the same reason.
        //
        // Nothing in here may WRAP. The tank's height is this column's implicit
        // height and this column's width is what the tank leaves, so a line free
        // to grow taller as it gets narrower would be a loop.
        Column {
            id: stats

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - tank.width - parent.spacing
            spacing: Appearance.padding.large

            Repeater {
                model: !Battery.available ? [] : [
                    {
                        // The state leads, because it is the one thing the tank
                        // cannot draw: a tank at 76% looks the same whether that
                        // number is on its way up or on its way down.
                        lead: true,
                        value: Battery.state,
                        note: Battery.timeLabel() || "fully charged"
                    },
                    {
                        lead: false,
                        value: Battery.rate > 0 ? `${Battery.rate.toFixed(1)} W` : "idle",
                        // "input" rather than "charging" while it charges: the
                        // state above already says charging, and a menu that
                        // says one word twice reads as two facts.
                        note: Battery.charging ? "input" : "draw"
                    },
                    {
                        lead: false,
                        value: Battery.health > 0 ? `${Math.round(Battery.health)}%` : "unknown",
                        note: "health"
                    }
                ]

                delegate: Column {
                    required property var modelData

                    width: stats.width
                    spacing: 0

                    StyledText {
                        width: parent.width
                        text: parent.modelData.value
                        font.pixelSize: parent.modelData.lead ? Appearance.font.size.normal : Appearance.font.size.small
                        color: parent.modelData.lead && Battery.low ? Appearance.colour.accent : Appearance.colour.text
                        elide: Text.ElideRight
                    }

                    StyledText {
                        width: parent.width
                        text: parent.modelData.note
                        color: parent.modelData.lead ? Appearance.colour.textDim : Appearance.colour.textFaint
                        elide: Text.ElideRight
                    }
                }
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
            font.pixelSize: Appearance.font.size.normal
        }

        StyledText {
            text: "this machine runs on mains"
            color: Appearance.colour.textDim
        }
    }
}
