.pragma library

const TIMER_PRESETS = [5, 15, 25, 30];

const COMMON_ZONES = [
    "America/New_York",
    "America/Los_Angeles",
    "America/Chicago",
    "Europe/London",
    "Europe/Paris",
    "Europe/Berlin",
    "Asia/Dubai",
    "Asia/Kolkata",
    "Asia/Singapore",
    "Asia/Hong_Kong",
    "Asia/Tokyo",
    "Australia/Sydney",
    "America/Sao_Paulo",
    "Pacific/Auckland"
];

function presetText(minutes) {
    return `${minutes}m`;
}

function squash(text) {
    return String(text === undefined || text === null ? "" : text).toLowerCase().replace(/[_\s]+/g, " ").trim();
}

function cityOf(id) {
    return id.slice(id.lastIndexOf("/") + 1).replace(/_/g, " ");
}

function zoneRank(id, query) {
    const city = squash(cityOf(id));
    if (city === query)
        return 0;
    if (city.startsWith(query))
        return 1;
    if (city.split(" ").some(word => word.startsWith(query)))
        return 2;
    if (city.includes(query))
        return 3;
    if (squash(id.replace(/\//g, " ")).includes(query))
        return 4;
    return -1;
}

function matchZones(all, taken, query, max) {
    const free = all.filter(id => !taken.includes(id));
    const q = squash(query);
    if (q === "") {
        const common = COMMON_ZONES.filter(id => free.includes(id));
        return common.slice(0, max);
    }
    const ranked = [];
    for (const id of free) {
        const rank = zoneRank(id, q);
        if (rank >= 0)
            ranked.push({
                id,
                rank,
                city: cityOf(id)
            });
    }
    ranked.sort((a, b) => a.rank - b.rank || a.city.localeCompare(b.city) || (a.id < b.id ? -1 : 1));
    return ranked.slice(0, max).map(row => row.id);
}

function missingZoneText(query, taken) {
    const here = matchZones(taken, [], query, 1);
    if (here.length > 0)
        return `${cityOf(here[0])} is already on the list`;
    return `no city called ${String(query).trim().replace(/\s+/g, " ")}`;
}

function fullNote(kind, max) {
    return max === 1 ? `1 ${kind} is the most, remove it` : `${max} ${kind}s is the most, remove one`;
}

function timersFull(timers, max) {
    return timers.filter(t => !t.finished).length >= max;
}

function runningTimers(timers) {
    return timers.filter(t => !t.finished && !t.paused);
}

function hour12(hour) {
    return hour % 12 || 12;
}

function hour24(hour, pm) {
    return hour % 12 + (pm ? 12 : 0);
}

function typedNumber(text, from, to) {
    const digits = String(text === undefined || text === null ? "" : text).replace(/\D/g, "");
    if (digits === "")
        return -1;
    return Math.max(from, Math.min(to, parseInt(digits, 10)));
}

function reinsert(list, item, index) {
    const at = Math.max(0, Math.min(list.length, index));
    const next = list.slice();
    next.splice(at, 0, item);
    return next;
}
