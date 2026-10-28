const WEEKDAYS = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];

const STYLES = ["slashes", "dotted", "iso", "words"];

const LEGACY_STYLES = {
    "14/10/2026": "slashes",
    "14. okt. 2026": "dotted",
    "2026-10-14": "iso",
    "wed 14 oct": "words"
};

const SHAPES = ["headline", "brief", "year", "day", "month"];

function styleOf(value) {
    if (STYLES.indexOf(value) >= 0)
        return value;
    return LEGACY_STYLES[value] || "words";
}

function pad(n) {
    return n < 10 ? `0${n}` : `${n}`;
}

function twelveHour(hour) {
    return hour % 12 || 12;
}

function hourPart(date, clock24) {
    return pad(clock24 ? date.getHours() : twelveHour(date.getHours()));
}

function minutePart(date) {
    return pad(date.getMinutes());
}

function clockText(hour, minute, clock24, second) {
    const tail = second === undefined ? "" : `:${pad(second)}`;
    if (clock24)
        return `${pad(hour)}:${pad(minute)}${tail}`;
    return `${twelveHour(hour)}:${pad(minute)}${tail} ${hour < 12 ? "am" : "pm"}`;
}

function timeText(date, clock24, withSeconds) {
    return clockText(date.getHours(), date.getMinutes(), clock24, withSeconds ? date.getSeconds() : undefined);
}

function abbreviation(name) {
    return name.slice(0, 3);
}

function dateText(date, style, shape) {
    const weekday = WEEKDAYS[date.getDay()];
    const month = MONTHS[date.getMonth()];
    const day = date.getDate();
    const year = date.getFullYear();
    const numbers = `${pad(day)}/${pad(date.getMonth() + 1)}`;
    const iso = `${year}-${pad(date.getMonth() + 1)}-${pad(day)}`;
    switch (styleOf(style)) {
    case "slashes":
        return ({
            headline: `${weekday} ${numbers}`,
            brief: `${abbreviation(weekday)} ${numbers}`,
            year: `${numbers}/${year}`,
            day: numbers,
            month: `${pad(date.getMonth() + 1)}/${year}`
        })[shape];
    case "dotted":
        return ({
            headline: `${weekday} ${day}. ${month}`,
            brief: `${abbreviation(weekday)} ${day}. ${abbreviation(month)}.`,
            year: `${day}. ${abbreviation(month)}. ${year}`,
            day: `${day}. ${abbreviation(month)}.`,
            month: `${abbreviation(month)}. ${year}`
        })[shape];
    case "iso":
        return ({
            headline: `${weekday} ${iso}`,
            brief: `${abbreviation(weekday)} ${iso}`,
            year: iso,
            day: `${pad(date.getMonth() + 1)}-${pad(day)}`,
            month: `${year}-${pad(date.getMonth() + 1)}`
        })[shape];
    }
    return ({
        headline: `${weekday} ${day} ${month}`,
        brief: `${abbreviation(weekday)} ${day} ${abbreviation(month)}`,
        year: `${day} ${abbreviation(month)} ${year}`,
        day: `${day} ${abbreviation(month)}`,
        month: `${month} ${year}`
    })[shape];
}

function stampText(date, style, clock24) {
    return `${dateText(date, style, "year")}  ${timeText(date, clock24, false)}`;
}

function recentText(date, now, style, clock24) {
    if (date.toDateString() === now.toDateString())
        return timeText(date, clock24, false);
    if (date.getFullYear() === now.getFullYear())
        return dateText(date, style, "day");
    return dateText(date, style, "month");
}

function changedText(date, now, style) {
    if (date.toDateString() === now.toDateString())
        return "Today";
    return dateText(date, style, date.getFullYear() === now.getFullYear() ? "day" : "year");
}

function exampleText(style, date) {
    return dateText(date, style, "year").toLowerCase();
}
