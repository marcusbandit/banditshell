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

var SPAN_HEAD = /^(\d+(?:[.,]\d+)?)\s*(hours?|hrs?|h|minutes?|mins?|m|seconds?|secs?|s)(?![a-z])\s*(?:and\s+)?/i;

function unitSeconds(unit) {
    const u = unit.toLowerCase();
    return u[0] === "h" ? 3600 : u[0] === "m" ? 60 : 1;
}

function leadingSpan(text, bareMinutes) {
    let rest = String(text || "").trim();
    let total = 0;
    let m;
    while ((m = SPAN_HEAD.exec(rest)) !== null) {
        total += parseFloat(m[1].replace(",", ".")) * unitSeconds(m[2]);
        rest = rest.slice(m[0].length);
    }
    if (!total && bareMinutes) {
        const bare = /^(\d+(?:[.,]\d+)?)(?![\d.,:a-z])\s*/i.exec(rest);
        if (bare) {
            total = parseFloat(bare[1].replace(",", ".")) * 60;
            rest = rest.slice(bare[0].length);
        }
    }
    return total > 0 ? {
        seconds: Math.round(total),
        rest: rest.trim()
    } : null;
}

function spanText(seconds) {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor(seconds % 3600 / 60);
    const s = seconds % 60;
    return [h ? `${h} h` : "", m ? `${m} min` : "", s ? `${s} s` : ""].filter(p => p).join(" ");
}

function timerAsk(text) {
    const t = String(text || "").trim();
    const led = /^timer\s+(?:for\s+)?(.*)$/i.exec(t);
    if (led) {
        const span = leadingSpan(led[1], true);
        return span ? {
            seconds: span.seconds,
            label: span.rest.replace(/^(?:for|called)\s+/i, "")
        } : null;
    }
    const span = leadingSpan(t, false);
    const tail = span && /^timer(?:\s+(?:for\s+)?(.*))?$/i.exec(span.rest);
    return tail ? {
        seconds: span.seconds,
        label: (tail[1] || "").trim()
    } : null;
}

function clockOf(text, loose) {
    const m = /^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm)?$/i.exec(String(text || "").trim());
    if (!m || !(m[2] || m[3] || loose))
        return null;
    let hour = parseInt(m[1], 10);
    const minute = m[2] ? parseInt(m[2], 10) : 0;
    const half = (m[3] || "").toLowerCase();
    if (minute > 59 || hour > (half ? 12 : 23) || (half && hour === 0))
        return null;
    if (half)
        hour = hour % 12 + (half === "pm" ? 12 : 0);
    return {
        hour: hour,
        minute: minute
    };
}

var CLOCK = "\\d{1,2}(?:[:.]\\d{2})?(?:\\s*(?:am|pm))?";

function reminderAsk(text) {
    const m = /^remind\s+me\s+(.+)$/i.exec(String(text || "").trim());
    if (!m)
        return null;
    const rest = m[1].trim();
    const what = s => (s || "").trim().replace(/^to\s+/i, "");

    const first = new RegExp(`^(at\\s+)?(${CLOCK})(?:\\s+(.*))?$`, "i").exec(rest);
    const early = first && clockOf(first[2], !!first[1]);
    if (early)
        return {
            at: early,
            label: what(first[3])
        };
    const last = new RegExp(`^(.+?)\\s+at\\s+(${CLOCK})$`, "i").exec(rest);
    const late = last && clockOf(last[2], true);
    if (late)
        return {
            at: late,
            label: what(last[1])
        };
    const lead = /^in\s+(.*)$/i.exec(rest);
    if (lead) {
        const span = leadingSpan(lead[1], false);
        return span ? {
            seconds: span.seconds,
            label: what(span.rest)
        } : null;
    }
    const after = /^(.+?)\s+in\s+(.+)$/i.exec(rest);
    const span = after && leadingSpan(after[2], false);
    return span && !span.rest ? {
        seconds: span.seconds,
        label: what(after[1])
    } : null;
}

