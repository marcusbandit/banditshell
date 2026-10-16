.pragma library

var TONES = [
    {
        id: "none",
        name: "Default",
        modifier: ""
    },
    {
        id: "light",
        name: "Light",
        modifier: String.fromCodePoint(0x1F3FB)
    },
    {
        id: "medium-light",
        name: "Medium light",
        modifier: String.fromCodePoint(0x1F3FC)
    },
    {
        id: "medium",
        name: "Medium",
        modifier: String.fromCodePoint(0x1F3FD)
    },
    {
        id: "medium-dark",
        name: "Medium dark",
        modifier: String.fromCodePoint(0x1F3FE)
    },
    {
        id: "dark",
        name: "Dark",
        modifier: String.fromCodePoint(0x1F3FF)
    }
];

var POPULAR = ["😂", "❤️", "🤣", "👍", "😭", "🙏", "😘", "🥰", "😍", "😊", "🎉", "😁", "💕", "🥺", "😅", "🔥", "☺️", "🤦", "🤷", "🙄", "😆", "🤗", "😉", "🎂", "🤔", "👏", "🙂", "😳", "🥳", "😎", "👌", "💜", "😔", "💪", "✨", "💖", "👀", "😋", "😏", "😢", "👉", "💗", "😩", "💯", "🌹", "💞", "🎈", "💙", "😃", "😡", "💐", "😜", "🙈", "🤞", "😄", "🤤", "🙌", "🤪", "😀", "💋", "💀", "👇", "💔", "😌", "💓", "🤩", "🙃", "😬", "😱", "😴", "🤭", "😐", "😒", "😇", "🌸", "😈", "🎶", "✌️", "🎊", "🥵", "😞", "💚", "🖤", "💰", "😚", "👑", "🎁", "💥", "🙋", "😑", "🥴", "👈", "💩", "✅", "👋", "🤝", "😮", "→", "°", "™", "€"];

var PRESENTATION = "️";

