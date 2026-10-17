.pragma library

var ASK = /^(?:tray icons?|tray items?|system tray|systray|tray)(?:\s+(.*))?$/i;
var AMBIENT_SCALE = 0.1;

function ask(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? { words: String(m[1] || "").trim().toLowerCase() } : null;
}

function best(entry, text, place) {
    return Math.max(place(entry.name, text), place(entry.id, text));
}

function matching(list, words, place, limit) {
    var want = String(words || "").trim().toLowerCase();
    if (!want)
        return list.slice(0, limit);
    var scored = [];
    for (var i = 0; i < list.length; i++) {
        var s = Math.max(best(list[i], want, place), place(list[i].detail, want) - 1);
        if (s > 0)
            scored.push({ entry: list[i], score: s, at: i });
    }
    scored.sort(function (a, b) {
        return b.score - a.score || a.at - b.at;
    });
    return scored.slice(0, limit).map(function (s) {
        return s.entry;
    });
}

function ambient(list, text, place, limit) {
    var want = String(text || "").trim().toLowerCase();
    if (want.length < 3 || /\s/.test(want))
        return [];
    var out = [];
    for (var i = 0; i < list.length && out.length < limit; i++) {
        var s = best(list[i], want, place);
        if (s >= 2)
            out.push({ entry: list[i], score: s * AMBIENT_SCALE });
    }
    return out;
}
