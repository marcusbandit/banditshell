function shelve(shelf, records) {
    const kept = shelf.map(r => r.entry);
    const fresh = [];
    for (const record of records || [])
        if (record && record.entry && !kept.includes(record.entry) && !fresh.some(r => r.entry === record.entry))
            fresh.push(record);
    return shelf.concat(fresh);
}

function restored(list, entries) {
    const out = list.slice();
    const back = entries.filter(e => !out.includes(e)).sort((a, b) => b.time - a.time);
    for (const entry of back) {
        const at = out.findIndex(e => e.time < entry.time);
        out.splice(at < 0 ? out.length : at, 0, entry);
    }
    return out;
}

function placed(list, items) {
    const out = list.slice();
    for (const item of items.slice().reverse())
        if (!out.includes(item.entry))
            out.splice(Math.min(Math.max(0, item.at), out.length), 0, item.entry);
    return out;
}

function homes(records) {
    const history = [];
    const popups = [];
    const gone = [];
    for (const r of records) {
        const popup = r.popup >= 0 && r.live;
        if (r.listed)
            history.push(r.entry);
        if (popup)
            popups.push({ entry: r.entry, at: r.popup });
        if (!r.listed && !popup)
            gone.push(r.entry);
    }
    return { history: history, popups: popups, gone: gone };
}

function hushedPopups(popups, keys, entry, key, kind) {
    const out = [];
    popups.forEach((e, at) => {
        if (kind === "snooze" ? e === entry : kind === "mute" && keys[at] === key)
            out.push({ entry: e, at: at });
    });
    return out;
}
