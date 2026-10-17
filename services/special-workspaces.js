.pragma library

var ASK = /^(?:scratch\s+pads?|scratchpads?|scratch|special\s+workspaces?|specials?)(?:\s+(.*))?$/i;
var DEFAULT_NAME = "special";

function ask(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? { words: String(m[1] || "").trim().toLowerCase() } : null;
}

function listed(specials) {
    if (specials && specials.length)
        return specials.map(function (s) {
            return { name: s.label, windows: s.windows ? s.windows.length : 0, fallback: false };
        });
    return [{ name: DEFAULT_NAME, windows: 0, fallback: true }];
}

function matching(list, words, place, limit) {
    var want = String(words || "").trim().toLowerCase();
    var scored = [];
    for (var i = 0; i < list.length; i++) {
        var s = want ? place(list[i].name, want) : 1;
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

function windowsText(count) {
    return count === 0 ? "empty" : count === 1 ? "1 window" : count + " windows";
}

function labelOf(entry) {
    return entry.fallback ? "Scratchpad" : entry.name;
}

function detailOf(entry, shown) {
    return "special workspace · " + (shown ? "open · " : "") + windowsText(entry.windows);
}
