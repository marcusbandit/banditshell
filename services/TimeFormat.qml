pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "timeformat.js" as Formatting

Singleton {
    id: root

    readonly property bool clock24: Config.values.region.clock24
    readonly property string dateStyle: Formatting.styleOf(Config.values.region.dateFormat)

    readonly property var styles: Formatting.STYLES

    function styleOf(value: string): string {
        return Formatting.styleOf(value);
    }

    function time(moment: date, withSeconds: bool): string {
        return Formatting.timeText(moment, root.clock24, withSeconds);
    }

    function clock(hour: int, minute: int): string {
        return Formatting.clockText(hour, minute, root.clock24);
    }

    function hourPart(moment: date): string {
        return Formatting.hourPart(moment, root.clock24);
    }

    function minutePart(moment: date): string {
        return Formatting.minutePart(moment);
    }

    function dateText(moment: date, shape: string): string {
        return Formatting.dateText(moment, root.dateStyle, shape);
    }

    function stamp(moment: date): string {
        return Formatting.stampText(moment, root.dateStyle, root.clock24);
    }

    function recent(moment: date): string {
        return Formatting.recentText(moment, new Date(), root.dateStyle, root.clock24);
    }

    function example(style: string, moment: date): string {
        return Formatting.exampleText(style, moment);
    }
}
