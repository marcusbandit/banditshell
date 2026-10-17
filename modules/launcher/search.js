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

var PICTURE = /\.(?:png|jpe?g|webp|gif|bmp|svg|avif|tiff?)$/i;

function streamName(label) {
    return String(label || "").replace(/\.(?:x86_64|x86|x64|exe|bin|appimage)$/i, "");
}

function isPicture(path) {
    return PICTURE.test(String(path || ""));
}

var TEXTUAL = /(?:\.(?:md|markdown|txt|text|rst|org|adoc|qml|js|mjs|cjs|ts|tsx|jsx|json|jsonc|py|sh|bash|zsh|fish|lua|rs|go|c|h|cc|cpp|hpp|cs|java|kt|kts|swift|rb|php|pl|r|sql|css|scss|sass|less|html|htm|xml|svg|toml|yaml|yml|ini|conf|cfg|env|log|csv|tsv|nix|gradle|cmake|mk|vim|el|clj|ex|exs|erl|hs|ml|dart|vue|svelte|tex|bib|desktop|service|rules|patch|diff|gitignore|frag|vert|glsl)|\/(?:Makefile|Dockerfile|Containerfile|PKGBUILD|README|LICENSE|CHANGELOG|COPYING|\.zshrc|\.bashrc|\.profile))$/i;

var SECRETISH = /(?:secret|token|credential|passw|apikey|api[_-]key|adminsdk|wallet|keyring|cookies|id_rsa|id_ed25519|id_ecdsa|backup.?code)|(?:^|[^a-z])(?:auth|recovery|seed|mnemonic|otp|private)(?:s?(?:[^a-z]|$))|[_.-]keys?(?:\.|$)|\.env(?:\.|$)|\.(?:pem|p12|pfx|kdbx|gpg|asc|netrc|pgpass)$/i;
var SECRET_FOLDERS = /\/\.(?:ssh|gnupg|aws|kube|docker|password-store|config\/gh|config\/rclone|local\/share\/keyrings)(?:\/|$)/;

function isText(path) {
    return TEXTUAL.test(String(path || ""));
}

function isSecretish(path) {
    var text = String(path || "");
    return SECRET_FOLDERS.test(text) || SECRETISH.test(text.slice(text.lastIndexOf("/") + 1));
}

