.pragma library

var SECTIONS = ["Files and clipboard", "Ask and look up", "Desktop", "System", "Text and numbers", "Plugins", "Quicklinks"];

var OWN = [
    { section: "Files and clipboard", word: "~", example: "~/Downloads", about: "Browse your folders", icon: "folder_open", also: ["/"] },
    { section: "Ask and look up", word: ":", example: ":fire", about: "Emoji by name", icon: "mood", also: [] },
    { section: "Text and numbers", word: "=", example: "=2^10 + 3", about: "Calculate", icon: "calculate", also: [] }
];

var SYMBOLS = /^[^a-z0-9]$/i;

function asked(text) {
    return text === "?";
}

function heads(p) {
    return [p.word].concat(p.also || []);
}

function claims(text, prefixes) {
    var lower = String(text || "").trim().toLowerCase();
    return lower.indexOf("?") === 0 || (prefixes || []).some(p => heads(p).indexOf(lower) >= 0);
}

function guess(text, labels, closest, prefixes) {
    return claims(text, prefixes) ? -1 : closest(text, labels);
}

function completion(p) {
    return SYMBOLS.test(p.word) ? (p.word === "~" ? "~/" : p.word) : `${p.word} `;
}

function detail(p) {
    return p.example ? `${p.about}, as in ${p.example}` : p.about;
}

function order(a, b) {
    return SYMBOLS.test(b.word) - SYMBOLS.test(a.word) || a.word.localeCompare(b.word);
}

function sections(prefixes) {
    var linked = {};
    (prefixes || []).filter(p => p && p.section === "Quicklinks").forEach(p => heads(p).forEach(h => linked[h] = true));
    var taken = {};
    var unique = (prefixes || []).filter(p => {
        var key = p && p.word && (p.section === "Quicklinks" || !linked[p.word]) ? `${p.section}\n${p.word}` : "";
        var fresh = key && !taken[key];
        if (fresh)
            taken[key] = true;
        return fresh;
    });
    return SECTIONS.map(title => ({
        title: title,
        prefixes: unique.filter(p => p.section === title).sort(order)
    })).filter(section => section.prefixes.length);
}
