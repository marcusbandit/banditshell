.pragma library

var MODIFIERS = [
    { bit: 64, name: "Super" },
    { bit: 4, name: "Ctrl" },
    { bit: 8, name: "Alt" },
    { bit: 1, name: "Shift" },
    { bit: 2, name: "Caps" },
    { bit: 16, name: "Mod2" },
    { bit: 32, name: "Mod3" },
    { bit: 128, name: "Mod5" }
];

var MOUSE_BASE = 272;
var MOUSE_NAMES = ["left", "right", "middle", "side", "extra", "forward", "back", "task"];
var CHORDS_PER_BIND = 24;
var ASK = /^(?:keys|shortcuts?|keybinds?|keybindings?)(?:\s+(.*))?$/i;

function ask(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? { words: String(m[1] || "").trim().toLowerCase() } : null;
}

function keyLabel(key) {
    var k = String(key || "");
    if (k.indexOf("mouse:") === 0) {
        var named = MOUSE_NAMES[parseInt(k.slice(6), 10) - MOUSE_BASE];
        return named ? "Mouse " + named : k;
    }
    if (k.indexOf("XF86") === 0)
        return k.slice(4).replace(/([a-z0-9])([A-Z])/g, "$1 $2");
    return k.length === 1 ? k.toUpperCase() : k.charAt(0).toUpperCase() + k.slice(1);
}

function chordText(mask, key) {
    var parts = [];
    for (var i = 0; i < MODIFIERS.length; i++)
        if ((mask & MODIFIERS[i].bit) !== 0)
            parts.push(MODIFIERS[i].name);
    var label = keyLabel(key);
    if (label)
        parts.push(label);
    return parts.join(" + ");
}

function squeeze(text) {
    return String(text || "").replace(/\s+/g, " ").trim();
}

function entries(binds) {
    var out = [];
    var seen = {};
    for (var i = 0; i < (binds || []).length; i++) {
        var b = binds[i];
        var action = squeeze(b.action || b.description || b.expr);
        if (!action)
            continue;
        var presses = b.presses && b.presses.length ? b.presses : [{ mask: b.mask, key: b.key }];
        var kept = 0;
        for (var j = 0; j < presses.length && kept < CHORDS_PER_BIND; j++) {
            if (!presses[j] || !presses[j].key)
                continue;
            kept++;
            var chord = chordText(presses[j].mask || 0, presses[j].key);
            var submap = b.submap || "";
            var id = submap + "|" + chord + "|" + action;
            if (seen[id])
                continue;
            seen[id] = true;
            out.push({ id: id, chord: chord, action: action, submap: submap });
        }
    }
    return out;
}

function tokens(words) {
    return String(words || "").toLowerCase().replace(/\+/g, " ").split(/\s+/).filter(function (t) {
        return t.length > 0;
    });
}

function escapeRegex(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function tokenScore(entry, token) {
    var chordParts = entry.chord.toLowerCase().split(" + ");
    if (chordParts.indexOf(token) >= 0)
        return 3;
    if (new RegExp("\\b" + escapeRegex(token)).test(entry.action.toLowerCase()))
        return 2;
    return 0;
}

function matching(list, words, place, limit) {
    var want = tokens(words);
    var phrase = want.join(" ");
    var scored = [];
    for (var i = 0; i < list.length; i++) {
        var total = 0;
        var hit = true;
        for (var t = 0; t < want.length && hit; t++) {
            var s = tokenScore(list[i], want[t]);
            if (s === 0)
                hit = false;
            total += s;
        }
        if (!hit)
            continue;
        scored.push({ entry: list[i], score: total + (phrase ? Math.max(place(list[i].action, phrase), 0) : 0), at: i });
    }
    scored.sort(function (a, b) {
        return b.score - a.score || a.at - b.at;
    });
    return scored.slice(0, limit).map(function (s) {
        return s.entry;
    });
}
