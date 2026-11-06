pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "timeformat.js" as Formatting
import "weekdays.js" as Weekdays

Singleton {
    id: root

    readonly property bool clock24: Config.values.region.clock24
    readonly property string dateStyle: Formatting.styleOf(Config.values.region.dateFormat)

    readonly property var styles: Formatting.STYLES
    readonly property int firstDay: Weekdays.firstDay(Config.values.region.firstDay, Qt.locale().firstDayOfWeek)
    readonly property bool weekNumbers: Config.values.region.weekNumbers
    readonly property var weekOrder: Weekdays.order(root.firstDay)

    function weekdayLead(moment: date): int {
        return Weekdays.lead(moment, root.firstDay);
    }

    function weekdayInitial(day: int): string {
        return Qt.locale().dayName(Weekdays.qtDay(day), Locale.NarrowFormat).toUpperCase();
    }

    function weekNumber(rowStart: date): int {
        return Weekdays.weekNumber(rowStart);
    }

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

    function changed(moment: date): string {
        return Formatting.changedText(moment, new Date(), root.dateStyle);
    }

    function example(style: string, moment: date): string {
        return Formatting.exampleText(style, moment);
    }
}
