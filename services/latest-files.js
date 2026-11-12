.pragma library

var SHELVES = [
    {
        key: "screenshots",
        title: "Screenshots",
        icon: "screenshot_monitor",
        pictures: true,
        ask: /^(?:screenshots|screen shots|recent screenshots?|last screenshot|my screenshots)(?:\s+(.*))?$/i
    },
    {
        key: "downloads",
        title: "Downloads",
        icon: "download",
        pictures: false,
        ask: /^(?:download|(?:downloads|recent downloads?|last download|downloaded)(?:\s+(.*))?)$/i
    }
];

var PARTIAL = /\.(?:part|crdownload|download|partial|tmp|filepart|opdownload|aria2|!qb)$/i;

function ask(text) {
    var t = String(text || "").trim();
    for (var i = 0; i < SHELVES.length; i++) {
        var m = SHELVES[i].ask.exec(t);
        if (m)
            return {
                shelf: SHELVES[i],
                words: String(m[1] || "").trim().toLowerCase()
            };
    }
    return null;
}

function readListing(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t");
        if (parts.length < 3 || !parts[2])
            continue;
        var path = parts.slice(2).join("\t");
        var name = path.slice(path.lastIndexOf("/") + 1);
        if (name.charAt(0) === "." || PARTIAL.test(name))
            continue;
        out.push({
            path: path,
            name: name,
            dir: parts[1] === "d",
            modified: Math.round((Number(parts[0]) || 0) * 1000)
        });
    }
    return out;
}

var MONTHS = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"];
var DAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"];
var LEADERS = "(?:(?:from|on|since|during|taken|made|in)\\s+)?";
var DAY_MS = 86400000;

function dayStart(date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function monthIndex(word) {
    for (var i = 0; i < 12; i++)
        if (MONTHS[i] === word || (word.length === 3 && MONTHS[i].slice(0, 3) === word))
            return i;
    return -1;
}

function dayIndex(word) {
    return DAYS.indexOf(word);
}

function span(from, to) {
    return {
        from: from.getTime(),
        to: to.getTime()
    };
}

function plusDays(date, n) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate() + n);
}

function dateWindow(words, now) {
    var text = " " + String(words || "").toLowerCase().replace(/\s+/g, " ").trim() + " ";
    var today = dayStart(now || new Date());
    var found = null;
    var cut = function (m, window) {
        found = window;
        text = text.slice(0, m.index) + " " + text.slice(m.index + m[0].length);
    };
    var m = new RegExp("\\s" + LEADERS + "(\\d{4})-(\\d{2})-(\\d{2})(?=\\s)").exec(text);
    if (m) {
        var day = new Date(+m[1], +m[2] - 1, +m[3]);
        cut(m, span(day, plusDays(day, 1)));
    } else if ((m = new RegExp("\\s" + LEADERS + "(today|yesterday)(?=\\s)").exec(text))) {
        var back = m[1] === "today" ? 0 : 1;
        cut(m, span(plusDays(today, -back), plusDays(today, 1 - back)));
    } else if ((m = new RegExp("\\s" + LEADERS + "(this|last) (week|month)(?=\\s)").exec(text))) {
        var start = m[2] === "week" ? plusDays(today, -((today.getDay() + 6) % 7)) : new Date(today.getFullYear(), today.getMonth(), 1);
        var length = m[2] === "week" ? function (d, n) {
            return plusDays(d, 7 * n);
        } : function (d, n) {
            return new Date(d.getFullYear(), d.getMonth() + n, 1);
        };
        cut(m, m[1] === "this" ? span(start, length(start, 1)) : span(length(start, -1), start));
    } else if ((m = new RegExp("\\s" + LEADERS + "(?:the )?(?:last|past) (\\d{1,3}) (day|days|week|weeks)(?=\\s)").exec(text))) {
        var n = +m[1] * (m[2].charAt(0) === "w" ? 7 : 1);
        cut(m, span(plusDays(today, 1 - n), plusDays(today, 1)));
    } else if ((m = new RegExp("\\s" + LEADERS + "(?:last |on )?(" + DAYS.join("|") + ")(?=\\s)").exec(text))) {
        var ago = (today.getDay() - dayIndex(m[1]) + 7) % 7;
        cut(m, span(plusDays(today, -ago), plusDays(today, 1 - ago)));
    } else if ((m = new RegExp("\\s" + LEADERS + "([a-z]{3,9}) (\\d{1,2})(?:st|nd|rd|th)?(?=\\s)").exec(text)) && monthIndex(m[1]) >= 0 && +m[2] >= 1 && +m[2] <= 31) {
        var d1 = new Date(today.getFullYear(), monthIndex(m[1]), +m[2]);
        if (d1 > today)
            d1 = new Date(d1.getFullYear() - 1, d1.getMonth(), d1.getDate());
        cut(m, span(d1, plusDays(d1, 1)));
    } else if ((m = new RegExp("\\s" + LEADERS + "(\\d{1,2})(?:st|nd|rd|th)? ([a-z]{3,9})(?=\\s)").exec(text)) && monthIndex(m[2]) >= 0 && +m[1] >= 1 && +m[1] <= 31) {
        var d2 = new Date(today.getFullYear(), monthIndex(m[2]), +m[1]);
        if (d2 > today)
            d2 = new Date(d2.getFullYear() - 1, d2.getMonth(), d2.getDate());
        cut(m, span(d2, plusDays(d2, 1)));
    } else if ((m = new RegExp("\\s" + LEADERS + "(" + MONTHS.filter(function (name) {
        return name !== "may";
    }).join("|") + ")(?=\\s)").exec(text))) {
        var first = new Date(today.getFullYear(), monthIndex(m[1]), 1);
        if (first > today)
            first = new Date(first.getFullYear() - 1, first.getMonth(), 1);
        cut(m, span(first, new Date(first.getFullYear(), first.getMonth() + 1, 1)));
    }
    if (!found)
        return null;
    return {
        from: found.from,
        to: found.to,
        rest: text.trim().replace(/\s+/g, " ")
    };
}