function volumeAsk(text) {
    const m = /^(?:set\s+)?(?:the\s+)?(?:volume|vol|sound)\s+(?:to\s+)?(\d{1,3})\s*%?$/i.exec(String(text || "").trim());
    return m && parseInt(m[1], 10) <= 150 ? parseInt(m[1], 10) : -1;
}

function streamVolumeAsk(text) {
    const t = String(text || "").trim().toLowerCase().replace(/\s+/g, " ");
    const m = /^(?:set )?(?:volume|vol) (?:of |for )?(.+?) (?:to )?(\d{1,3}) ?%?$/.exec(t) || /^(?:set )?(.+?) (?:volume|vol) (?:to )?(\d{1,3}) ?%?$/.exec(t) || /^(.+?) (?:to )?(\d{1,3}) ?%$/.exec(t);
    if (!m || /^(?:the|to|sound|it|all)$/.test(m[1]) || m[1].length < 2 || parseInt(m[2], 10) > 150)
        return null;
    return {
        name: m[1],
        level: parseInt(m[2], 10)
    };
}

function mixerAsk(text) {
    return /^(?:volume|volumes|mixer|volume mixer|sound mixer|app volume|apps volume|app volumes)$/i.test(String(text || "").trim());
}

function awakeAsk(text) {
    const m = /^(?:keep )?awake(?: for)? (.+)$/i.exec(String(text || "").trim()) || /^(?:caffeinate|coffee)(?: for)? (.+)$/i.exec(String(text || "").trim());
    if (!m)
        return 0;
    const span = leadingSpan(m[1], true);
    return span && !span.rest ? span.seconds : 0;
}

var ZONE_ALIASES = {
    "nyc": "America/New_York",
    "washington": "America/New_York",
    "boston": "America/New_York",
    "miami": "America/New_York",
    "sf": "America/Los_Angeles",
    "san francisco": "America/Los_Angeles",
    "seattle": "America/Los_Angeles",
    "ldn": "Europe/London",
    "beijing": "Asia/Shanghai",
    "delhi": "Asia/Kolkata",
    "new delhi": "Asia/Kolkata",
    "mumbai": "Asia/Kolkata",
    "bangalore": "Asia/Kolkata"
};

var ZONE_ABBREVIATIONS = {
    "utc": "UTC",
    "gmt": "UTC",
    "wet": "Europe/Lisbon",
    "bst": "Europe/London",
    "cet": "Europe/Paris",
    "cest": "Europe/Paris",
    "eet": "Europe/Athens",
    "est": "America/New_York",
    "edt": "America/New_York",
    "cst": "America/Chicago",
    "cdt": "America/Chicago",
    "mst": "America/Denver",
    "mdt": "America/Denver",
    "pst": "America/Los_Angeles",
    "pdt": "America/Los_Angeles",
    "ist": "Asia/Kolkata",
    "sgt": "Asia/Singapore",
    "hkt": "Asia/Hong_Kong",
    "kst": "Asia/Seoul",
    "jst": "Asia/Tokyo",
    "aest": "Australia/Sydney",
    "aedt": "Australia/Sydney",
    "nzst": "Pacific/Auckland",
    "nzdt": "Pacific/Auckland"
};

function zoneConvertAsk(text) {
    const t = String(text || "").trim().toLowerCase().replace(/\s+/g, " ");
    const time = "(\\d{1,2}(?:[:.]\\d{2})?\\s*(?:am|pm)?|noon|midnight)";
    let m = new RegExp(`^${time} (?:in )?(.+?) (?:in|to|->|→) (.+)$`).exec(t);
    let from = "", to = "";
    if (m) {
        from = m[2];
        to = m[3];
    } else if ((m = new RegExp(`^${time} (?:in|to) (.+)$`).exec(t))) {
        to = m[2];
    } else if ((m = new RegExp(`^${time} (.+?)(?: time)?$`).exec(t))) {
        from = m[2];
    } else {
        return null;
    }
    const clock = m[1] === "noon" ? {
        hour: 12,
        minute: 0
    } : m[1] === "midnight" ? {
        hour: 0,
        minute: 0
    } : clockOf(m[1], false);
    if (!clock || from === to || (from && from.length < 2) || (to && to.length < 2))
        return null;
    return {
        clock: clock,
        from: from,
        to: to
    };
}