function fileUrl(path) {
    return "file://" + String(path || "").split("/").map(encodeURIComponent).join("/");
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

function pathScore(path, query, place) {
    const want = String(query || "").replace(/^\/+|\/+$/g, "");
    const tail = path.split("/").slice(-want.split("/").length).join("/");
    const placed = place(tail, want);
    return placed > 0 ? placed : place(path, want) > 0 ? 0.5 : placed;
}

function fileRows(lines, query, place) {
    const byPath = String(query || "").indexOf("/") >= 0;
    return (lines || []).filter(l => !!l).map(line => {
        const dir = line[line.length - 1] === "/";
        const path = dir ? line.slice(0, -1) : line;
        const name = path.slice(path.lastIndexOf("/") + 1);
        return {
            path: path,
            name: name,
            dir: dir,
            fileClass: dir ? "directory" : "unknown",
            score: byPath ? pathScore(path, query, place) : place(name, query),
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

function encodedQuery(text) {
    try {
        return encodeURIComponent(text);
    } catch (error) {
        return encodeURIComponent(text.replace(/[\ud800-\udfff]/g, "\ufffd"));
    }
}

function webSearchUrl(template, text) {
    return String(template || "").replace("%s", encodedQuery(String(text || "").trim()));
}

function remembered(groups, bonusOf) {
    return (groups || []).map(g => {
        let lifted = false;
        const items = g.items.map((it, i) => {
            const bonus = it.kind === "app" || it.kind === "latest" || it.header || !isFinite(it.score ?? 0) ? 0 : bonusOf(it.key);
            if (bonus > 0)
                lifted = true;
            return {
                it: bonus > 0 ? Object.assign({}, it, {
                    score: (it.score ?? 0) + bonus
                }) : it,
                i: i
            };
        });
        if (!lifted)
            return g;
        items.sort((a, b) => (b.it.score ?? 0) - (a.it.score ?? 0) || a.i - b.i);
        return Object.assign({}, g, {
            items: items.map(x => x.it)
        });
    });
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

var NUMBER_WORDS = {
    a: 1,
    an: 1,
    one: 1,
    two: 2,
    three: 3,
    four: 4,
    five: 5,
    six: 6,
    seven: 7,
    eight: 8,
    nine: 9,
    ten: 10,
    eleven: 11,
    twelve: 12,
    thirteen: 13,
    fourteen: 14,
    fifteen: 15,
    sixteen: 16,
    seventeen: 17,
    eighteen: 18,
    nineteen: 19,
    twenty: 20,
    thirty: 30,
    forty: 40,
    fifty: 50,
    sixty: 60,
    seventy: 70,
    eighty: 80,
    ninety: 90,
    couple: 2,
    few: 3
};

var NUMBER_WORD = "(?:a\\s+couple(?:\\s+of)?|a\\s+few|couple(?:\\s+of)?|twenty|thirty|forty|fifty|sixty|seventy|eighty|ninety)(?:[\\s-]+(?:one|two|three|four|five|six|seven|eight|nine))?|an?|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen";

var SPOKEN_HEAD = new RegExp(`^(${NUMBER_WORD}|\\d+(?:[.,]\\d+)?)(\\s+and\\s+a\\s+half)?\\s+(hours?|hrs?|minutes?|mins?|seconds?|secs?)(?![a-z])(\\s+and\\s+a\\s+half)?\\s*(?:and\\s+)?`, "i");

var FRACTION_HEAD = /^(?:(half)\s+(?:an?\s+)?|(?:an?\s+)?(quarter)\s+(?:of\s+)?(?:an?\s+)?|(three)\s+quarters?\s+of\s+(?:an?\s+)?)(hour|minute)(?![a-z])\s*(?:and\s+)?/i;

var TRAILING_NUMBER = /^(\d{1,2})(?![\d.,:a-z])\s*/i;

function unitSeconds(unit) {
    const u = unit.toLowerCase();
    return u[0] === "h" ? 3600 : u[0] === "m" ? 60 : 1;
}

function spokenNumber(text) {
    const words = text.toLowerCase().replace(/\s+of$/, "").split(/[\s-]+/).filter(w => w !== "a" || text.trim().toLowerCase() === "a");
    return words.reduce((sum, w) => sum + (NUMBER_WORDS[w] ?? parseFloat(w.replace(",", "."))), 0);
}

function spanHead(rest) {
    let m = SPAN_HEAD.exec(rest);
    if (m)
        return {
            seconds: parseFloat(m[1].replace(",", ".")) * unitSeconds(m[2]),
            unit: unitSeconds(m[2]),
            joined: /[a-z]$/i.test(m[0]),
            length: m[0].length
        };
    m = SPOKEN_HEAD.exec(rest);
    if (m)
        return {
            seconds: (spokenNumber(m[1]) + (m[2] || m[4] ? 0.5 : 0)) * unitSeconds(m[3]),
            unit: unitSeconds(m[3]),
            joined: false,
            length: m[0].length
        };
    m = FRACTION_HEAD.exec(rest);
    if (m)
        return {
            seconds: (m[1] ? 0.5 : m[2] ? 0.25 : 0.75) * unitSeconds(m[4]),
            unit: unitSeconds(m[4]),
            joined: false,
            length: m[0].length
        };
    return null;
}

function leadingSpan(text, bareMinutes) {
    let rest = String(text || "").trim();
    let total = 0;
    let last = null;
    let head;
    while ((head = spanHead(rest)) !== null) {
        total += head.seconds;
        last = head;
        rest = rest.slice(head.length);
    }
    if (last && last.unit > 1) {
        const tail = TRAILING_NUMBER.exec(rest);
        const amount = tail ? parseInt(tail[1], 10) : -1;
        if (tail && amount < 60 && (last.unit === 3600 || last.joined || tail[0].length === rest.length)) {
            total += amount * last.unit / 60;
            rest = rest.slice(tail[0].length);
        }
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

var TIMER_VERB = /^(?:please\s+)?(?:(?:can\s+you\s+|could\s+you\s+)?(?:set|start|make|create|begin|run|put\s+on|give\s+me)\s+(?:me\s+)?(?:up\s+)?)/i;
var LEADING_ARTICLE = /^(?:an?|the|my)\s+/i;
var TIMER_LED = /^(?:timer|countdown)\s+(?:for\s+|of\s+)?(.*)$/i;
var TIMER_TAIL = /^(?:timer|countdown)(?:\s+(?:for\s+|called\s+|named\s+|to\s+)?(.*))?$/i;
var TIMER_LABEL_LEAD = /^(?:for|called|named|labelled|labeled|to)\s+/i;

function timerForm(t) {
    const led = TIMER_LED.exec(t);
    if (led) {
        const span = leadingSpan(led[1], true);
        return span ? {
            seconds: span.seconds,
            label: span.rest.replace(TIMER_LABEL_LEAD, "")
        } : null;
    }
    const span = leadingSpan(t, false);
    const tail = span && TIMER_TAIL.exec(span.rest);
    return tail ? {
        seconds: span.seconds,
        label: (tail[1] || "").trim()
    } : null;
}

function timerAsk(text) {
    const t = String(text || "").trim().replace(TIMER_VERB, "");
    return timerForm(t) || (LEADING_ARTICLE.test(t) ? timerForm(t.replace(LEADING_ARTICLE, "")) : null);
}

var CLOCK_TEXT = /^(\d{1,2})(?:[:.](\d{2}))?\s*(am|pm|a\.m\.|p\.m\.)?$/i;
var CLOCK_COMPACT = /^(\d{1,2})(\d{2})\s*(am|pm)?$/i;

function clockOf(text, loose) {
    const t = String(text || "").trim().toLowerCase();
    if (t === "noon" || t === "midday")
        return {
            hour: 12,
            minute: 0
        };
    if (t === "midnight")
        return {
            hour: 0,
            minute: 0
        };
    const m = CLOCK_TEXT.exec(t) || (loose ? CLOCK_COMPACT.exec(t) : null);
    if (!m || !(m[2] || m[3] || loose))
        return null;
    let hour = parseInt(m[1], 10);
    const minute = m[2] ? parseInt(m[2], 10) : 0;
    const half = (m[3] || "").replace(/\./g, "").toLowerCase();
    if (minute > 59 || hour > (half ? 12 : 23) || (half && hour === 0))
        return null;
    if (half)
        hour = hour % 12 + (half === "pm" ? 12 : 0);
    return {
        hour: hour,
        minute: minute
    };
}

var CLOCK = "\\d{1,2}(?:[:.]\\d{2})?(?:\\s*(?:am|pm|a\\.m\\.|p\\.m\\.))?|noon|midday|midnight";
var CLOCK_AT = `\\d{3,4}(?:\\s*(?:am|pm))?|${CLOCK}`;

var WEEKDAY_NAMES = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
var WEEKDAY_SHORT = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
var MONTH_SHORT = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"];

var WEEKDAY = "monday|tuesday|wednesday|thursday|friday|saturday|sunday";
var WEEKDAY_ANY = `${WEEKDAY}|mon|tues?|wed|thu(?:rs?)?|fri|sat|sun`;
var MONTH = "january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sept?|oct|nov|dec";
var ORDINAL = "\\d{1,2}(?:st|nd|rd|th)?";
var DAY_COUNT = "\\d{1,3}|a|an|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|thirteen|fourteen|fifteen|twenty|thirty";
var DAY_PART = "(?:\\s+(?:morning|afternoon|evening|night))?";

var DAY_PHRASE = [
    "(?:the\\s+)?day\\s+after\\s+tomorrow",
    "tomorrow(?:\\s+(?:morning|afternoon|evening|night))?",
    "tmrw|tmr",
    "today",
    "tonight",
    "this\\s+(?:morning|afternoon|evening)",
    "next\\s+week",
    `(?:next|this|coming)\\s+(?:${WEEKDAY_ANY})${DAY_PART}`,
    `(?:${WEEKDAY})${DAY_PART}`,
    `(?:the\\s+)?${ORDINAL}\\s+(?:of\\s+)?(?:${MONTH})\\.?`,
    `(?:${MONTH})\\.?\\s+${ORDINAL}`,
    "\\d{4}-\\d{1,2}-\\d{1,2}",
    "\\d{1,2}/\\d{1,2}(?:/\\d{2,4})?",
    "the\\s+\\d{1,2}(?:st|nd|rd|th)",
    `in\\s+(?:${DAY_COUNT})\\s+(?:days?|weeks?)`
].join("|");

var DAY_LEAD = new RegExp(`^(?:on\\s+)?(${DAY_PHRASE})(?![a-z0-9])\\s*`, "i");
var DAY_TAIL = new RegExp(`\\s+(?:on\\s+)?(${DAY_PHRASE})$`, "i");
var TIME_LEAD = new RegExp(`^(at\\s+)?(${CLOCK_AT})(?![\\w:.])\\s*`, "i");
var TIME_TAIL = new RegExp(`\\s+(?:at\\s+)(${CLOCK_AT})$`, "i");
var REMIND = /^remind\s+me\s+(.+)$/i;
var REMIND_WHAT = /^(to|about|that|of)(?:\s+|$)/i;
var SPAN_SPLIT = /\s+in(?=\s)/gi;
var MERIDIEM = /(?:am|pm|a\.m\.|p\.m\.)$/i;

function partOfDay(day) {
    const m = /(morning|afternoon|evening|night)$/.exec(day) || (day === "tonight" ? ["", "night"] : null);
    return m ? m[1] : "";
}

function reminderAsk(text) {
    const m = REMIND.exec(String(text || "").trim());
    if (!m)
        return null;
    let rest = m[1].trim();
    let day = "";
    let at = null;
    let said = "";
    let link = "";
    const what = s => {
        const trimmed = (s || "").trim();
        const lead = REMIND_WHAT.exec(trimmed);
        if (lead)
            link = lead[1].toLowerCase() === "of" ? "about" : lead[1].toLowerCase();
        return trimmed.replace(REMIND_WHAT, "").trim();
    };
    const linked = out => {
        if (link && link !== "to" && out && out.label)
            out.link = link;
        return out;
    };
    const pullDay = (pattern, lead) => {
        if (day)
            return;
        const d = pattern.exec(rest);
        if (!d)
            return;
        day = d[1].toLowerCase().replace(/\s+/g, " ").replace(/\.$/, "");
        rest = lead ? rest.slice(d[0].length) : rest.slice(0, d.index);
    };
    pullDay(DAY_LEAD, true);
    const first = TIME_LEAD.exec(rest);
    const early = first && clockOf(first[2], !!first[1]);
    if (early) {
        at = early;
        said = first[2];
        rest = rest.slice(first[0].length);
        pullDay(DAY_LEAD, true);
    }
    pullDay(DAY_TAIL, false);
    if (!at) {
        const last = TIME_TAIL.exec(rest);
        const late = last && clockOf(last[1], true);
        if (late) {
            at = late;
            said = last[1];
            rest = rest.slice(0, last.index);
            pullDay(DAY_TAIL, false);
        }
    }
    if (at || day) {
        const part = partOfDay(day);
        const bare = at && !MERIDIEM.test(said.trim());
        if (bare && part === "night" && at.hour === 12)
            at = {
                hour: 0,
                minute: at.minute
            };
        else if (bare && (part === "afternoon" || part === "evening" || part === "night" && at.hour >= 5) && at.hour < 12 && at.hour > 0)
            at = {
                hour: at.hour + 12,
                minute: at.minute
            };
        const out = {
            at: at,
            label: what(rest)
        };
        if (day)
            out.day = day;
        return linked(out);
    }
    const lead = /^in\s+(.*)$/i.exec(rest);
    if (lead) {
        const span = leadingSpan(lead[1], false);
        return span ? linked({
            seconds: span.seconds,
            label: what(span.rest)
        }) : null;
    }
    const splits = [];
    let split;
    SPAN_SPLIT.lastIndex = 0;
    while ((split = SPAN_SPLIT.exec(rest)) !== null)
        splits.push(split);
    for (let i = splits.length - 1; i >= 0; i--) {
        const head = rest.slice(0, splits[i].index);
        const span = head ? leadingSpan(rest.slice(splits[i].index + splits[i][0].length).trim(), false) : null;
        if (span && !span.rest)
            return linked({
                seconds: span.seconds,
                label: what(head)
            });
    }
    return null;
}

function dayIndex(word, names, short) {
    const w = String(word || "").toLowerCase();
    const full = names.indexOf(w);
    return full >= 0 ? full : short.findIndex(s => w.indexOf(s) === 0);
}

function validDay(y, m, d) {
    const date = new Date(y, m, d);
    return date.getFullYear() === y && date.getMonth() === m && date.getDate() === d ? date : null;
}

function reminderDay(phrase, now) {
    const p = String(phrase || "").toLowerCase().replace(/\s+/g, " ").trim();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const plus = n => new Date(today.getFullYear(), today.getMonth(), today.getDate() + n);
    if (/^(?:today|tonight|this (?:morning|afternoon|evening))$/.test(p))
        return {
            date: today,
            rolls: false
        };
    if (/^(?:the )?day after tomorrow$/.test(p))
        return {
            date: plus(2),
            rolls: false
        };
    if (/^(?:tomorrow|tmrw|tmr)/.test(p))
        return {
            date: plus(1),
            rolls: false
        };
    if (p === "next week")
        return {
            date: plus(7),
            rolls: false
        };
    let m = /^in (\S+) (days?|weeks?)$/.exec(p);
    if (m) {
        const n = NUMBER_WORDS[m[1]] ?? parseInt(m[1], 10);
        return n > 0 ? {
            date: plus(m[2][0] === "w" ? 7 * n : n),
            rolls: false
        } : null;
    }
    m = /^(?:(next|this|coming) )?(\S+)(?: (?:morning|afternoon|evening|night))?$/.exec(p);
    const weekday = m ? dayIndex(m[2], WEEKDAY_NAMES, WEEKDAY_SHORT) : -1;
    if (m && weekday >= 0 && (m[1] || WEEKDAY_NAMES.indexOf(m[2]) >= 0)) {
        let step = (weekday - today.getDay() + 7) % 7;
        if (m[1] === "next" && step === 0)
            step = 7;
        return {
            date: plus(step),
            rolls: m[1] !== "next" ? "week" : false
        };
    }
    m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(p);
    if (m) {
        const date = validDay(+m[1], +m[2] - 1, +m[3]);
        return date ? {
            date: date,
            rolls: false
        } : null;
    }
    m = /^(\d{1,2})\/(\d{1,2})(?:\/(\d{2}|\d{4}))?$/.exec(p);
    if (m) {
        let d = +m[1], mo = +m[2];
        if (mo > 12 && d <= 12)
            [d, mo] = [mo, d];
        const year = m[3] ? (m[3].length === 2 ? 2000 + +m[3] : +m[3]) : today.getFullYear();
        let date = validDay(year, mo - 1, d);
        if (date && !m[3] && date < today)
            date = validDay(year + 1, mo - 1, d);
        return date ? {
            date: date,
            rolls: m[3] ? false : "year"
        } : null;
    }
    m = /^the (\d{1,2})(?:st|nd|rd|th)$/.exec(p);
    if (m) {
        let date = validDay(today.getFullYear(), today.getMonth(), +m[1]);
        for (let ahead = 1; (!date || date < today) && ahead <= 12; ahead++) {
            const month = new Date(today.getFullYear(), today.getMonth() + ahead, 1);
            date = validDay(month.getFullYear(), month.getMonth(), +m[1]);
        }
        return date ? {
            date: date,
            rolls: "month"
        } : null;
    }
    m = /^(?:the )?(\d{1,2})(?:st|nd|rd|th)? (?:of )?([a-z]+)$/.exec(p) || /^([a-z]+) (\d{1,2})(?:st|nd|rd|th)?$/.exec(p);
    if (m) {
        const dayFirst = /^\d/.test(m[1]);
        const month = dayIndex((dayFirst ? m[2] : m[1]).slice(0, 3), [], MONTH_SHORT);
        const d = +(dayFirst ? m[1] : m[2]);
        if (month < 0)
            return null;
        let date = validDay(today.getFullYear(), month, d);
        if (date && date < today)
            date = validDay(today.getFullYear() + 1, month, d);
        return date ? {
            date: date,
            rolls: "year"
        } : null;
    }
    return null;
}

var PART_HOURS = {
    afternoon: 15,
    evening: 19,
    night: 20
};

var VAGUE_HOUR = /(?:^|\s)at\s+(\d{1,2})(?![\d:.]|\s*(?:am|pm|a\.m\.|p\.m\.))(?:\s|$)/i;

function vagueHour(text) {
    const m = VAGUE_HOUR.exec(String(text || ""));
    return !!m && parseInt(m[1], 10) >= 1 && parseInt(m[1], 10) <= 11;
}

function rolledMoment(date, rolls, hour, minute, now) {
    for (let step = 0; step <= 24; step++) {
        const year = date.getFullYear() + (rolls === "year" ? step : 0);
        const month = date.getMonth() + (rolls === "month" ? step : 0);
        const day = date.getDate() + (rolls === "week" ? 7 * step : 0);
        const moment = new Date(year, month, day, hour, minute);
        const fits = rolls === "week" || moment.getDate() === date.getDate();
        if (fits && moment > now)
            return moment.getTime();
        if (!rolls)
            return 0;
    }
    return 0;
}

function reminderMoment(ask, now, morningHour, vague, twelveHour) {
    if (!ask)
        return 0;
    if (ask.seconds)
        return now.getTime() + ask.seconds * 1000;
    const part = ask.day ? partOfDay(ask.day) : "";
    let hour = ask.at ? ask.at.hour : PART_HOURS[part] ?? morningHour ?? 9;
    const minute = ask.at ? ask.at.minute : 0;
    if (vague && !part && hour >= 1 && hour <= 6)
        hour += 12;
    if (!ask.day) {
        const on = (offset, h) => new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset, h, minute);
        if (vague && twelveHour && hour >= 1 && hour <= 11 && on(0, hour) <= now && on(0, hour + 12) > now)
            return on(0, hour + 12).getTime();
        return on(0, hour) > now ? on(0, hour).getTime() : on(1, hour).getTime();
    }
    const found = reminderDay(ask.day, now);
    if (!found)
        return 0;
    const late = part === "night" && ask.at && hour < 5 ? 1 : 0;
    const date = new Date(found.date.getFullYear(), found.date.getMonth(), found.date.getDate() + late);
    return rolledMoment(date, found.rolls, hour, minute, now);
}

var VOLUME_LEVEL = /^(?:(?:set|turn|put|change)\s+)?(?:the\s+)?(?:volume|vol|sound)\s+(?:(?:up|down)\s+to\s+|to\s+|at\s+)?(\d{1,3})\s*(?:%|percent)?$/i;

function volumeLevelAsk(text) {
    const m = VOLUME_LEVEL.exec(String(text || "").trim());
    return m ? parseInt(m[1], 10) : -1;
}

function volumeAsk(text) {
    const level = volumeLevelAsk(text);
    return level <= 150 ? level : -1;
}

var LOUDER = /^(?:louder|turn\s+(?:it|this|that|the\s+(?:volume|sound|music))\s+up|turn\s+up(?:\s+the\s+(?:volume|sound|music))?|raise\s+(?:the\s+)?(?:volume|sound)|increase\s+(?:the\s+)?(?:volume|sound)|(?:volume|vol|sound)\s+up|more\s+volume|make\s+it\s+louder)$/i;

var QUIETER = /^(?:quieter|softer|turn\s+(?:it|this|that|the\s+(?:volume|sound|music))\s+down|turn\s+down(?:\s+the\s+(?:volume|sound|music))?|lower\s+(?:the\s+)?(?:volume|sound)|decrease\s+(?:the\s+)?(?:volume|sound)|reduce\s+(?:the\s+)?(?:volume|sound)|(?:volume|vol|sound)\s+down|less\s+volume|make\s+it\s+quieter|too\s+loud)$/i;

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

function streamNameAsk(text) {
    const t = String(text || "").trim().toLowerCase().replace(/\s+/g, " ");
    const m = /^(?:volume|vol|mute|unmute) (?:of |for )?(.+)$/.exec(t) || /^(.+?) (?:volume|vol)$/.exec(t);
    return m && m[1].length >= 2 && !/^(?:up|down|mixer|the|to|\d+ ?%?)$/.test(m[1]) ? m[1] : "";
}

function windowListAsk(text) {
    return /^(?:windows|window list|all windows|open windows|switch windows?|switcher|window switcher)$/i.test(String(text || "").trim());
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

var ZONE_REGIONS = {
    "india": "Asia/Kolkata",
    "germany": "Europe/Berlin",
    "france": "Europe/Paris",
    "uk": "Europe/London",
    "united kingdom": "Europe/London",
    "britain": "Europe/London",
    "great britain": "Europe/London",
    "england": "Europe/London",
    "scotland": "Europe/London",
    "wales": "Europe/London",
    "ireland": "Europe/Dublin",
    "spain": "Europe/Madrid",
    "portugal": "Europe/Lisbon",
    "italy": "Europe/Rome",
    "netherlands": "Europe/Amsterdam",
    "holland": "Europe/Amsterdam",
    "belgium": "Europe/Brussels",
    "luxembourg": "Europe/Luxembourg",
    "switzerland": "Europe/Zurich",
    "austria": "Europe/Vienna",
    "denmark": "Europe/Copenhagen",
    "sweden": "Europe/Stockholm",
    "norway": "Europe/Oslo",
    "finland": "Europe/Helsinki",
    "iceland": "Atlantic/Reykjavik",
    "estonia": "Europe/Tallinn",
    "latvia": "Europe/Riga",
    "lithuania": "Europe/Vilnius",
    "poland": "Europe/Warsaw",
    "czechia": "Europe/Prague",
    "czech republic": "Europe/Prague",
    "slovakia": "Europe/Bratislava",
    "hungary": "Europe/Budapest",
    "slovenia": "Europe/Ljubljana",
    "croatia": "Europe/Zagreb",
    "serbia": "Europe/Belgrade",
    "romania": "Europe/Bucharest",
    "bulgaria": "Europe/Sofia",
    "greece": "Europe/Athens",
    "cyprus": "Asia/Nicosia",
    "turkey": "Europe/Istanbul",
    "türkiye": "Europe/Istanbul",
    "ukraine": "Europe/Kyiv",
    "belarus": "Europe/Minsk",
    "israel": "Asia/Jerusalem",
    "egypt": "Africa/Cairo",
    "morocco": "Africa/Casablanca",
    "nigeria": "Africa/Lagos",
    "ghana": "Africa/Accra",
    "kenya": "Africa/Nairobi",
    "ethiopia": "Africa/Addis_Ababa",
    "south africa": "Africa/Johannesburg",
    "uae": "Asia/Dubai",
    "united arab emirates": "Asia/Dubai",
    "saudi arabia": "Asia/Riyadh",
    "qatar": "Asia/Qatar",
    "iran": "Asia/Tehran",
    "iraq": "Asia/Baghdad",
    "pakistan": "Asia/Karachi",
    "bangladesh": "Asia/Dhaka",
    "nepal": "Asia/Kathmandu",
    "sri lanka": "Asia/Colombo",
    "thailand": "Asia/Bangkok",
    "vietnam": "Asia/Ho_Chi_Minh",
    "malaysia": "Asia/Kuala_Lumpur",
    "philippines": "Asia/Manila",
    "china": "Asia/Shanghai",
    "taiwan": "Asia/Taipei",
    "japan": "Asia/Tokyo",
    "korea": "Asia/Seoul",
    "south korea": "Asia/Seoul",
    "new zealand": "Pacific/Auckland",
    "nz": "Pacific/Auckland",
    "argentina": "America/Argentina/Buenos_Aires",
    "chile": "America/Santiago",
    "colombia": "America/Bogota",
    "peru": "America/Lima",
    "venezuela": "America/Caracas",
    "cuba": "America/Havana",
    "jamaica": "America/Jamaica",
    "puerto rico": "America/Puerto_Rico",
    "usa": ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles"],
    "us": ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles"],
    "united states": ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles"],
    "america": ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles"],
    "canada": ["America/Toronto", "America/Winnipeg", "America/Edmonton", "America/Vancouver"],
    "australia": ["Australia/Sydney", "Australia/Brisbane", "Australia/Adelaide", "Australia/Perth"],
    "brazil": ["America/Sao_Paulo", "America/Manaus"],
    "mexico": ["America/Mexico_City", "America/Tijuana", "America/Cancun"],
    "russia": ["Europe/Moscow", "Asia/Yekaterinburg", "Asia/Novosibirsk", "Asia/Vladivostok"],
    "indonesia": ["Asia/Jakarta", "Asia/Makassar", "Asia/Jayapura"],
    "alabama": "America/Chicago",
    "alaska": "America/Anchorage",
    "arizona": "America/Phoenix",
    "arkansas": "America/Chicago",
    "california": "America/Los_Angeles",
    "colorado": "America/Denver",
    "connecticut": "America/New_York",
    "delaware": "America/New_York",
    "florida": "America/New_York",
    "hawaii": "Pacific/Honolulu",
    "idaho": "America/Boise",
    "illinois": "America/Chicago",
    "indiana": "America/Indiana/Indianapolis",
    "iowa": "America/Chicago",
    "kansas": "America/Chicago",
    "kentucky": "America/New_York",
    "louisiana": "America/Chicago",
    "maine": "America/New_York",
    "maryland": "America/New_York",
    "massachusetts": "America/New_York",
    "michigan": "America/Detroit",
    "minnesota": "America/Chicago",
    "mississippi": "America/Chicago",
    "missouri": "America/Chicago",
    "montana": "America/Denver",
    "nebraska": "America/Chicago",
    "nevada": "America/Los_Angeles",
    "new hampshire": "America/New_York",
    "new jersey": "America/New_York",
    "new mexico": "America/Denver",
    "new york state": "America/New_York",
    "north carolina": "America/New_York",
    "north dakota": "America/Chicago",
    "ohio": "America/New_York",
    "oklahoma": "America/Chicago",
    "oregon": "America/Los_Angeles",
    "pennsylvania": "America/New_York",
    "rhode island": "America/New_York",
    "south carolina": "America/New_York",
    "south dakota": "America/Chicago",
    "tennessee": "America/Chicago",
    "texas": "America/Chicago",
    "utah": "America/Denver",
    "vermont": "America/New_York",
    "virginia": "America/New_York",
    "washington state": "America/Los_Angeles",
    "west virginia": "America/New_York",
    "wisconsin": "America/Chicago",
    "wyoming": "America/Denver",
    "washington dc": "America/New_York",
    "dc": "America/New_York",
    "ontario": "America/Toronto",
    "quebec": "America/Toronto",
    "british columbia": "America/Vancouver",
    "alberta": "America/Edmonton",
    "manitoba": "America/Winnipeg",
    "saskatchewan": "America/Regina",
    "nova scotia": "America/Halifax",
    "newfoundland": "America/St_Johns",
    "new south wales": "Australia/Sydney",
    "queensland": "Australia/Brisbane",
    "western australia": "Australia/Perth",
    "south australia": "Australia/Adelaide",
    "tasmania": "Australia/Hobart"
};

var ZONE_CHOICES = {
    "ist": [["Asia/Kolkata", ["Asia/Kolkata", "Asia/Calcutta"]], ["Europe/Dublin", ["Europe/Dublin"]], ["Asia/Jerusalem", ["Asia/Jerusalem", "Asia/Tel_Aviv"]]],
    "cst": [["America/Chicago", ["America/"]], ["Asia/Shanghai", ["Asia/Shanghai", "Asia/Chongqing", "Asia/Urumqi", "Asia/Macau", "Asia/Hong_Kong", "Asia/Taipei"]], ["America/Havana", ["America/Havana"]]],
    "cdt": [["America/Chicago", ["America/"]], ["America/Havana", ["America/Havana"]]],
    "bst": [["Europe/London", ["Europe/", "Atlantic/"]], ["Asia/Dhaka", ["Asia/Dhaka"]]],
    "ast": [["America/Halifax", ["America/"]], ["Asia/Riyadh", ["Asia/Riyadh", "Asia/Baghdad", "Asia/Kuwait", "Asia/Qatar", "Asia/Bahrain", "Asia/Aden"]]],
    "est": [["America/New_York", ["America/"]], ["Australia/Sydney", ["Australia/"]]],
    "georgia": [["America/New_York", ["America/"]], ["Asia/Tbilisi", ["Asia/Tbilisi", "Europe/", "Asia/"]]]
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

var ZONE_TIME = "(\\d{1,2}(?:[:.]\\d{2})?\\s*(?:am|pm)?|noon|midnight)";
var ZONE_NOT_MERIDIEM = "(?!(?:am|pm|a\\.m\\.|p\\.m\\.)(?: |$))";
var ZONE_BETWEEN = new RegExp(`^${ZONE_TIME} ${ZONE_NOT_MERIDIEM}(?:in )?(.+?) (?:in|to|->|→) (.+)$`);
var ZONE_TO = new RegExp(`^${ZONE_TIME} ${ZONE_NOT_MERIDIEM}(?:in|to) (.+)$`);
var ZONE_AT = new RegExp(`^${ZONE_TIME} ${ZONE_NOT_MERIDIEM}(.+?)(?: time)?$`);

function zoneConvertAsk(text) {
    const t = String(text || "").trim().toLowerCase().replace(/\s+/g, " ");
    let m = ZONE_BETWEEN.exec(t);
    let from = "", to = "";
    if (m) {
        from = m[2];
        to = m[3];
    } else if ((m = ZONE_TO.exec(t))) {
        to = m[2];
    } else if ((m = ZONE_AT.exec(t))) {
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
    if (!clock || from === to || (from && from.length < 2) || (to && to.length < 2) || from === "in" || from === "to" || from === "time")
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

var ZONE_ASK = /^(?:what(?:'s|s|\s+is)\s+the\s+(?:current\s+|local\s+)?|what\s+|(?:the\s+)?(?:current|local)\s+)?(?:time|clock)\s+(?:is\s+it\s+)?(?:(?:right\s+)?now\s+)?in\s+(.+?)(?:\s+(?:right\s+)?now)?\??$/;
var ZONE_LOOSE_AFTER = /^time\s+(?!in$)(?!(?:out|zone|zones|machine|lapse|line|travel|sheet|tracker|tracking|table|off|left|limit|signature|stamp|stamps|to|is|for|of|and|at|on|in|now)(?:\s|$))(.+)$/;
var ZONE_LOOSE_BEFORE = /^(?!(?:current|local|lunch|bed|bedtime|prime|epoch|dinner|break|screen|run|real|play|free|over|part|full|tea|game|show|story|bath|nap|quality|spare|server|compile|load|response|boot|wake|what|same|next|last|first|this|every|any|some|long|short|a|the|my|your|our|unix|system|set|change)(?:\s|$))(.+?)\s+time(?:\s+now)?$/;

function zoneAsk(text) {
    const t = String(text || "").trim().toLowerCase();
    const m = ZONE_ASK.exec(t) || ZONE_LOOSE_AFTER.exec(t) || ZONE_LOOSE_BEFORE.exec(t);
    const place = m ? m[1].trim() : "";
    return place.length >= 2 ? place : "";
}

function zoneChoices(want, localZone) {
    const choices = ZONE_CHOICES[want];
    if (!choices)
        return null;
    const local = String(localZone || "");
    const fit = homes => homes.indexOf(local) >= 0 ? 2 : homes.some(h => h[h.length - 1] === "/" && local.indexOf(h) === 0) ? 1 : 0;
    return choices.map((c, i) => ({
                id: c[0],
                fit: fit(c[1]),
                i: i
            })).sort((a, b) => b.fit - a.fit || a.i - b.i).map(c => c.id);
}

function namedZones(place, localZone) {
    const want = String(place || "").toLowerCase().trim().replace(/\s+/g, " ").replace(/^the /, "");
    const named = zoneChoices(want, localZone) || ZONE_REGIONS[want] || ZONE_ALIASES[want] || ZONE_ABBREVIATIONS[want];
    return !named ? [] : typeof named === "string" ? [named] : named;
}

function placeLabel(place, zone, cityOf) {
    const want = String(place || "").toLowerCase().trim().replace(/\s+/g, " ").replace(/^the /, "");
    if (ZONE_CHOICES[want])
        return cityOf(zone);
    if (ZONE_ABBREVIATIONS[want])
        return want.toUpperCase();
    if (typeof ZONE_REGIONS[want] === "string")
        return want.length <= 3 ? want.toUpperCase() : want.split(" ").map(w => w.length <= 2 ? w.toUpperCase() : w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
    return cityOf(zone);
}

function zoneMatches(zones, place, cityOf, localZone) {
    const want = String(place || "").toLowerCase();
    const named = namedZones(want, localZone).filter(id => !(zones || []).length || zones.indexOf(id) >= 0);
    if (named.length)
        return named;
    const rank = id => {
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

var PORT_ASKS = [/^(kill|free|close|stop|quit|force\s+quit|free\s+up)\s+(?:(?:the\s+)?(?:process|processes|thing|app|server|program|whatever|anything|everything|whatever's)\s+(?:is\s+|that's\s+|that\s+is\s+)?(?:on|using|at|listening\s+on|running\s+on)\s+)?(?:the\s+)?port\s*:?\s*(\d{1,5})$/i, /^((?:what|who|which|what\s+(?:process|app|program)|which\s+(?:process|app|program))(?:'s|\s+is)?)\s+(?:using|on|listening\s+on|running\s+on|holding|bound\s+to|occupying|blocking)\s+(?:the\s+)?port\s*:?\s*(\d{1,5})\??$/i, /^(whats|what's)\s+(?:using|on|listening\s+on|running\s+on)\s+(?:the\s+)?port\s+:?(\d{1,5})\??$/i, /^(is\s+)?port\s+:?(\d{1,5})\s+(?:in\s+use|free|taken|busy|open|used)\??$/i, /^(port|lsof\s+-i\s*:?|who\s+uses\s+port)\s*:?(\d{1,5})$/i];

function portAsk(text) {
    const t = String(text || "").trim();
    for (const pattern of PORT_ASKS) {
        const m = pattern.exec(t);
        const port = m ? parseInt(m[2], 10) : 0;
        if (port >= 1 && port <= 65535)
            return {
                port: port,
                kill: /^(?:kill|free|close|stop|quit|force)/i.test(m[1])
            };
    }
    return null;
}

function killAsk(text) {
    const m = /^(?:kill|force\s+quit)(?:\s+(.*))?$/i.exec(String(text || "").trim());
    return m && !portAsk(text) ? (m[1] || "").trim().toLowerCase() : null;
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

var TOKENISH = /(?:^|\s)(?:eyJ[\w-]{8,}\.[\w-]{8,}|(?=[A-Za-z0-9+\/=_.-]*\d)(?=[A-Za-z0-9+\/=_.-]*[A-Za-z])[A-Za-z0-9+\/=_.-]{32,})(?:\s|$)/;

function looksLikeSecret(text) {
    return TOKENISH.test(String(text || ""));
}

function fallbackRows(chosen, text, webTemplate) {
    return FALLBACKS.filter(f => chosen && chosen[f.id] && (f.id === "terminal" || !looksLikeSecret(text))).map((f, i) => ({
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

var LUA_COMMENTS = /--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*/g;

function luaLayouts(texts) {
    const out = [];
    const find = /hl\.layout\.register\(\s*["']([^"']+)["']/g;
    for (const text of texts || []) {
        const code = String(text).replace(LUA_COMMENTS, "");
        let m;
        while ((m = find.exec(code)) !== null)
            if (out.indexOf(`lua:${m[1]}`) < 0)
                out.push(`lua:${m[1]}`);
    }
    return out;
}

var DIRECTIONS = ["left", "right", "up", "down"];

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
        head: "volume ",
        picks: ["25", "50", "75", "100"]
    },
    {
        head: "set volume to ",
        picks: ["25", "50", "75", "100"]
    },
    {
        head: "kill ",
        picks: "processes"
    },
    {
        head: "force quit ",
        picks: "processes"
    },
    {
        head: "swap ",
        picks: DIRECTIONS
    },
    {
        head: "focus ",
        picks: DIRECTIONS
    },
    {
        head: "move window ",
        picks: DIRECTIONS.concat(["to workspace "])
    },
    {
        head: "move window to workspace ",
        picks: "workspaces"
    },
    {
        head: "send to workspace ",
        picks: "workspaces"
    },
    {
        head: "move to ",
        picks: ["next display", "previous display", "next workspace", "previous workspace"]
    },
    {
        head: "go to workspace ",
        picks: "workspaces"
    },
    {
        head: "workspace ",
        picks: "workspaces"
    },
    {
        head: "timer for ",
        picks: ["5m", "10m", "25m", "1h"]
    },
    {
        head: "remind me at ",
        picks: ["9:00 to ", "12:00 to ", "15:00 to ", "18:00 to "]
    },
    {
        head: "awake ",
        picks: ["30m", "1h", "2h"]
    },
    {
        head: "coffee ",
        picks: ["30m", "1h", "2h"]
    },
    {
        head: "what time is it in ",
        picks: "places"
    },
    {
        head: "noon in ",
        picks: "places"
    },
    {
        head: "midnight in ",
        picks: "places"
    },
    {
        head: "week of ",
        picks: ["christmas", "new year", "easter", "1 jan"]
    },
    {
        head: "what week is ",
        picks: ["christmas", "new year", "easter", "1 jan"]
    },
    {
        head: "weeks since ",
        picks: ["christmas", "1 jan", "easter"]
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
        } else if (p.head.indexOf(t) === 0 && picks.length && out.indexOf(p.head) < 0) {
            out.push(p.head);
        }
    }
    return out;
}
