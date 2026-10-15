.pragma library

var SYMBOL_KEYS = [
    { label: "+", insert: "+" },
    { label: "−", insert: "-" },
    { label: "×", insert: "*" },
    { label: "÷", insert: "/" },
    { label: "(", insert: "(" },
    { label: ")", insert: ")" },
    { label: "^", insert: "^", tip: "power" },
    { label: "%", insert: "%" },
    { label: "!", insert: "!", tip: "factorial" },
    { label: "√", insert: "sqrt(", tip: "square root" },
    { label: "π", insert: "pi" },
    { label: "e", insert: "e" },
    { label: "sin", insert: "sin(" },
    { label: "cos", insert: "cos(" },
    { label: "tan", insert: "tan(" },
    { label: "ln", insert: "ln(" },
    { label: "log", insert: "log10(" },
    { label: "∫", insert: "integrate(", tip: "integral: integrate(x^2, x) or integrate(x^2, 0, 1)" },
    { label: "d/dx", insert: "diff(", tip: "derivative: diff(x^2, x)" },
    { label: "Σ", insert: "sum(", tip: "sum: sum(x, x, 1, 10)" },
    { label: "x", insert: "x" },
    { label: "∞", insert: "infinity" }
];

var DOMAINS = ["com", "net", "org", "io", "dev", "app", "co", "me", "ai", "gg", "tv", "fm", "ly", "sh", "xyz", "info", "edu", "gov", "eu", "uk", "de", "no", "se", "dk", "fi", "nl", "fr", "es", "it", "pt", "pl", "ch", "at", "be", "us", "ca", "au", "jp", "br", "in", "ru", "page", "site", "blog", "wiki", "tech", "cloud", "social"];

function pathQuery(text, home) {
    const t = String(text || "");
    if (!(t === "~" || t.indexOf("~/") === 0 || t[0] === "/"))
        return null;
    const full = t === "~" ? `${home}/` : t[0] === "~" ? home + t.slice(1) : t;
    const cut = full.lastIndexOf("/");
    return {
        dir: full.slice(0, cut + 1),
        stem: full.slice(cut + 1)
    };
}

function shortPath(path, home) {
    const p = String(path || "");
    return home && (p === home || p.indexOf(`${home}/`) === 0) ? `~${p.slice(home.length)}` : p;
}

function pathRows(entries, query, hidden, home) {
    const stem = query.stem.toLowerCase();
    const shown = e => !e.hidden || stem[0] === "." || hidden === "all" || (hidden === ".config" && e.name === ".config" && query.dir === `${home}/`);
    const rank = name => name.toLowerCase().indexOf(stem) === 0 ? 2 : name.toLowerCase().indexOf(stem) > 0 ? 1 : 0;
    return (entries || []).filter(e => shown(e) && rank(e.name) > 0).sort((a, b) => rank(b.name) - rank(a.name) || (b.kind === "dir") - (a.kind === "dir") || a.name.toLowerCase().localeCompare(b.name.toLowerCase())).map(e => ({
                path: query.dir + e.name,
                name: e.name,
                dir: e.kind === "dir",
                fileClass: e.class || (e.kind === "dir" ? "directory" : "unknown")
            }));
}

function fileRows(lines, query, place) {
    return (lines || []).filter(l => !!l).map(line => {
        const dir = line[line.length - 1] === "/";
        const path = dir ? line.slice(0, -1) : line;
        const name = path.slice(path.lastIndexOf("/") + 1);
        return {
            path: path,
            name: name,
            dir: dir,
            fileClass: dir ? "directory" : "unknown",
            score: place(name, query),
            depth: path.split("/").length
        };
    }).filter(f => f.score > 0).sort((a, b) => b.score - a.score || a.depth - b.depth || a.name.length - b.name.length || a.path.localeCompare(b.path));
}

function urlOf(text) {
    const t = String(text || "").trim();
    if (!t || /\s/.test(t))
        return "";
    if (/^[a-z][a-z0-9+.\-]*:\/\/\S+$/i.test(t))
        return t;
    if (/^(localhost|(\d{1,3}\.){3}\d{1,3})(:\d+)?(\/\S*)?$/i.test(t))
        return `http://${t}`;
    const site = /^(www\.)?([a-z0-9\-]+\.)+([a-z]{2,})(:\d+)?(\/\S*)?$/i.exec(t);
    if (site && (site[1] || DOMAINS.indexOf(site[3].toLowerCase()) >= 0))
        return `https://${t}`;
    return "";
}

function webSearchUrl(template, text) {
    return String(template || "").replace("%s", encodeURIComponent(String(text || "").trim()));
}

function arrange(groups, caps) {
    const best = g => g.items.reduce((m, it) => Math.max(m, it.score ?? 0), -Infinity);
    const live = (groups || []).map((g, i) => ({
                g: g,
                i: i,
                best: best(g)
            })).filter(x => x.g.items.length > 0).sort((a, b) => b.best - a.best || a.i - b.i);
    const out = [];
    for (const x of live) {
        if (live.length > 1)
            out.push({
                header: true,
                key: `header:${x.g.key}`,
                title: x.g.title
            });
        const cap = caps?.[x.g.key];
        for (const it of cap === undefined ? x.g.items : x.g.items.slice(0, cap))
            out.push(it);
    }
    return out;
}

function nextPickable(rows, from, step) {
    const n = (rows || []).length;
    for (let i = 0; i < n; i++) {
        const at = ((from + i * step) % n + n) % n;
        if (!rows[at].header)
            return at;
    }
    return -1;
}
