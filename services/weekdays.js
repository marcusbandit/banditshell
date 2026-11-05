.pragma library

var CHOICES = ["locale", "monday", "sunday", "saturday"];

var STARTS = { monday: 1, sunday: 0, saturday: 6 };

function firstDay(setting, localeFirst) {
    if (Object.prototype.hasOwnProperty.call(STARTS, setting))
        return STARTS[setting];
    var n = Math.floor(Number(localeFirst));
    return n >= 0 && n <= 6 ? n : 1;
}

function order(first) {
    var out = [];
    for (var i = 0; i < 7; i++)
        out.push((first + i) % 7);
    return out;
}

function lead(date, first) {
    return (date.getDay() - first + 7) % 7;
}

function mondayBased(day) {
    return (day + 6) % 7;
}

function qtDay(day) {
    return day === 0 ? 7 : day;
}

function weekNumber(rowStart) {
    var thursday = new Date(rowStart.getFullYear(), rowStart.getMonth(), rowStart.getDate() + (4 - rowStart.getDay() + 7) % 7);
    var january = new Date(thursday.getFullYear(), 0, 1);
    var dayOfYear = Math.round((thursday.getTime() - january.getTime()) / 86400000) + 1;
    return Math.floor((dayOfYear - 1) / 7) + 1;
}
