.pragma library

.import "copy-name.js" as CopyName

var SLOT = /\{([a-z][a-z0-9_-]{0,23})\}/gi;
var MOST_SLOTS = 3;
var SAMPLES = ["cats", "dogs", "birds"];
var HOST = /^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)/i;
var ORIGIN = /^([a-z][a-z0-9+.-]*:\/\/[^\/?#]+)/i;
var LEADING = /^\s+/;
var GAP = /\s/;
var GAPS = /\s+/g;
var WWW = /^www\./i;
var KEYWORD_SCORE = 0.5;

function allSlots(url) {
    var found = [];
    var source = String(url || "");
    SLOT.lastIndex = 0;
    var m;
    while ((m = SLOT.exec(source)) !== null) {
        var name = m[1].toLowerCase();
        if (found.indexOf(name) < 0)
            found.push(name);
    }
    return found;
}

function slots(url) {
    return allSlots(url).slice(0, MOST_SLOTS);
}

function takes(link) {
    return slots(link && link.url).length > 0;
}

function sample(url) {
    return SAMPLES.slice(0, slots(url).length).join(" ");
}

function values(url, typed) {
    var count = slots(url).length;
    var words = String(typed || "").trim();
    var out = [];
    while (out.length < count - 1 && words) {
        var cut = words.search(GAP);
        if (cut < 0)
            break;
        out.push(words.slice(0, cut));
        words = words.slice(cut).replace(LEADING, "");
    }
    if (out.length < count && words)
        out.push(words);
    return out;
}

function missing(url, typed) {
    var names = slots(url);
    return names.length > 1 ? names[values(url, typed).length] || "" : "";
}

function hostOf(url) {
    var m = HOST.exec(String(url || ""));
    return m ? m[1].replace(WWW, "").toLowerCase() : "";
}

function resolve(url, query) {
    var template = String(url || "");
    var names = slots(template);
    if (!names.length)
        return template;
    var typed = String(query || "").trim();
    if (!typed) {
        var origin = ORIGIN.exec(template);
        return origin ? origin[1] + "/" : template.replace(SLOT, "");
    }
    var given = values(template, typed);
    return template.replace(SLOT, function (whole, name) {
        var at = names.indexOf(name.toLowerCase());
        return at < 0 ? whole : encodeURIComponent(given[at] || "");
    });
}

function originOf(url) {
    var m = ORIGIN.exec(String(url || ""));
    return m ? m[1] + "/" : "";
}

function copyOf(list, link) {
    var name = CopyName.next((list || []).map(function (item) {
        return item && item.name;
    }), String(link && link.name || "Link").trim() + " copy");
    var keyword = cleanKeyword(link && link.keyword);
    var next = keyword;
    for (var k = 2; !next || keywordHolder(list, next, -1); k++)
        next = keyword + k;
    return {
        name: name,
        keyword: next,
        url: String(link && link.url || "")
    };
}

function cleanKeyword(text) {
    return String(text || "").trim().replace(GAPS, "").toLowerCase();
}

function match(links, text) {
    var typed = String(text || "").replace(LEADING, "");
    var lowered = typed.toLowerCase();
    var cut = lowered.search(GAP);
    var head = cut < 0 ? lowered : lowered.slice(0, cut);
    var rest = cut < 0 ? "" : typed.slice(cut).trim();
    var exact = [];
    var partial = [];
    if (!head)
        return {
            exact: exact,
            partial: partial
        };
    for (var i = 0; i < (links || []).length; i++) {
        var link = links[i];
        if (!link || !link.url)
            continue;
        var keyword = cleanKeyword(link.keyword);
        var name = String(link.name || "").toLowerCase();
        if (keyword && keyword === head && (rest === "" || takes(link))) {
            exact.push({
                link: link,
                query: rest
            });
            continue;
        }
        if (rest !== "")
            continue;
        var score = head.length < 2 ? 0 : keyword.indexOf(head) === 0 ? 0.45 : name.indexOf(head) === 0 ? 0.4 : head.length >= 3 && (" " + name).indexOf(" " + head) >= 0 ? 0.35 : 0;
        if (score > 0)
            partial.push({
                link: link,
                score: score
            });
    }
    partial.sort(function (a, b) {
        return b.score - a.score || String(a.link.name).localeCompare(String(b.link.name));
    });
    return {
        exact: exact,
        partial: partial
    };
}

function withLink(list, item, at) {
    var out = (list || []).slice();
    if (at >= 0 && at < out.length)
        out[at] = item;
    else
        out.push(item);
    return out;
}

function keywordHolder(list, keyword, at) {
    var want = cleanKeyword(keyword);
    if (!want)
        return null;
    for (var i = 0; i < (list || []).length; i++)
        if (i !== at && list[i] && cleanKeyword(list[i].keyword) === want)
            return list[i];
    return null;
}

function problem(link) {
    if (!String(link && link.name || "").trim())
        return "needs a name";
    if (!cleanKeyword(link.keyword))
        return "needs a keyword";
    if (!HOST.test(String(link.url || "").trim()))
        return "needs a full address like https://…";
    if (allSlots(link.url).length > MOST_SLOTS)
        return "takes at most three arguments";
    return "";
}

function prefixes(links) {
    var out = [];
    var byUrl = {};
    for (var i = 0; i < (links || []).length; i++) {
        var link = links[i];
        var keyword = cleanKeyword(link && link.keyword);
        if (!keyword || problem(link))
            continue;
        var url = String(link.url).trim();
        var same = byUrl[url];
        if (same) {
            if (same.word !== keyword && same.also.indexOf(keyword) < 0) {
                same.also.push(keyword);
                same.label = `${same.label}, ${keyword}`;
            }
            continue;
        }
        var name = String(link.name).trim();
        byUrl[url] = {
            section: "Quicklinks",
            word: keyword,
            label: keyword,
            about: takes(link) ? `Search ${name}` : `Open ${name}`,
            icon: takes(link) ? "travel_explore" : "link",
            also: []
        };
        out.push(byUrl[url]);
    }
    return out;
}
