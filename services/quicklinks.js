.pragma library

var QUERY = /\{query\}/gi;
var HOST = /^[a-z][a-z0-9+.-]*:\/\/([^\/?#]+)/i;
var ORIGIN = /^([a-z][a-z0-9+.-]*:\/\/[^\/?#]+)/i;
var HAS_QUERY = /\{query\}/i;
var LEADING = /^\s+/;
var GAP = /\s/;
var GAPS = /\s+/g;
var WWW = /^www\./i;
var KEYWORD_SCORE = 0.5;

function takes(link) {
    return HAS_QUERY.test(String(link && link.url || ""));
}

function hostOf(url) {
    var m = HOST.exec(String(url || ""));
    return m ? m[1].replace(WWW, "").toLowerCase() : "";
}

function resolve(url, query) {
    var template = String(url || "");
    var typed = String(query || "").trim();
    if (!HAS_QUERY.test(template))
        return template;
    if (!typed) {
        var origin = ORIGIN.exec(template);
        return origin ? origin[1] + "/" : template.replace(QUERY, "");
    }
    return template.replace(QUERY, encodeURIComponent(typed));
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
    return "";
}

function prefixes(links) {
    var out = [];
    for (var i = 0; i < (links || []).length; i++) {
        var link = links[i];
        var keyword = cleanKeyword(link && link.keyword);
        if (!keyword || problem(link))
            continue;
        var name = String(link.name).trim();
        out.push({
            section: "Quicklinks",
            word: keyword,
            about: takes(link) ? `Search ${name}` : `Open ${name}`,
            icon: takes(link) ? "travel_explore" : "link",
            also: []
        });
    }
    return out;
}
