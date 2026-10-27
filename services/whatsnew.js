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

const ID = /^(\d{4})-(\d{2})-(\d{2})(-\d+)?$/;

function idOrder(id) {
    const hit = ID.exec(String(id ?? "").trim());
    return hit ? { day: `${hit[1]}-${hit[2]}-${hit[3]}`, push: hit[4] ? Number(hit[4].slice(1)) : 1 } : null;
}

function laterThan(a, b) {
    const x = idOrder(a);
    const y = idOrder(b);
    if (x === null || y === null)
        return false;
    return x.day !== y.day ? x.day > y.day : x.push > y.push;
}

function accumulated(entries, seen) {
    const mark = String(seen ?? "");
    if (mark && laterThan(mark, newestId(entries)))
        return [];
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

function readSeen(text) {
    return String(text ?? "").split("\n")[0].trim();
}

function lastSeen(stored, legacy) {
    const own = readSeen(stored);
    return own !== "" ? own : readSeen(legacy);
}

function legacyToMove(stored, legacy) {
    return readSeen(stored) === "" ? readSeen(legacy) : "";
}

function newestId(entries) {
    for (const e of Array.isArray(entries) ? entries : [])
        if (e && !e.example && typeof e.id === "string" && e.id.trim())
            return e.id.trim();
    return "";
}

const RELEASE = /^v(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/;

function releaseParts(tag) {
    const hit = RELEASE.exec(String(tag ?? "").trim());
    return hit ? [Number(hit[1]), Number(hit[2]), Number(hit[3])] : null;
}

function newerRelease(a, b) {
    const x = releaseParts(a);
    const y = releaseParts(b);
    if (x === null)
        return false;
    if (y === null)
        return true;
    for (let i = 0; i < 3; i++)
        if (x[i] !== y[i])
            return x[i] > y[i];
    return false;
}

function newestRelease(tags) {
    let best = "";
    for (const tag of Array.isArray(tags) ? tags : [])
        if (newerRelease(tag, best))
            best = String(tag).trim();
    return best;
}

function bumpOf(subjects) {
    let bump = "";
    for (const subject of Array.isArray(subjects) ? subjects : []) {
        const line = String(subject ?? "").trim();
        if (!line)
            continue;
        const hit = /^([a-z]+)(\([^)]*\))?(!)?:/.exec(line);
        if (hit && hit[3])
            return "breaking";
        if (hit && hit[1] === "feat")
            bump = "minor";
        else if (bump === "")
            bump = "patch";
    }
    return bump;
}

function nextRelease(last, subjects) {
    const bump = bumpOf(subjects);
    if (bump === "")
        return null;
    const parts = releaseParts(last);
    if (parts === null)
        return { tag: "v0.1.0", bump: "first" };
    const [major, minor, patch] = parts;
    if (bump === "breaking" && major > 0)
        return { tag: `v${major + 1}.0.0`, bump: "major" };
    if (bump === "patch")
        return { tag: `v${major}.${minor}.${patch + 1}`, bump };
    return { tag: `v${major}.${minor + 1}.0`, bump: "minor" };
}

function entriesSince(beforeText, afterText) {
    const known = new Set(parse(beforeText).map(e => e.id));
    return parse(afterText).filter(e => !e.example && e.changes.length > 0 && !known.has(e.id));
}

function releaseNotes(entries, first) {
    const parts = sections(entries).map(s => [`## ${s.title}`, "", ...s.changes.map(c => `- ${c.text}`)].join("\n"));
    if (parts.length === 0)
        parts.push(first ? "The first numbered release of banditshell." : "Small fixes and upkeep, nothing you will notice.");
    return parts.join("\n\n") + "\n";
}

const SECTIONS = [
    { key: "major", title: "Big changes", glyph: "new_releases", types: null },
    { key: "features", title: "New", glyph: "add_circle", types: ["features"] },
    { key: "ui", title: "Changed", glyph: "border_color", types: ["ui"] },
    { key: "bugs", title: "Fixed", glyph: "build", types: ["bugs", "issues"] },
    { key: "config", title: "Settings", glyph: "tune", types: ["config"] },
    { key: "other", title: "Other", glyph: "chevron_right", types: [] }
];

function sectionOf(c) {
    if (c.severity === "major")
        return "major";
    const hit = SECTIONS.find(s => s.types && s.types.includes(c.type));
    return hit ? hit.key : "other";
}

function sections(entries) {
    const buckets = {};
    for (const e of Array.isArray(entries) ? entries : [])
        for (const raw of Array.isArray(e?.changes) ? e.changes : []) {
            const c = change(raw);
            if (!c)
                continue;
            const key = sectionOf(c);
            if (!buckets[key])
                buckets[key] = [];
            buckets[key].push(c);
        }
    return SECTIONS.filter(s => buckets[s.key]).map(s => ({ key: s.key, title: s.title, glyph: s.glyph, changes: buckets[s.key] }));
}

function main(argv) {
    const fs = require("node:fs");
    const stdin = () => fs.readFileSync(0, "utf8").split("\n");
    const read = file => {
        try {
            return fs.readFileSync(file, "utf8");
        } catch (e) {
            return "";
        }
    };
    if (argv[0] === "newest") {
        process.stdout.write(newestRelease(stdin()) + "\n");
        return 0;
    }
    if (argv[0] === "next") {
        const next = nextRelease(argv[1] ?? "", stdin());
        if (next === null)
            return 1;
        process.stdout.write(`${next.tag} ${next.bump}\n`);
        return 0;
    }
    if (argv[0] === "notes") {
        const first = argv[3] === "--first";
        process.stdout.write(releaseNotes(first ? [] : entriesSince(read(argv[1]), read(argv[2])), first));
        return 0;
    }
    process.stderr.write("usage: node whatsnew.js newest | next <last-tag> | notes <before> <after> [--first]\n");
    return 2;
}

if (typeof require !== "undefined" && typeof module !== "undefined" && require.main === module)
    process.exit(main(process.argv.slice(2)));