var EXPLICIT = /^(?:emoji|emojis|emoticons?|symbols?|characters?)(?:\s+([\s\S]*))?$/i;
var COLON = /^:(?:([a-z0-9][a-z0-9_+-][\s\S]*))?$/i;
var JOINED = /([a-z0-9])-(?=[a-z0-9])/g;
var LOOSE = /[:,;!?()"]+/g;
var QUOTES = /['’]/g;
var SPACES = /\s+/g;
var SYMBOLIC = /[^a-z0-9\s]/;

function fold(text) {
    return String(text || "").toLowerCase().replace(QUOTES, "").replace(JOINED, "$1 ").replace(LOOSE, " ").replace(SPACES, " ").trim();
}

function foldWord(text) {
    return String(text || "").toLowerCase().replace(QUOTES, "").replace(JOINED, "$1 ").trim();
}

function parse(table, groups, firstSymbol) {
    var out = [];
    for (var i = 0; i < table.length; i++) {
        var fields = table[i].split("|");
        var group = +fields[3];
        var words = fields[2] ? fields[2].split(",") : [];
        var keys = words.map(foldWord);
        var title = fold(fields[1]);
        out.push({
            char: fields[0],
            name: fields[1],
            words: words,
            group: groups[group] || "",
            symbol: group >= firstSymbol,
            places: fields[4] ? fields[4].split(".").map(Number) : [],
            index: i,
            title: title,
            keys: keys,
            spaced: " " + title,
            framed: " " + title + " ",
            keyline: "," + keys.join(",") + ",",
            popular: POPULAR.indexOf(fields[0]) >= 0,
            hay: " " + title + " " + keys.join(" ")
        });
    }
    return out;
}

function index(entries) {
    var out = {};
    for (var i = 0; i < entries.length; i++)
        out[entries[i].char] = entries[i];
    return out;
}

function ask(text) {
    var typed = String(text || "").trim();
    var said = EXPLICIT.exec(typed);
    if (said)
        return {
            term: (said[1] || "").trim(),
            explicit: true
        };
    var colon = COLON.exec(typed);
    if (colon)
        return {
            term: (colon[1] || "").trim(),
            explicit: true
        };
    return {
        term: typed,
        explicit: false
    };
}

function tier(entry, want, exact, parts, least) {
    var keyed = entry.keyline.indexOf("," + exact + ",") >= 0 || !!want && want !== exact && entry.keyline.indexOf("," + want + ",") >= 0;
    if (!want || entry.hay.indexOf(want) < 0) {
        if (want && entry.keyline.indexOf(",:" + want + ",") >= 0)
            return 9.5;
        if (keyed)
            return 8;
        if (least > 3 || parts.length < 2)
            return 0;
        for (var j = 0; j < parts.length; j++)
            if (entry.hay.indexOf(" " + parts[j]) < 0)
                return 0;
        return 3;
    }
    if (entry.title === want)
        return 10;
    if (entry.keyline.indexOf(",:" + want + ",") >= 0)
        return 9.5;
    if (entry.framed.indexOf(" " + want + " ") >= 0)
        return 9;
    if (keyed)
        return 8;
    if (entry.title.indexOf(want) === 0)
        return 7;
    if (entry.spaced.indexOf(" " + want) >= 0)
        return 6;
    if (entry.keyline.indexOf("," + want) >= 0 || entry.keyline.indexOf(",:" + want) >= 0)
        return 5;
    if (entry.hay.indexOf(" " + want) >= 0)
        return 4;
    return 2;
}

function bonus(entry, want, found, used) {
    var record = used && used[entry.char];
    var recent = record ? 3 + Math.min(1, (record.count || 0) / 20) : 0;
    var leading = found <= 8 && want && entry.title.indexOf(want) === 0 ? 0.5 : 0;
    return recent + leading + (entry.popular ? 1.5 : 0);
}

function lowest(exact, explicit) {
    if (explicit)
        return 2;
    if (SYMBOLIC.test(exact))
        return exact.length >= 2 ? 8 : 99;
    return exact.length >= 3 ? 6 : 99;
}

function recentFirst(entries, byChar, used, limit) {
    var chars = Object.keys(used || {}).sort(function (a, b) {
        return (used[b].last || 0) - (used[a].last || 0);
    });
    var out = [];
    var seen = {};
    var pool = chars.concat(POPULAR);
    for (var i = 0; i < pool.length && out.length < limit; i++) {
        var entry = byChar[pool[i]];
        if (entry && !seen[entry.char]) {
            seen[entry.char] = true;
            out.push(entry);
        }
    }
    for (var j = 0; j < entries.length && out.length < limit; j++)
        if (!seen[entries[j].char])
            out.push(entries[j]);
    return out;
}

function search(entries, byChar, query, used, explicit, limit) {
    var exact = foldWord(query);
    var want = fold(query);
    if (!exact)
        return explicit ? recentFirst(entries, byChar, used, limit) : [];
    var least = lowest(exact, explicit);
    if (least > 10)
        return [];
    var parts = want.split(" ");
    var hits = [];
    for (var i = 0; i < entries.length; i++) {
        var found = tier(entries[i], want, exact, parts, least);
        if (found >= least)
            hits.push({
                entry: entries[i],
                score: found + bonus(entries[i], want, found, used)
            });
    }
    hits.sort(function (a, b) {
        return b.score - a.score || a.entry.title.length - b.entry.title.length || a.entry.index - b.entry.index;
    });
    return hits.slice(0, limit).map(function (hit) {
        return hit.entry;
    });
}

function modifierFor(tone) {
    for (var i = 0; i < TONES.length; i++)
        if (TONES[i].id === tone)
            return TONES[i].modifier;
    return "";
}

function codePoints(text) {
    var out = [];
    for (var i = 0; i < text.length;) {
        var code = text.codePointAt(i);
        out.push(String.fromCodePoint(code));
        i += code > 0xFFFF ? 2 : 1;
    }
    return out;
}

function toned(entry, modifier) {
    if (!modifier || !entry || !entry.places.length)
        return entry ? entry.char : "";
    var points = codePoints(entry.char);
    var out = "";
    for (var i = 0; i < points.length; i++) {
        if (points[i] === PRESENTATION && entry.places.indexOf(i - 1) >= 0)
            continue;
        out += points[i];
        if (entry.places.indexOf(i) >= 0)
            out += modifier;
    }
    return out;
}

function remember(used, char, now) {
    var out = {};
    var keys = Object.keys(used || {});
    for (var i = 0; i < keys.length; i++)
        out[keys[i]] = used[keys[i]];
    var had = out[char];
    out[char] = {
        count: (had ? had.count || 0 : 0) + 1,
        last: now
    };
    var kept = Object.keys(out).sort(function (a, b) {
        return out[b].last - out[a].last;
    }).slice(0, 60);
    var trimmed = {};
    for (var j = 0; j < kept.length; j++)
        trimmed[kept[j]] = out[kept[j]];
    return trimmed;
}

function codeOf(char) {
    return codePoints(char).filter(function (point) {
        return point !== PRESENTATION;
    }).map(function (point) {
        var hex = point.codePointAt(0).toString(16).toUpperCase();
        return "U+" + ("0000" + hex).slice(-Math.max(4, hex.length));
    }).join(" ");
}