function readConversion(text) {
    const lines = String(text || "").trim().split("\n");
    const m = /^(\d{2}) (\d{2}) (\d{4}-\d{2}-\d{2})$/.exec((lines[0] || "").trim());
    if (!m || !/^\d{4}-\d{2}-\d{2}$/.test((lines[1] || "").trim()))
        return null;
    return {
        hour: parseInt(m[1], 10),
        minute: parseInt(m[2], 10),
        day: m[3],
        shift: Math.round((Date.parse(m[3]) - Date.parse(lines[1].trim())) / 86400000)
    };
}

function zoneAsk(text) {
    const t = String(text || "").trim().toLowerCase();
    const m = /^(?:what\s+)?(?:time|clock)\s+(?:is\s+it\s+)?in\s+(.+)$/.exec(t) || /^time\s+(?!in$)(.+)$/.exec(t) || /^(.+?)\s+time$/.exec(t);
    const place = m ? m[1].trim() : "";
    return place.length >= 2 ? place : "";
}

function zoneMatches(zones, place, cityOf) {
    const want = String(place || "").toLowerCase();
    const alias = ZONE_ALIASES[want];
    const rank = id => {
        if (id === alias)
            return 4;
        const city = cityOf(id).toLowerCase();
        return city === want ? 3 : city.indexOf(want) === 0 ? 2 : want.length >= 3 && city.indexOf(want) > 0 ? 1 : 0;
    };
    return (zones || []).filter(id => id.indexOf("/") > 0 && id.indexOf("Etc/") !== 0).map(id => ({
                id: id,
                rank: rank(id)
            })).filter(z => z.rank > 0).sort((a, b) => b.rank - a.rank || a.id.length - b.id.length || a.id.localeCompare(b.id)).map(z => z.id);
}

function readOffsets(text) {
    const map = {};
    for (const line of String(text || "").split("\n")) {
        const m = /^(\S+)\s+([+-])(\d{2})(\d{2})$/.exec(line.trim());
        if (m)
            map[m[1]] = (m[2] === "-" ? -1 : 1) * (parseInt(m[3], 10) * 60 + parseInt(m[4], 10));
    }
    return map;
}

function killAsk(text) {
    const m = /^(?:kill|force\s+quit)(?:\s+(.*))?$/i.exec(String(text || "").trim());
    return m ? (m[1] || "").trim().toLowerCase() : null;
}

