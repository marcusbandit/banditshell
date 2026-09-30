const TYPES = ["issues", "bugs", "features", "ui", "config"];

function change(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    if (typeof raw.text !== "string" || !raw.text.trim())
        return null;
    return {
        type: typeof raw.type === "string" ? raw.type : "",
        severity: raw.severity === "major" ? "major" : "minor",
        text: raw.text.trim()
    };
}

function entry(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    if (typeof raw.id !== "string" || !raw.id.trim())
        return null;
    return {
        id: raw.id.trim(),
        date: typeof raw.date === "string" ? raw.date.trim() : "",
        example: raw.example === true,
        changes: Array.isArray(raw.changes) ? raw.changes.map(change).filter(c => c) : []
    };
}

function parse(text) {
    let doc;
    try {
        doc = JSON.parse(String(text ?? ""));
    } catch (e) {
        return [];
    }
    const list = Array.isArray(doc) ? doc : Array.isArray(doc?.entries) ? doc.entries : null;
    if (!list)
        return [];
    return list.map(entry).filter(e => e);
}

function accumulated(entries, seen) {
    const mark = String(seen ?? "");
    const out = [];
    for (const e of entries) {
        if (e.example || !e.changes.length)
            continue;
        if (mark && e.id === mark)
            break;
        out.push(e);
    }
    return out;
}

function severityOf(e) {
    return e && e.changes.some(c => c.severity === "major") ? "major" : "minor";
}
