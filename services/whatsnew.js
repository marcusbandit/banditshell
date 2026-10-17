const TYPES = ["issues", "bugs", "features", "ui", "config"];

const IMPACT_KEYS = ["restart", "cli", "binds", "deps"];

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

function names(list) {
    return Array.isArray(list) ? list.filter(s => typeof s === "string" && s.trim()).map(s => s.trim()) : [];
}

function impact(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    return {
        restart: raw.restart === true,
        cli: raw.cli === true,
        binds: names(raw.binds),
        deps: names(raw.deps)
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
        impact: impact(raw.impact),
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

function newestId(entries) {
    for (const e of Array.isArray(entries) ? entries : [])
        if (e && !e.example && typeof e.id === "string" && e.id.trim())
            return e.id.trim();
    return "";
}

function tagFor(id) {
    const hit = /^(\d{4})-(\d{2})-(\d{2})(-\d+)?$/.exec(String(id ?? "").trim());
    return hit ? `v${hit[1]}.${hit[2]}.${hit[3]}${hit[4] ?? ""}` : "";
}
