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
