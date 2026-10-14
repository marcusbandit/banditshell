.pragma library

const KEEP_DAYS = 14;

function pad(n) {
    return n < 10 ? `0${n}` : `${n}`;
}

function dayKey(date) {
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
}

function credit(days, key, appClass, ms) {
    if (!appClass || !(ms > 0))
        return days;
    const next = Object.assign({}, days);
    const day = Object.assign({}, next[key] ?? {});
    day[appClass] = (day[appClass] ?? 0) + ms;
    next[key] = day;
    return next;
}

function prune(days, today, keep) {
    const kept = keep ?? KEEP_DAYS;
    const oldest = dayKey(new Date(today.getFullYear(), today.getMonth(), today.getDate() - (kept - 1)));
    const next = {};
    for (const key of Object.keys(days))
        if (key >= oldest)
            next[key] = days[key];
    return next;
}

function top(days, key, count) {
    const day = days[key] ?? {};
    const ranked = Object.keys(day).map(appClass => ({
                appClass,
                ms: day[appClass],
                minutes: Math.round(day[appClass] / 60000)
            })).filter(entry => entry.ms > 0).sort((a, b) => b.ms - a.ms || (a.appClass < b.appClass ? -1 : 1));
    return count === undefined ? ranked : ranked.slice(0, count);
}

function total(days, key) {
    return Object.values(days[key] ?? {}).reduce((sum, ms) => sum + ms, 0);
}

function sanitise(data) {
    const clean = {};
    if (!data || typeof data !== "object" || Array.isArray(data))
        return clean;
    for (const key of Object.keys(data)) {
        if (!/^\d{4}-\d{2}-\d{2}$/.test(key) || !data[key] || typeof data[key] !== "object")
            continue;
        const day = {};
        for (const appClass of Object.keys(data[key]))
            if (typeof data[key][appClass] === "number" && isFinite(data[key][appClass]) && data[key][appClass] > 0)
                day[appClass] = data[key][appClass];
        if (Object.keys(day).length)
            clean[key] = day;
    }
    return clean;
}

function merge(mine, theirs) {
    const next = Object.assign({}, mine);
    for (const key of Object.keys(theirs)) {
        const day = Object.assign({}, next[key] ?? {});
        for (const appClass of Object.keys(theirs[key]))
            day[appClass] = Math.max(day[appClass] ?? 0, theirs[key][appClass]);
        next[key] = day;
    }
    return next;
}

function same(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
}
