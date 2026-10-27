const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const LIMIT = 30 * DAY;

const UNITS = {
    m: MINUTE,
    min: MINUTE,
    mins: MINUTE,
    minute: MINUTE,
    minutes: MINUTE,
    h: HOUR,
    hr: HOUR,
    hrs: HOUR,
    hour: HOUR,
    hours: HOUR,
    d: DAY,
    day: DAY,
    days: DAY,
    w: 7 * DAY,
    week: 7 * DAY,
    weeks: 7 * DAY
};

const FOREVER = ["", "always", "never", "forever", "off", "permanent", "permanently"];

function span(text) {
    const said = String(text ?? "").trim().toLowerCase().replace(/^for\s+/, "").replace(/^(an?|the)\s+/, "");
    const bare = /^([a-z]+)$/.exec(said);
    if (bare && UNITS[bare[1]])
        return UNITS[bare[1]];
    const counted = /^(\d+(?:\.\d+)?)\s*([a-z]+)$/.exec(said);
    if (!counted || !UNITS[counted[2]])
        return -1;
    const ms = Math.round(Number(counted[1]) * UNITS[counted[2]]);
    return ms > 0 && ms <= LIMIT ? ms : -1;
}

function muteLength(text) {
    const said = String(text ?? "").trim().toLowerCase();
    if (FOREVER.includes(said))
        return 0;
    return span(said);
}

function snoozeLength(text) {
    const said = String(text ?? "").trim().toLowerCase();
    if (!said)
        return 10 * MINUTE;
    return span(said);
}

function muted(rule, now) {
    return typeof rule?.muteUntil === "number" && rule.muteUntil > now;
}

function mutedLine(until, now) {
    if (!(until > now))
        return "";
    const left = until - now;
    if (left < HOUR)
        return `${Math.max(1, Math.round(left / MINUTE))}m`;
    if (left < DAY)
        return `${Math.round(left / HOUR)}h`;
    return `${Math.round(left / DAY)}d`;
}

function due(items, now) {
    const ready = [];
    const waiting = [];
    for (const item of items ?? [])
        (item && item.at <= now ? ready : waiting).push(item);
    return { ready, waiting };
}

function snoozeAdd(items, entry, at) {
    return (items ?? []).filter(item => item && item.entry !== entry).concat([{ entry, at }]);
}

function hushAllowed(kind, ms, key) {
    if (kind === "snooze")
        return ms > 0;
    if (kind === "mute")
        return !!key && ms >= 0;
    return kind === "unmute" && !!key;
}

function popupTimeout(asked, critical, fallback) {
    if (critical || asked === 0)
        return 0;
    return asked > 0 ? asked : fallback;
}

function wakeTimeout(timeout, critical, live, fallback) {
    if (timeout > 0 || critical || live)
        return timeout;
    return fallback;
}
