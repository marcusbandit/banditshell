.pragma library

var EXPLICIT = /^(?:clip|clips|clipboard)(?:\s+([\s\S]*))?$/i;
var SPACES = /\s+/g;
var LINES = /\r?\n/;
var DEPTH = 1000;
var IMAGE_KINDS = ["image", "audio", "video"];

function ask(text) {
    var typed = String(text || "").trim();
    var said = EXPLICIT.exec(typed);
    return said ? {
        term: (said[1] || "").trim(),
        explicit: true
    } : {
        term: typed,
        explicit: false
    };
}

function haystack(text) {
    return " " + String(text || "").slice(0, DEPTH).replace(SPACES, " ").toLowerCase();
}

function index(entries, summarise) {
    var out = [];
    for (var i = 0; i < (entries || []).length; i++) {
        var entry = entries[i];
        out.push({
            entry: entry,
            order: i,
            textual: IMAGE_KINDS.indexOf(entry.kind) < 0 && !entry.file,
            hay: haystack(summarise(entry))
        });
    }
    return out;
}

function find(indexed, term, explicit, limit) {
    var want = String(term || "").trim().replace(SPACES, " ").toLowerCase();
    if (!want)
        return explicit ? indexed.slice(0, limit).map(function (item) {
            return item.entry;
        }) : [];
    if (!explicit && want.length < 3)
        return [];
    var hits = [];
    for (var i = 0; i < indexed.length; i++) {
        var item = indexed[i];
        if (!explicit && !item.textual)
            continue;
        var at = item.hay.indexOf(" " + want);
        var tier = at === 0 ? 3 : at > 0 ? 2 : explicit && item.hay.indexOf(want) >= 0 ? 1 : 0;
        if (tier > 0)
            hits.push({
                item: item,
                tier: tier
            });
    }
    hits.sort(function (a, b) {
        return b.tier - a.tier || a.item.order - b.item.order;
    });
    return hits.slice(0, limit).map(function (hit) {
        return hit.item.entry;
    });
}

function firstLine(text, length) {
    var lines = String(text || "").slice(0, DEPTH * 2).split(LINES);
    var most = length || 160;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(SPACES, " ").trim();
        if (line)
            return line.length > most ? line.slice(0, most - 1).trim() + "…" : line;
    }
    return "";
}
