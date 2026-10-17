const MINUTE = 60 * 1000;
const HOUR = 60 * MINUTE;
const DAY = 24 * HOUR;
const THREAD_WINDOW = 10 * MINUTE;

const WEEKDAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
const MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];

function pad(n) {
    return String(n).padStart(2, "0");
}

function clock(date) {
    return `${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function dayStart(at) {
    const d = new Date(at);
    return new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
}

function age(time, now) {
    if (!(time > 0) || !(now > time))
        return "";
    const diff = now - time;
    if (diff < MINUTE)
        return "";
    if (diff < HOUR)
        return `${Math.floor(diff / MINUTE)}m`;
    const days = Math.round((dayStart(now) - dayStart(time)) / DAY);
    if (days <= 0 || diff < HOUR * 12)
        return `${Math.floor(diff / HOUR)}h`;
    const date = new Date(time);
    if (days === 1)
        return `yesterday ${clock(date)}`;
    if (days < 7)
        return `${WEEKDAYS[date.getDay()]} ${clock(date)}`;
    const dated = `${date.getDate()} ${MONTHS[date.getMonth()]}`;
    return date.getFullYear() === new Date(now).getFullYear() ? dated : `${dated} ${date.getFullYear()}`;
}

function appOf(entry) {
    return String(entry?.appId || entry?.desktopEntry || String(entry?.appName ?? "").toLowerCase());
}

function threadKey(entry) {
    const said = String(entry?.summary ?? "").trim().toLowerCase();
    return `${appOf(entry)}\u0001${said || `\u0002${entry?.category ?? ""}`}`;
}

function threads(entries) {
    const ordered = (entries ?? []).map((entry, index) => ({ entry, index })).sort((a, b) => (b.entry.time ?? 0) - (a.entry.time ?? 0) || a.index - b.index);
    const open = new Map();
    const out = [];
    for (const { entry } of ordered) {
        const key = threadKey(entry);
        const thread = open.get(key);
        if (thread && thread.oldest - (entry.time ?? 0) <= THREAD_WINDOW) {
            thread.entries.push(entry);
            thread.oldest = entry.time ?? 0;
            continue;
        }
        const fresh = { key, app: appOf(entry), entries: [entry], newest: entry, oldest: entry.time ?? 0 };
        open.set(key, fresh);
        out.push(fresh);
    }
    return out.map(t => ({ id: `${t.key}\u0003${t.oldest}`, key: t.key, app: t.app, entries: t.entries, newest: t.newest }));
}
