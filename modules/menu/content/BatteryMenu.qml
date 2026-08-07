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
// ONE BLOCK, not a header and then a list. Everything the menu knows fits beside
// the tank, and the readouts are SPREAD to the tank's height rather than stacked
// at their natural spacing: the first line's top and the last line's bottom then
// land on the tank's own ends, so the two halves frame each other instead of one
// floating in the middle of the other.
Column {
    id: root

    spacing: Appearance.padding.normal

    // A line box, and the two-line block at the top of the column. StyledText
    // fixes its line box at 4/3 of the pixel size, so these are the heights the
    // readouts actually occupy, and the spread below is the room left over.
    readonly property int lineHeight: Math.round(Appearance.font.size.small * 4 / 3)
    readonly property int leadHeight: Math.round(Appearance.font.size.normal * 4 / 3) + lineHeight

    Row {
        width: parent.width
        visible: Battery.available
        spacing: Appearance.padding.large

        BatteryTank {
            id: tank

            level: Battery.percentage
            charging: Battery.charging
        }

        // WHATEVER THE TANK LEAVES, stated rather than implied: a line of text
        // that works its width out from its own length runs off the end of a
        // fixed panel, and "plugged in" at the 27px tier is wider than what is
        // left. Every line elides for the same reason.
        Column {
            id: stats

            width: parent.width - tank.width - parent.spacing
            height: tank.height

            // The gap is what is LEFT after the readouts, shared between them,
            // rather than a padding tier that happens to look close. Two gaps for
            // three blocks; see ~/.claude/rules/math-over-hardcoding.md.
            readonly property int gaps: Math.max(1, readouts.count - 1)
            spacing: Math.max(Appearance.padding.normal, (height - root.leadHeight - root.lineHeight * gaps) / gaps)

            Repeater {
                id: readouts

                model: !Battery.available ? [] : [
                    {
                        // The state leads, because it is the one thing the tank
                        // cannot draw: a tank at 76% looks the same whether that
                        // number is on its way up or on its way down. It is also
                        // the only one whose second line is a fact rather than a
                        // label, which is why it is the only one stacked.
                        lead: true,
                        value: Battery.state,
                        note: Battery.timeLabel() || "fully charged"
                    },
                    {
                        lead: false,
                        value: Battery.rate > 0 ? `${Battery.rate.toFixed(1)} W` : "idle",
                        // "input" rather than "charging" while it charges: the
                        // state above already says charging, and a menu that says
                        // one word twice reads as two facts. NOT while full,
                        // though `charging` covers that too: a full battery is
                        // taking nothing, and "idle / input" is a contradiction.
                        note: Battery.charging && !Battery.full ? "input" : "draw"
                    },
                    {
                        lead: false,
                        value: Battery.health > 0 ? `${Math.round(Battery.health)}%` : "unknown",
                        note: "health"
                    }
                ]

                // A LABEL BESIDE ITS VALUE rather than under it, which is
                // MenuRow's own inlineDetail argument: stacked is right where
                // there is no width to spare, and this column has plenty. Beside
                // and right-aligned it costs no height, spends the width on
                // something true, and turns the readouts into two columns that
                // can be scanned independently.
                delegate: Item {
                    id: readout

                    required property var modelData

                    width: stats.width
                    height: readout.modelData.lead ? root.leadHeight : root.lineHeight

                    StyledText {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        // Yields to the label beside it, never the other way
                        // round: the value is what is being read.
                        width: readout.modelData.lead ? parent.width : parent.width - note.width - Appearance.padding.normal

                        text: readout.modelData.value
                        font.pixelSize: readout.modelData.lead ? Appearance.font.size.normal : Appearance.font.size.small
                        color: readout.modelData.lead && Battery.low ? Appearance.colour.accent : Appearance.colour.text
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: note

                        anchors.left: readout.modelData.lead ? parent.left : undefined
                        anchors.right: readout.modelData.lead ? undefined : parent.right
                        anchors.bottom: parent.bottom

                        // Capped, so a wordy label cannot squeeze the value it
                        // belongs to down to an ellipsis.
                        width: readout.modelData.lead ? parent.width : Math.min(implicitWidth, parent.width * 0.4)
                        horizontalAlignment: readout.modelData.lead ? Text.AlignLeft : Text.AlignRight

                        text: readout.modelData.note
                        color: readout.modelData.lead ? Appearance.colour.textDim : Appearance.colour.textFaint
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
