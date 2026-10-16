.pragma library

var EXPLICIT = /^(?:snippets?|snip)(?:\s+([\s\S]*))?$/i;
var PLACEHOLDERS = /\{(date|time|clipboard|cursor)\}/gi;
var SPACES = /\s+/g;
var AMBIENT = 0.35;
var AMBIENT_STEP = 0.035;

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

function place(haystack, needle) {
    var hay = String(haystack || "").toLowerCase();
    var want = String(needle || "").toLowerCase();
    if (!want || !hay)
        return 0;
    if (hay === want)
        return 4;
    if (hay.indexOf(want) === 0)
        return 3;
    if ((" " + hay).indexOf(" " + want) >= 0)
        return 2;
    return hay.indexOf(want) >= 0 ? 1 : 0;
}

function find(list, term, explicit) {
    var want = String(term || "").trim().toLowerCase();
    var out = [];
    for (var i = 0; i < (list || []).length; i++) {
        var item = list[i];
        if (!item)
            continue;
        if (!want) {
            if (explicit)
                out.push({
                    snippet: item,
                    score: 0,
                    keyed: false
                });
            continue;
        }
        var keyed = !!item.keyword && item.keyword.toLowerCase() === want;
        var named = place(item.name, want);
        var worded = place(item.keyword, want);
        var inside = explicit && place(item.text, want) > 0 ? 1 : 0;
        var best = Math.max(named, worded - 0.5, inside);
        if (keyed || best >= (explicit ? 1 : 2))
            out.push({
                snippet: item,
                score: keyed ? Infinity : explicit ? best : AMBIENT + best * AMBIENT_STEP,
                keyed: keyed
            });
    }
    return out.sort(function (a, b) {
        return b.score - a.score || String(a.snippet.name).localeCompare(String(b.snippet.name));
    });
}

function expand(text, values) {
    var marker = -1;
    var out = "";
    var last = 0;
    var source = String(text || "");
    PLACEHOLDERS.lastIndex = 0;
    var m;
    while ((m = PLACEHOLDERS.exec(source)) !== null) {
        out += source.slice(last, m.index);
        var name = m[1].toLowerCase();
        if (name === "cursor") {
            if (marker < 0)
                marker = out.length;
        } else {
            out += String(values && values[name] !== undefined ? values[name] : "");
        }
        last = m.index + m[0].length;
    }
    out += source.slice(last);
    return {
        text: out,
        back: marker < 0 ? 0 : countPoints(out.slice(marker))
    };
}

function previewText(text, values, length) {
    var shown = {};
    var keys = Object.keys(values || {});
    for (var i = 0; i < keys.length; i++)
        shown[keys[i]] = values[keys[i]];
    shown.clipboard = "{clipboard}";
    return preview(expand(text, shown).text, length);
}

function countPoints(text) {
    var count = 0;
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (code < 0xDC00 || code > 0xDFFF)
            count++;
    }
    return count;
}

function preview(text, length) {
    var flat = String(text || "").replace(SPACES, " ").trim();
    var most = length || 80;
    return flat.length > most ? flat.slice(0, most - 1).trim() + "…" : flat;
}

function suggestName(text) {
    var words = String(text || "").replace(SPACES, " ").trim().split(" ");
    var out = "";
    for (var i = 0; i < words.length; i++) {
        var next = out ? out + " " + words[i] : words[i];
        if (next.length > 24 && out)
            break;
        out = next;
    }
    return out.slice(0, 32);
}

function newId(list, now) {
    var taken = {};
    for (var i = 0; i < (list || []).length; i++)
        if (list[i] && list[i].id)
            taken[list[i].id] = true;
    var base = "s" + Number(now || 0).toString(36);
    var id = base;
    for (var n = 2; taken[id]; n++)
        id = base + "-" + n;
    return id;
}

function cleanKeyword(text) {
    return String(text || "").trim().replace(SPACES, "");
}

function withSnippet(list, item) {
    var out = [];
    var placed = false;
    for (var i = 0; i < (list || []).length; i++) {
        if (list[i] && list[i].id === item.id) {
            out.push(item);
            placed = true;
        } else {
            out.push(list[i]);
        }
    }
    if (!placed)
        out.push(item);
    return out;
}

function withoutSnippet(list, id) {
    return (list || []).filter(function (item) {
        return item && item.id !== id;
    });
}

function keywordHolder(list, keyword, id) {
    var want = cleanKeyword(keyword).toLowerCase();
    if (!want)
        return null;
    for (var i = 0; i < (list || []).length; i++)
        if (list[i] && list[i].id !== id && String(list[i].keyword || "").toLowerCase() === want)
            return list[i];
    return null;
}
