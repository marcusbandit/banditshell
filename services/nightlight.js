const DAY_MS = 86400000;
const MINUTE_MS = 60000;
const J2000 = 2451545.0;
const UNIX_EPOCH_JULIAN = 2440587.5;
const HORIZON_ANGLE = -0.833;
const OBLIQUITY = 23.4397;

function radians(degrees) {
    return degrees * Math.PI / 180;
}

function degrees(rad) {
    return rad * 180 / Math.PI;
}

function julianOf(ms) {
    return ms / DAY_MS + UNIX_EPOCH_JULIAN;
}

function millisecondsOf(julian) {
    return (julian - UNIX_EPOCH_JULIAN) * DAY_MS;
}

function solarDay(dayNumber, lat, lon) {
    const meanDay = dayNumber + 0.0009 - lon / 360;
    const anomaly = (357.5291 + 0.98560028 * meanDay) % 360;
    const centre = 1.9148 * Math.sin(radians(anomaly)) + 0.02 * Math.sin(radians(2 * anomaly)) + 0.0003 * Math.sin(radians(3 * anomaly));
    const eclipticLongitude = (anomaly + centre + 180 + 102.9372) % 360;
    const transit = J2000 + meanDay + 0.0053 * Math.sin(radians(anomaly)) - 0.0069 * Math.sin(radians(2 * eclipticLongitude));
    const declination = Math.asin(Math.sin(radians(eclipticLongitude)) * Math.sin(radians(OBLIQUITY)));
    const cosine = (Math.sin(radians(HORIZON_ANGLE)) - Math.sin(radians(lat)) * Math.sin(declination)) / (Math.cos(radians(lat)) * Math.cos(declination));
    if (cosine > 1)
        return { polar: "night", transit };
    if (cosine < -1)
        return { polar: "day", transit };
    const halfDay = degrees(Math.acos(cosine)) / 360;
    return { rise: millisecondsOf(transit - halfDay), set: millisecondsOf(transit + halfDay), transit };
}

function sunEvents(nowMs, lat, lon) {
    const first = Math.round(julianOf(nowMs) - J2000) - 3;
    const events = [];
    let polar = "";
    for (let n = first; n <= first + 6; n++) {
        const day = solarDay(n, lat, lon);
        if (day.polar)
            polar = day.polar;
        else
            events.push({ at: day.rise, kind: "rise" }, { at: day.set, kind: "set" });
    }
    events.sort((a, b) => a.at - b.at);
    return { events, polar };
}

function sunWindow(nowMs, place) {
    if (!place)
        return null;
    const { events, polar } = sunEvents(nowMs, place.lat, place.lon);
    if (events.length === 0)
        return polar === "night" ? { start: -Infinity, end: Infinity } : null;
    let last = null;
    for (const e of events)
        if (e.at <= nowMs)
            last = e;
    const after = events.filter(e => e.at > nowMs);
    const riseAfter = from => {
        const hit = events.find(e => e.kind === "rise" && e.at > from);
        return hit ? hit.at : Infinity;
    };
    if (last && last.kind === "set")
        return { start: last.at, end: riseAfter(last.at) };
    const next = after.find(e => e.kind === "set");
    if (!next)
        return polar === "night" ? { start: nowMs, end: Infinity } : null;
    return { start: next.at, end: riseAfter(next.at) };
}

function minutesOf(text) {
    const m = String(text || "").match(/^(\d{1,2}):(\d{2})$/);
    if (!m)
        return -1;
    const hour = Number(m[1]);
    const minute = Number(m[2]);
    return hour < 24 && minute < 60 ? hour * 60 + minute : -1;
}

function clockOf(minutes) {
    const hour = Math.floor(minutes / 60);
    const minute = minutes % 60;
    return `${hour < 10 ? "0" : ""}${hour}:${minute < 10 ? "0" : ""}${minute}`;
}

function localMoment(nowMs, dayOffset, minutes) {
    const base = new Date(nowMs);
    return new Date(base.getFullYear(), base.getMonth(), base.getDate() + dayOffset, Math.floor(minutes / 60), minutes % 60, 0, 0).getTime();
}

function timesWindow(nowMs, from, to) {
    const start = minutesOf(from);
    const end = minutesOf(to);
    if (start < 0 || end < 0 || start === end)
        return null;
    for (let offset = -1; offset <= 1; offset++) {
        const closing = localMoment(nowMs, end > start ? offset : offset + 1, end);
        if (closing > nowMs)
            return { start: localMoment(nowMs, offset, start), end: closing };
    }
    return null;
}

function windowFor(mode, nowMs, settings) {
    if (mode === "sunset")
        return sunWindow(nowMs, settings.place);
    if (mode === "times") {
        return timesWindow(nowMs, settings.from, settings.to);
    }
    return null;
}

function smooth(t) {
    const k = Math.max(0, Math.min(1, t));
    return k * k * (3 - 2 * k);
}

function fractionAt(nowMs, window, easeMs) {
    if (!window || nowMs < window.start || nowMs >= window.end)
        return 0;
    const ease = Math.max(1, easeMs);
    return smooth(Math.min((nowMs - window.start) / ease, (window.end - nowMs) / ease));
}

function nextEdge(nowMs, window) {
    if (!window)
        return 0;
    if (nowMs < window.start)
        return window.start;
    return window.end > nowMs ? window.end : 0;
}

function warmKelvin(fraction, neutral, target) {
    return Math.round(neutral + fraction * (target - neutral));
}

function scheduled(mode, settings) {
    if (mode === "sunset")
        return !!settings.place;
    if (mode === "times") {
        const from = minutesOf(settings.from);
        const to = minutesOf(settings.to);
        return from >= 0 && to >= 0 && from !== to;
    }
    return false;
}

function nightAt(mode, nowMs, settings) {
    if (!scheduled(mode, settings))
        return { known: false, night: true, next: 0 };
    const window = windowFor(mode, nowMs, settings);
    return {
        known: true,
        night: !!window && nowMs >= window.start && nowMs < window.end,
        next: nextEdge(nowMs, window)
    };
}
