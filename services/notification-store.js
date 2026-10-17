const VERSION = 1;
const PER_THREAD = 3;
const PICTURE_NAME = /^[A-Za-z0-9._-]+\.png$/;

function isBorrowed(url) {
    return String(url ?? "").startsWith("image://") && !String(url).startsWith("image://icon/");
}

function isTemporary(url) {
    return /^(file:\/\/)?\/(tmp|var\/tmp|run)\//.test(String(url ?? ""));
}

function number(value, fallback) {
    return typeof value === "number" && isFinite(value) ? value : fallback;
}

function text(value) {
    return typeof value === "string" ? value : "";
}

function basename(path) {
    const cut = String(path ?? "").lastIndexOf("/");
    return cut < 0 ? String(path ?? "") : String(path).slice(cut + 1);
}

function serialise(entries, pictureLimit) {
    const kept = [];
    let pictures = 0;
    for (const e of entries ?? []) {
        if (!e || !e.durable || (e.leaving && e.forget))
            continue;
        const name = e.cached ? basename(e.cached) : "";
        const withPicture = PICTURE_NAME.test(name) && pictures < pictureLimit;
        if (withPicture)
            pictures++;
        kept.push({
            id: text(e.id),
            time: number(e.time, 0),
            appName: text(e.appName),
            summary: text(e.summary),
            body: text(e.body),
            appIcon: text(e.appIcon),
            desktopEntry: text(e.desktopEntry),
            category: text(e.category),
            urgency: number(e.urgency, 1),
            progress: number(e.progress, -1),
            image: isBorrowed(e.image) || isTemporary(e.image) ? "" : text(e.image),
            picture: withPicture ? name : "",
            pinned: !!e.pinned,
            seen: !!e.seen
        });
    }
    return { version: VERSION, entries: kept };
}

function pictureNames(saved) {
    return (saved?.entries ?? []).map(e => e.picture).filter(n => n);
}

function restore(raw, limit, known, picturesDir) {
    let data = raw;
    if (typeof raw === "string") {
        try {
            data = JSON.parse(raw);
        } catch (err) {
            return [];
        }
    }
    const list = Array.isArray(data?.entries) ? data.entries : [];
    const seen = new Set(known ?? []);
    const out = [];
    for (const r of list) {
        if (!r || typeof r !== "object")
            continue;
        const time = number(r.time, 0);
        const id = text(r.id);
        if (time <= 0 || !id || seen.has(id))
            continue;
        seen.add(id);
        const urgency = number(r.urgency, 1);
        const progress = number(r.progress, -1);
        out.push({
            id,
            time,
            appName: text(r.appName),
            summary: text(r.summary),
            body: text(r.body),
            appIcon: text(r.appIcon),
            desktopEntry: text(r.desktopEntry),
            category: text(r.category),
            urgency: urgency === 0 || urgency === 2 ? urgency : 1,
            progress: progress >= 0 && progress <= 100 ? progress : -1,
            image: isBorrowed(r.image) || isTemporary(r.image) ? "" : text(r.image),
            cached: PICTURE_NAME.test(text(r.picture)) && picturesDir ? `${picturesDir}/${r.picture}` : "",
            pinned: !!r.pinned,
            seen: !!r.seen
        });
    }
    out.sort((a, b) => b.time - a.time);
    return out.slice(0, Math.max(0, limit));
}

function trim(threads, limit, perThread) {
    const quota = perThread > 0 ? perThread : PER_THREAD;
    const all = [];
    const surplus = [];
    let order = 0;
    for (const thread of threads ?? [])
        thread.entries.forEach((entry, place) => {
            const item = { entry, time: entry.time ?? 0, order: order++ };
            all.push(item);
            if (place >= quota)
                surplus.push(item);
        });
    const excess = all.length - Math.max(0, limit);
    if (excess <= 0)
        return [];
    const oldest = (a, b) => a.time - b.time || b.order - a.order;
    const chosen = surplus.sort(oldest).slice(0, excess);
    if (chosen.length < excess) {
        const taken = new Set(chosen);
        chosen.push(...all.filter(i => !taken.has(i)).sort(oldest).slice(0, excess - chosen.length));
    }
    return chosen.map(i => i.entry);
}
