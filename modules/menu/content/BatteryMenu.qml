pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The battery page of the menu.
//
// Two blocks, because there are two questions and they are not the same one.
// The top block is about RIGHT NOW: the tank on the left, readouts on the right,
// spread to the tank's height so the top line and the bottom line land level
// with the tank's ends. The bottom block is about the CELL ITSELF, how worn it
// is and how fast it is wearing, which moves over months and would be nonsense
// as a fourth line in a column that changes every minute.
//
// On a desktop there is no battery, so both hide and the "no battery" block
// shows instead. UPower hands over a device either way, which is why this is
// checked rather than assumed.
Column {
    id: root

    spacing: Appearance.padding.normal

    // How tall a line of text is. StyledText makes its line box 4/3 of the font
    // size, so these are the real heights of the readouts; the spread below
    // divides up whatever height is left over.
    readonly property int lineHeight: Math.round(Appearance.font.size.small * 4 / 3)
    readonly property int leadHeight: Math.round(Appearance.font.size.normal * 4 / 3) + lineHeight

    // The readouts, top to bottom. A function rather than an inline array
    // because the charge line only exists on a device that reports watt-hours,
    // and the spread below asks the Repeater for its count, so a row that comes
    // and goes re-divides the spacing on its own.
    function readouts(): var {
        if (!Battery.available)
            return [];

        const rows = [
            {
                // The state leads, because it is the one thing the tank cannot
                // draw: 76% looks the same going up as going down. It is also
                // the only one whose second line is a fact rather than a label,
                // which is why it is the only one stacked.
                lead: true,
                value: Battery.state,
                note: Battery.timeLabel() || "fully charged"
            }
        ];

        // WHAT IS ACTUALLY IN THE CELL, which the percentage cannot say: 24% of
        // a battery that has lost a tenth of its capacity is less charge than
        // 24% was a year ago, and the tank cannot show that because the tank is
        // drawn against today's full.
        if (Battery.capacity > 0)
            rows.push({
                lead: false,
                value: `${Battery.energy.toFixed(1)} Wh`,
                note: `of ${Battery.capacity.toFixed(1)}`
            });

        rows.push({
            lead: false,
            value: Battery.rate > 0 ? `${Battery.rate.toFixed(1)} W` : "idle",
            // "input" while charging rather than "charging", since the state
            // above already says that. Not while full: a full battery takes
            // nothing, and "idle / input" would contradict itself.
            note: Battery.charging && !Battery.full ? "input" : "draw"
        });

        return rows;
    }

    // "2026-08-10" into "10 aug". Split rather than parsed, because `new Date`
    // on a bare ISO day reads it as UTC and shows the day before for anyone
    // west of Greenwich, which for a label that says when something started is
    // exactly the sort of quiet wrongness nobody checks.
    readonly property var months: ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    function since(key: string): string {
        const parts = key.split("-");
        if (parts.length < 3)
            return key;
        return `${Number(parts[2])} ${root.months[Number(parts[1]) - 1] ?? ""}`;
    }

    // WHAT THE LOG HAS SEEN, or an honest admission that it has not seen
    // anything yet. A meter that draws a trend from one reading is inventing
    // one, so the first days say what they are instead.
    function trend(): string {
        if (!Battery.firstSample)
            return "starting to watch";
        if (!Battery.tracking)
            return `watching since ${root.since(Battery.firstSample.d)}`;

        // Signed by hand. `lostWh` is first minus last, so positive is wear and
        // wants a minus in front of it; the other way round happens too, when
        // the firmware revises its own estimate upward after a full cycle, and
        // showing that as a gain is more honest than hiding it.
        const lost = Battery.lostWh;
        const sign = lost >= 0 ? "-" : "+";
        return `${sign}${Math.abs(lost).toFixed(1)} Wh since ${root.since(Battery.firstSample.d)}`;
    }

    // ---- RIGHT NOW ---------------------------------------------------------

    Row {
        width: parent.width
        visible: Battery.available
        spacing: Appearance.padding.large

        // The battery drawing. Everything about how it looks lives in
        // components/BatteryTank.qml.
        BatteryTank {
            id: tank

            level: Battery.percentage
            charging: Battery.charging
            // The water wears the warning too, or the menu would contradict the
            // mark that was just clicked.
            liquid: Battery.low ? Appearance.colour.alarm : Appearance.colour.accent
        }

        // The text side. Takes whatever width the tank left over, stated rather
        // than left to the text: a line that sizes itself to its own length
        // runs off the end of a fixed-width panel.
        Column {
            id: stats

            width: parent.width - tank.width - parent.spacing
            height: tank.height

            // Spacing = the height left after the readouts, split between the
            // gaps. Derived from the count, so the charge line appearing on one
            // machine and not another needs nothing changed here.
            readonly property int gaps: Math.max(1, readoutRows.count - 1)
            spacing: Math.max(Appearance.padding.normal, (height - root.leadHeight - root.lineHeight * gaps) / gaps)

            Repeater {
                id: readoutRows

                model: root.readouts()

                // One readout. Value on the left, label right-aligned beside
                // it, which costs no height and gives two columns you can scan
                // separately. The lead one ignores that and stacks instead.
                delegate: Item {
                    id: readout

                    required property var modelData

                    width: stats.width
                    height: readout.modelData.lead ? root.leadHeight : root.lineHeight

                    // The value.
                    StyledText {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        // Gives way to the label beside it, never the reverse.
                        width: readout.modelData.lead ? parent.width : parent.width - note.width - Appearance.padding.normal

                        text: readout.modelData.value
                        font.pixelSize: readout.modelData.lead ? Appearance.font.size.normal : Appearance.font.size.small
                        color: readout.modelData.lead && Battery.low ? Appearance.colour.alarm : Appearance.colour.text
                        elide: Text.ElideRight
                    }

                    // The label. Right edge for the small ones, under the value
                    // for the lead one.
                    StyledText {
                        id: note

                        anchors.left: readout.modelData.lead ? parent.left : undefined
                        anchors.right: readout.modelData.lead ? undefined : parent.right
                        anchors.bottom: parent.bottom

                        // Capped at 40% so a long label cannot squeeze its own
                        // value down to an ellipsis.
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

    // ---- THE CELL ITSELF ---------------------------------------------------
    //
    // Hidden outright when there is no design figure to measure against, rather
    // than drawn empty: a meter with nothing behind it is worse than no meter.
    // services/Battery.qml has the note on why this comes from sysfs and not
    // from UPower's own health property.

    Separator {
        width: parent.width
        visible: health.visible
    }

    Column {
        id: health

        width: parent.width
        visible: Battery.available && Battery.health > 0
        spacing: Appearance.padding.small

        // Quieter than the tank on purpose. The tank is the accent because it is
        // what the menu is for; a second accent bar under it would make the page
        // argue with itself about which number to read first. The track is the
        // DARKEST fill rather than the tank's well, because the gap at the right
        // end IS the reading here, and at 96% that gap is four percent of the
        // width: too little to find unless the two materials are far apart.
        Gauge {
            width: parent.width
            value: Battery.health / 100
            fill: Appearance.colour.textDim
            track: Appearance.colour.fill

            // Where health stood on the log's first day. Hidden until there are
            // two readings, because one reading is not a history: see the
            // `tracking` note in services/Battery.qml.
            mark: Battery.tracking && Battery.firstSample.design > 0 ? Battery.firstSample.cap / Battery.firstSample.design : -1
        }

        // THREE SHORT LINES RATHER THAN TWO CROWDED ONES. The obvious layout put
        // the cycle count on the same line as the trend, and at this width "89
        // cycles" left the trend 243px for a sentence that wants 250: it elided
        // to "watching since 10 ..." on the first machine it ran on. The lines
        // below each hold one thing and none of them has to be measured against
        // another to know it fits.
        Item {
            width: parent.width
            height: root.lineHeight

            StyledText {
                anchors.left: parent.left
                text: `${Math.round(Battery.health)}% health`
            }

            StyledText {
                anchors.right: parent.right
                // Blank rather than "0 cycles" on a cell that does not count
                // them, which is most desktops-with-a-UPS and some laptops.
                text: Battery.cycles > 0 ? `${Battery.cycles} cycles` : ""
                color: Appearance.colour.textFaint
            }
        }

        // The two numbers behind the percentage above: what it charges to now,
        // and what it charged to new.
        StyledText {
            width: parent.width
            text: `${Battery.capacity.toFixed(1)} of ${Battery.designCapacity.toFixed(1)} Wh`
            color: Appearance.colour.textDim
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.trend()
            color: Appearance.colour.textFaint
            elide: Text.ElideRight
        }
    }

    // ---- NO BATTERY --------------------------------------------------------

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
