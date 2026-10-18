.pragma library

var HEAD = /^(?:(?:recently used|recent)(?:\s+(?:documents?|docs?|files?))?(?:\s+(.*))?|(?:documents?|docs)\s+(.+))$/i;
var LATEST_SHELVES = /^(?:downloads?|screenshots?)(?![a-z])/;
var AMBIENT_SCALE = 0.1;
var KEEP = 300;

function ask(text) {
    var m = HEAD.exec(String(text || "").trim());
    if (!m)
        return null;
    var words = String(m[1] || m[2] || "").trim().toLowerCase();
    if (LATEST_SHELVES.test(words))
        return null;
    return { words: words };
}

function unescapeXml(text) {
    return String(text)
        .replace(/&#x([0-9a-f]+);/gi, function (all, hex) {
            return String.fromCharCode(parseInt(hex, 16));
        })
        .replace(/&#(\d+);/g, function (all, dec) {
            return String.fromCharCode(parseInt(dec, 10));
        })
        .replace(/&lt;/g, "<")
        .replace(/&gt;/g, ">")
        .replace(/&quot;/g, "\"")
        .replace(/&apos;/g, "'")
        .replace(/&amp;/g, "&");
}

function attribute(text, name) {
    var m = new RegExp("(?:^|\\s)" + name + "=\"([^\"]*)\"").exec(text);
    return m ? unescapeXml(m[1]) : "";
}

function pathOf(href) {
    if (href.indexOf("file:///") !== 0)
        return "";
    try {
        return decodeURIComponent(href.slice(7));
    } catch (e) {
        return "";
    }
}

function readBookmarks(text, isSecret) {
    var found = {};
    var source = String(text || "");
    var pattern = /<bookmark\s([^>]*)>([\s\S]*?)<\/bookmark>/g;
    var m = pattern.exec(source);
    while (m) {
        var path = pathOf(attribute(m[1], "href"));
        var name = path.slice(path.lastIndexOf("/") + 1);
        if (path && name && name.charAt(0) !== "." && !isSecret(path)) {
            var when = Date.parse(attribute(m[1], "visited") || attribute(m[1], "modified") || attribute(m[1], "added")) || 0;
            var app = /<bookmark:application\s[^>]*?name="([^"]*)"/.exec(m[2]);
            var mime = /<mime:mime-type\s+type="([^"]*)"/.exec(m[2]);
            if (!found[path] || found[path].visited < when)
                found[path] = {
                    path: path,
                    name: name,
                    dir: path.slice(0, path.lastIndexOf("/")),
                    visited: when,
                    app: app ? unescapeXml(app[1]) : "",
                    mime: mime ? mime[1] : ""
                };
        }
        m = pattern.exec(source);
    }
    return Object.keys(found).map(function (p) {
        return found[p];
    }).sort(function (a, b) {
        return b.visited - a.visited;
    }).slice(0, KEEP);
}

function existing(documents, listing) {
    var present = {};
    var lines = String(listing || "").split("\n");
    for (var i = 0; i < lines.length; i++)
        if (lines[i])
            present[lines[i]] = true;
    return documents.filter(function (d) {
        return present[d.path] === true;
    });
}

function matching(documents, words, limit) {
    var want = String(words || "").toLowerCase().split(/\s+/).filter(function (t) {
        return t.length > 0;
    });
    var out = [];
    for (var i = 0; i < documents.length && out.length < limit; i++) {
        var hay = documents[i].path.toLowerCase();
        var all = true;
        for (var t = 0; t < want.length && all; t++)
            all = hay.indexOf(want[t]) >= 0;
        if (all)
            out.push(documents[i]);
    }
    return out;
}

function ambient(documents, text, place, limit) {
    var want = String(text || "").trim().toLowerCase();
    if (want.length < 3 || /\s/.test(want))
        return [];
    var out = [];
    for (var i = 0; i < documents.length && out.length < limit; i++) {
        var s = place(documents[i].name, want);
        if (s >= 2)
            out.push({ document: documents[i], score: s * AMBIENT_SCALE });
    }
    return out;
}
