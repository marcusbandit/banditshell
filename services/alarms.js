function weekdayOf(moment) {
    return (moment.getDay() + 6) % 7;
}

function occurrence(from, offset, hour, minute) {
    return new Date(from.getFullYear(), from.getMonth(), from.getDate() + offset, hour, minute, 0, 0).getTime();
}

function nextClockTime(hour, minute, at) {
    const from = new Date(at);
    const today = occurrence(from, 0, hour, minute);
    return today > at ? today : occurrence(from, 1, hour, minute);
}

function nextFor(alarm, at) {
    if (!alarm || !alarm.armed)
        return 0;
    if (alarm.snoozedUntil > at)
        return alarm.snoozedUntil;
    if (alarm.days.length === 0)
        return alarm.at > at ? alarm.at : 0;
    const from = new Date(at);
    for (let i = 0; i <= 7; i++) {
        const when = occurrence(from, i, alarm.hour, alarm.minute);
        if (when > at && alarm.days.includes(weekdayOf(new Date(when))))
            return when;
    }
    return 0;
}

function lastFor(alarm, at) {
    if (alarm.days.length === 0)
        return alarm.at <= at ? alarm.at : 0;
    const from = new Date(at);
    for (let i = 0; i <= 7; i++) {
        const when = occurrence(from, -i, alarm.hour, alarm.minute);
        if (when <= at && alarm.days.includes(weekdayOf(new Date(when))))
            return when;
    }
    return 0;
}

function pendingFor(alarm, at) {
    if (!alarm.armed)
        return 0;

    if (alarm.snoozedUntil > 0) {
        if (alarm.snoozedUntil > at)
            return 0;
        return alarm.snoozedUntil > alarm.handledUntil ? alarm.snoozedUntil : 0;
    }
    const due = lastFor(alarm, at);
    return due > alarm.handledUntil && due <= at ? due : 0;
}