function readProcesses(text, skip) {
    return String(text || "").split("\n").map(line => /^\s*(\d+)\s+(\d+)\s+(.+?)\s*$/.exec(line)).filter(m => m && (skip || []).indexOf(m[3]) < 0).map(m => ({
                pid: parseInt(m[1], 10),
                kb: parseInt(m[2], 10),
                name: m[3]
            }));
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

function chordParts(chord) {
    return String(chord || "").split("+").map(p => p.trim()).filter(Boolean);
}

function sameChord(a, b) {
    const norm = c => chordParts(c).map(p => p.toUpperCase()).sort().join("+");
    return !!norm(a) && norm(a) === norm(b);
}

function legacyChord(chord) {
    const parts = chordParts(chord);
    const key = parts.pop() || "";
    return `${parts.join(" ")}, ${key}`;
}

function chordText(chord) {
    return chordParts(chord).map(p => p.length <= 1 ? p : p.charAt(0) + p.slice(1).toLowerCase()).join(" ");
}

function hotkeyCommand(id) {
    return `banditshell panel launcher run '${String(id).replace(/'/g, "'\\''")}'`;
}

function cleanAlias(text) {
    return String(text || "").trim().toLowerCase().replace(/\s+/g, " ");
}

function aliasTarget(aliases, text) {
    const said = cleanAlias(text);
    return said && aliases && Object.prototype.hasOwnProperty.call(aliases, said) ? aliases[said].id || "" : "";
}

function aliasesById(aliases) {
    const out = {};
    for (const alias of Object.keys(aliases || {}))
        out[aliases[alias].id] = alias;
    return out;
}

function withAlias(aliases, id, alias, label) {
    const out = {};
    for (const key of Object.keys(aliases || {}))
        if (aliases[key].id !== id)
            out[key] = aliases[key];
    const said = cleanAlias(alias);
    if (said)
        out[said] = {
            id: id,
            label: label || id
        };
    return out;
}

var ENGINES = [["https://duckduckgo.com/?q=%s", "DuckDuckGo"], ["https://www.google.com/search?q=%s", "Google"], ["https://www.bing.com/search?q=%s", "Bing"], ["https://search.brave.com/search?q=%s", "Brave"], ["https://www.startpage.com/do/search?q=%s", "Startpage"], ["https://www.ecosia.org/search?q=%s", "Ecosia"], ["https://kagi.com/search?q=%s", "Kagi"]];

var FALLBACKS = [
    {
        id: "web",
        icon: "travel_explore",
        label: "Search the web for “%s”"
    },
    {
        id: "youtube",
        icon: "smart_display",
        label: "Search YouTube for “%s”",
        url: "https://www.youtube.com/results?search_query=%s"
    },
    {
        id: "wikipedia",
        icon: "menu_book",
        label: "Search Wikipedia for “%s”",
        url: "https://en.wikipedia.org/w/index.php?search=%s"
    },
    {
        id: "maps",
        icon: "map",
        label: "Find “%s” on a map",
        url: "https://www.openstreetmap.org/search?query=%s"
    },
    {
        id: "terminal",
        icon: "terminal",
        label: "Run “%s” in a terminal"
    }
];

function fallbackRows(chosen, text, webTemplate) {
    return FALLBACKS.filter(f => chosen && chosen[f.id]).map((f, i) => ({
                id: f.id,
                icon: f.icon,
                label: f.label.replace("%s", () => text),
                url: f.id === "terminal" ? "" : webSearchUrl(f.id === "web" ? webTemplate : f.url, text),
                order: i
            }));
}

function contentRow(line, home) {
    const m = /^(.*?):(\d+):(.*)$/.exec(String(line || ""));
    if (!m || !m[1])
        return null;
    const path = m[1];
    const cut = path.lastIndexOf("/");
    return {
        path: path,
        name: path.slice(cut + 1),
        line: parseInt(m[2], 10),
        text: m[3].trim().replace(/\s+/g, " "),
        where: shortPath(path.slice(0, cut) || "/", home)
    };
}

function usableArea(mon) {
    const turned = (mon.transform || 0) % 2 === 1;
    const scale = mon.scale || 1;
    const w = (turned ? mon.height : mon.width) / scale;
    const h = (turned ? mon.width : mon.height) / scale;
    const r = mon.reserved || [0, 0, 0, 0];
    return {
        x: mon.x + r[0],
        y: mon.y + r[1],
        w: w - r[0] - r[2],
        h: h - r[1] - r[3]
    };
}

function cellRect(area, outer, inner, tile) {
    const gap = inner * 2;
    const cw = (area.w - 2 * outer - (tile.cols - 1) * gap) / tile.cols;
    const ch = (area.h - 2 * outer - (tile.rows - 1) * gap) / tile.rows;
    const span = tile.span || 1;
    const tall = tile.tall || 1;
    return {
        x: Math.round(area.x + outer + tile.col * (cw + gap)),
        y: Math.round(area.y + outer + tile.row * (ch + gap)),
        w: Math.round(cw * span + gap * (span - 1)),
        h: Math.round(ch * tall + gap * (tall - 1))
    };
}

function tileSet() {
    const out = [];
    const add = (id, label, words, cols, rows, col, row, span) => out.push({
            id: id,
            label: label,
            words: `${words} snap window`,
            cols: cols,
            rows: rows,
            col: col,
            row: row,
            span: span || 1
        });
    const sides = ["left", "right"];
    const ends = ["top", "bottom"];
    const thirds = ["first", "center", "last"];
    const across = ["left", "center", "right"];
    const word = w => w.charAt(0).toUpperCase() + w.slice(1);
    sides.forEach((s, i) => add(`${s}-half`, `${word(s)} half`, `${s} half`, 2, 1, i, 0));
    ends.forEach((e, i) => add(`${e}-half`, `${word(e)} half`, `${e} half`, 1, 2, 0, i));
    thirds.forEach((t, i) => add(`${t}-third`, `${word(t)} third`, `${t} third ${across[i]} third`, 3, 1, i, 0));
    [thirds[0], thirds[2]].forEach((t, i) => add(`${t}-two-thirds`, `${word(t)} two thirds`, `${t} two thirds ${sides[i]} two thirds`, 3, 1, i, 0, 2));
    ends.forEach((e, r) => sides.forEach((s, c) => add(`${e}-${s}-quarter`, `${word(e)} ${s} quarter`, `${e} ${s} quarter corner`, 2, 2, c, r)));
    ends.forEach((e, r) => across.forEach((a, c) => add(`${e}-${a}-sixth`, `${word(e)} ${a} sixth`, `${e} ${a} sixth`, 3, 2, c, r)));
    return out;
}

var TILES = tileSet();

function workspaceAsk(text) {
    const m = /^(?:move|send|put)(?: (?:the )?window)? to (?:workspace |ws )?(\d{1,2})$/i.exec(String(text || "").trim());
    return m ? parseInt(m[1], 10) : 0;
}

function focusWorkspaceAsk(text) {
    const m = /^(?:focus |go to |goto |switch to |show |open )?(?:workspace|ws) (\d{1,2})$/i.exec(String(text || "").trim());
    return m ? parseInt(m[1], 10) : 0;
}

function layoutLabel(name) {
    const bare = String(name || "").replace(/^lua:/, "");
    return bare.charAt(0).toUpperCase() + bare.slice(1);
}

function luaLayouts(texts) {
    const out = [];
    const find = /hl\.layout\.register\(\s*["']([^"']+)["']/g;
    for (const text of texts || []) {
        let m;
        while ((m = find.exec(String(text))) !== null)
            if (out.indexOf(`lua:${m[1]}`) < 0)
                out.push(`lua:${m[1]}`);
    }
    return out;
}

var PHRASES = [
    {
        head: "days until ",
        picks: ["christmas", "christmas eve", "new year", "easter", "halloween", "valentine's day", "next friday", "31 dec"]
    },
    {
        head: "days since ",
        picks: ["1 jan", "christmas", "easter", "last monday"]
    },
    {
        head: "days between ",
        picks: ["1 jan and 31 dec", "today and christmas"]
    },
    {
        head: "weeks until ",
        picks: ["christmas", "new year", "easter"]
    },
    {
        head: "what day is ",
        picks: ["christmas", "new year", "1 jan", "easter"]
    },
    {
        head: "timer ",
        picks: ["5m", "10m", "25m", "1h"]
    },
    {
        head: "remind me ",
        picks: ["in 20 min to ", "in 1h to ", "at 15:00 to "]
    },
    {
        head: "keep awake ",
        picks: ["30m", "1h", "2h"]
    },
    {
        head: "time in ",
        picks: "places"
    },
    {
        head: "focus workspace ",
        picks: "workspaces"
    },
    {
        head: "move to workspace ",
        picks: "workspaces"
    },
    {
        head: "volume ",
        picks: "playing"
    },
    {
        head: "kill ",
        picks: "processes"
    }
];

function suggestions(text, found, more) {
    const t = String(text || "").replace(/^\s+/, "").toLowerCase();
    if (t.length < 2)
        return [];
    const out = [];
    for (const p of PHRASES.concat(more || [])) {
        const picks = typeof p.picks === "string" ? (found && found[p.picks]) || [] : p.picks;
        if (t.indexOf(p.head) === 0) {
            const rest = t.slice(p.head.length);
            for (const pick of picks) {
                const said = String(pick).toLowerCase();
                if (said.indexOf(rest) === 0 && said !== rest && out.indexOf(p.head + said) < 0)
                    out.push(p.head + said);
            }
        } else if (p.head.indexOf(t) === 0 && picks.length) {
            out.push(p.head);
        }
    }
    return out;
}