function terms(words) {
    return String(words || "").toLowerCase().split(/\s+/).filter(Boolean);
}

function textOf(texts, file) {
    var got = texts && texts[file.path];
    return got && got.m === file.modified ? got.t : "";
}

function hasRead(texts, file) {
    var got = texts && texts[file.path];
    return !!got && got.m === file.modified;
}

function snippet(text, word) {
    var at = String(text || "").toLowerCase().indexOf(word);
    if (at < 0)
        return "";
    var from = Math.max(0, at - 24);
    var out = text.slice(from, at + word.length + 48).replace(/\s+/g, " ").trim();
    return (from > 0 ? "..." : "") + out;
}

function scope(files, words, now) {
    var range = dateWindow(words, now);
    var inside = range ? files.filter(function (f) {
        return f.modified >= range.from && f.modified < range.to;
    }) : files;
    return {
        files: inside,
        rest: range ? range.rest : String(words || "").trim()
    };
}

function matching(files, words, limit, texts, now) {
    var scoped = scope(files, words, now);
    var wanted = terms(scoped.rest);
    var out = [];
    for (var i = 0; i < scoped.files.length && out.length < limit; i++) {
        var file = scoped.files[i];
        var name = file.name.toLowerCase();
        var body = textOf(texts, file).toLowerCase();
        var hit = wanted.every(function (w) {
            return name.indexOf(w) >= 0 || body.indexOf(w) >= 0;
        });
        if (!hit)
            continue;
        var inText = wanted.filter(function (w) {
            return name.indexOf(w) < 0;
        })[0];
        out.push(inText ? Object.assign({}, file, {
            snippet: snippet(textOf(texts, file), inText)
        }) : file);
    }
    return out;
}

function needText(files, words, texts, now, limit) {
    var scoped = scope(files, words, now);
    var wanted = terms(scoped.rest);
    if (!wanted.length)
        return [];
    return scoped.files.slice(0, limit).filter(function (file) {
        if (file.dir)
            return false;
        var name = file.name.toLowerCase();
        return !hasRead(texts, file) && !wanted.every(function (w) {
            return name.indexOf(w) >= 0;
        });
    });
}
