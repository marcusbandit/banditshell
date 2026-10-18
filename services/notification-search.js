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

function byApp(entries) {
    const ordered = (entries ?? []).map((entry, index) => ({ entry, index })).sort((a, b) => (b.entry.time ?? 0) - (a.entry.time ?? 0) || a.index - b.index);
    const open = new Map();
    const out = [];
    for (const { entry } of ordered) {
        const key = appOf(entry) || `\u0002${String(entry?.summary ?? "")}`;
        const group = open.get(key);
        if (group) {
            group.entries.push(entry);
            continue;
        }
        const fresh = { key, entries: [entry] };
        open.set(key, fresh);
        out.push(fresh);
    }
    return out;
}

const HEADS = ["notifications", "notification", "notifs", "notif"];
const QUALIFIERS = ["unread", "held"];

function ask(text) {
    const typed = String(text ?? "").trim();
    const parts = typed.toLowerCase().split(/\s+/).filter(w => w);
    const out = { explicit: false, unread: false, held: false, app: "", term: "", text: typed };
    if (parts.length === 0)
        return out;
    let from = 0;
    if (HEADS.includes(parts[0])) {
        out.explicit = true;
        from = 1;
    } else if (QUALIFIERS.includes(parts[0])) {
        out.explicit = true;
    } else {
        out.term = parts.join(" ");
        return out;
    }
    const free = [];
    for (let i = from; i < parts.length; i++) {
        const word = parts[i];
        if (word === "unread") {
            out.unread = true;
        } else if (word === "held") {
            out.held = true;
        } else if (word === "from" && i + 1 < parts.length && !out.app) {
            out.app = parts[++i];
        } else {
            free.push(word);
        }
    }
    out.term = free.join(" ");
    return out;
}

function appMatches(entry, token) {
    const want = String(token ?? "").toLowerCase();
    if (!want)
        return true;
    return String(entry?.appName ?? "").toLowerCase().includes(want) || appOf(entry).toLowerCase().includes(want);
}

function haystack(entry) {
    return `${entry?.appName ?? ""} ${entry?.summary ?? ""} ${entry?.body ?? ""}`.toLowerCase();
}

function matches(entry, asked) {
    if (!entry || entry.leaving)
        return false;
    if (asked.unread && entry.seen)
        return false;
    if (asked.held && !entry.withheld)
        return false;
    if (asked.app && !appMatches(entry, asked.app))
        return false;
    const hay = haystack(entry);
    return String(asked.term ?? "").split(" ").every(word => !word || hay.includes(word));
}

function find(entries, asked) {
    const kept = (entries ?? []).filter(entry => matches(entry, asked));
    if (!asked.term)
        return threads(kept);
    return kept.map((entry, index) => ({ entry, index })).sort((a, b) => (b.entry.time ?? 0) - (a.entry.time ?? 0) || a.index - b.index).map(({ entry }) => ({ id: `${entry.id}`, key: threadKey(entry), app: appOf(entry), entries: [entry], newest: entry }));
}

function apps(entries, limit) {
    const seen = new Set();
    const out = [];
    for (const entry of (entries ?? []).slice().sort((a, b) => (b.time ?? 0) - (a.time ?? 0))) {
        const name = String(entry?.appName ?? "").trim().toLowerCase();
        if (!name || name.includes(" ") || seen.has(name))
            continue;
        seen.add(name);
        out.push(name);
        if (out.length >= limit)
            break;
    }
    return out;
}

function line(entry, count, now) {
    const parts = [String(entry?.appName ?? "")];
    if (count > 1)
        parts.push(String(count));
    const when = age(entry?.time, now);
    if (when)
        parts.push(when);
    return parts.filter(p => p).join(" \u00b7 ");
}
