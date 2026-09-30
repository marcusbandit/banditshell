pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    spacing: Appearance.padding.normal

    readonly property int lineHeight: Math.round(Appearance.font.size.small * 4 / 3)
    readonly property int leadHeight: Math.round(Appearance.font.size.normal * 4 / 3) + lineHeight

    function readouts(): var {
        if (!Battery.available)
            return [];

        const rows = [
            {

                lead: true,
                value: Battery.state,
                note: Battery.timeLabel() || "fully charged"
            }
        ];

        if (Battery.capacity > 0)
            rows.push({
                lead: false,
                value: `${Battery.energy.toFixed(1)} Wh`,
                note: `of ${Battery.capacity.toFixed(1)}`
            });

        rows.push({
            lead: false,
            value: Battery.rate > 0 ? `${Battery.rate.toFixed(1)} W` : "idle",

            note: Battery.charging && !Battery.full ? "input" : "draw"
        });

        return rows;
    }

    readonly property var months: ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]

    function since(key: string): string {
        const parts = key.split("-");
        if (parts.length < 3)
            return key;
        return `${Number(parts[2])} ${root.months[Number(parts[1]) - 1] ?? ""}`;
    }

    function trend(): string {
        if (!Battery.firstSample)
            return "starting to watch";
        if (!Battery.tracking)
            return `watching since ${root.since(Battery.firstSample.d)}`;

        const lost = Battery.lostWh;
        const sign = lost >= 0 ? "-" : "+";
        return `${sign}${Math.abs(lost).toFixed(1)} Wh since ${root.since(Battery.firstSample.d)}`;
    }

    Row {
        width: parent.width
        visible: Battery.available
        spacing: Appearance.padding.large

        BatteryTank {
            id: tank

            level: Battery.percentage
            charging: Battery.charging

            liquid: Battery.low ? Appearance.colour.alarm : Appearance.colour.accent
        }

        Column {
            id: stats

            width: parent.width - tank.width - parent.spacing
            height: tank.height

            readonly property int gaps: Math.max(1, readoutRows.count - 1)
            spacing: Math.max(Appearance.padding.normal, (height - root.leadHeight - root.lineHeight * gaps) / gaps)

            Repeater {
                id: readoutRows

                model: root.readouts()

                delegate: Item {
                    id: readout

                    required property var modelData

                    width: stats.width
                    height: readout.modelData.lead ? root.leadHeight : root.lineHeight

                    StyledText {
                        anchors.left: parent.left
                        anchors.top: parent.top

                        width: readout.modelData.lead ? parent.width : parent.width - note.width - Appearance.padding.normal

                        text: readout.modelData.value
                        font.pixelSize: readout.modelData.lead ? Appearance.font.size.normal : Appearance.font.size.small
                        color: readout.modelData.lead && Battery.low ? Appearance.colour.alarm : Appearance.colour.text
                        elide: Text.ElideRight
                    }

                    StyledText {
                        id: note

                        anchors.left: readout.modelData.lead ? parent.left : undefined
                        anchors.right: readout.modelData.lead ? undefined : parent.right
                        anchors.bottom: parent.bottom

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

    Separator {
        width: parent.width
        visible: health.visible
    }

    Column {
        id: health

        width: parent.width
        visible: Battery.available && Battery.health > 0
        spacing: Appearance.padding.small

        Gauge {
            width: parent.width
            value: Battery.health / 100
            fill: Appearance.colour.textDim
            track: Appearance.colour.fill

            mark: Battery.tracking && Battery.firstSample.design > 0 ? Battery.firstSample.cap / Battery.firstSample.design : -1
        }

        Item {
            width: parent.width
            height: root.lineHeight

            StyledText {
                anchors.left: parent.left
                text: `${Math.round(Battery.health)}% health`
            }

            StyledText {
                anchors.right: parent.right

                text: Battery.cycles > 0 ? `${Battery.cycles} cycles` : ""
                color: Appearance.colour.textFaint
            }
        }

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
}
