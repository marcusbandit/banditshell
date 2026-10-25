const ENDS_HOUR = "in an hour";
const ENDS_EVENING = "at 18:00";
const ENDS_TOMORROW = "tomorrow";
const ENDS_NEVER = "off by hand";

const EVENING_MINUTES = 18 * 60;
const HOUR_MS = 60 * 60 * 1000;

function minutesOf(text) {
    const m = /^(\d{1,2}):(\d{2})$/.exec(String(text ?? "").trim());
    if (!m)
        return -1;
    const hour = Number(m[1]);
    const minute = Number(m[2]);
    return hour > 23 || minute > 59 ? -1 : hour * 60 + minute;
}

function minuteOfDay(at) {
    const d = new Date(at);
    return d.getHours() * 60 + d.getMinutes();
}

function occurrence(at, offsetDays, minutes) {
    const d = new Date(at);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate() + offsetDays, Math.floor(minutes / 60), minutes % 60, 0, 0).getTime();
}

function nextOccurrence(at, minutes) {
    const today = occurrence(at, 0, minutes);
    return today > at ? today : occurrence(at, 1, minutes);
}

function nightlyActive(at, from, to) {
    const start = minutesOf(from);
    const end = minutesOf(to);
    if (start < 0 || end < 0 || start === end)
        return false;
    const now = minuteOfDay(at);
    return start < end ? now >= start && now < end : now >= start || now < end;
}

function holding(state, at) {
    if (state.quiet && (!(state.until > 0) || at < state.until))
        return true;
    return !!state.nightly && nightlyActive(at, state.from, state.to);
}

function deadlineFor(choice, at, wake) {
    if (choice === ENDS_HOUR)
        return at + HOUR_MS;
    if (choice === ENDS_EVENING)
        return nextOccurrence(at, EVENING_MINUTES);
    if (choice === ENDS_TOMORROW) {
        const minutes = minutesOf(wake);
        return nextOccurrence(at, minutes < 0 ? 0 : minutes);
    }
    return 0;
}

function hushLength(choice, at, wake) {
    if (choice === "always")
        return 0;
    const ends = parseEnds(choice);
    return ends === ENDS_HOUR || ends === ENDS_TOMORROW ? deadlineFor(ends, at, wake) - at : -1;
}

function endsLabel(until, at, wake) {
    if (!(until > at))
        return ENDS_NEVER;
    const d = new Date(until);
    const exact = d.getSeconds() === 0 && d.getMilliseconds() === 0;
    const minutes = minuteOfDay(until);
    if (exact && minutes === EVENING_MINUTES)
        return ENDS_EVENING;
    if (exact && minutes === minutesOf(wake))
        return ENDS_TOMORROW;
    return ENDS_HOUR;
}

function clockTime(at) {
    const d = new Date(at);
    return `${String(d.getHours()).padStart(2, "0")}:${String(d.getMinutes()).padStart(2, "0")}`;
}

function parseEnds(text) {
    const want = String(text ?? "").trim().toLowerCase().replace(/\s+/g, " ");
    const words = new Map([
        ["hour", ENDS_HOUR],
        ["evening", ENDS_EVENING],
        ["tomorrow", ENDS_TOMORROW],
        ["never", ENDS_NEVER],
        ["", ENDS_NEVER],
        [ENDS_HOUR, ENDS_HOUR],
        [ENDS_EVENING, ENDS_EVENING],
        [ENDS_TOMORROW, ENDS_TOMORROW],
        [ENDS_NEVER, ENDS_NEVER]
    ]);
    return words.get(want) ?? "";
}

function quietLine(state, at) {
    if (state.quiet && (!(state.until > 0) || at < state.until))
        return state.until > 0 ? `Quiet until ${clockTime(state.until)}` : "Quiet until you turn it off";
    if (state.nightly && nightlyActive(at, state.from, state.to))
        return `Quiet until ${state.to}`;
    return "";
}
