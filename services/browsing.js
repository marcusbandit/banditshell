.pragma library

var ONLY = /^(bookmarks?|bm|history)(?:\s+(.*))?$/i;
var WORDY = /[a-z0-9]/;
var HOST = /^[a-z][a-z0-9+.\-]*:\/\/(?:[^@\/]*@)?([^\/:?#]+)/i;

function ask(input) {
    var text = String(input || "").trim();
    var hit = ONLY.exec(text);
    if (hit)
        return {
            term: (hit[2] || "").trim().toLowerCase(),
            only: hit[1].toLowerCase() === "history" ? "history" : "bookmarks"
        };
    return {
        term: text.toLowerCase(),
        only: ""
    };
}

function hostOf(url) {
    var hit = HOST.exec(String(url || ""));
    return hit ? hit[1].toLowerCase().replace(/^www\./, "") : "";
}

function prepare(data) {
    var places = data && Array.isArray(data.places) ? data.places : [];
    return places.filter(function (p) {
        return p && p.url;
    }).map(function (p) {
        var host = p.host || hostOf(p.url);
        var title = String(p.title || "").trim() || host || p.url;
        return {
            url: p.url,
            title: title,
            host: host,
            bookmark: !!p.bookmark,
            visits: p.visits || 0,
            last: p.last || 0,
            icon: p.icon || "",
            browser: p.browser || "",
            titleLow: title.toLowerCase(),
            hostLow: host
        };
    });
}

function placeIn(text, want) {
    if (text === want)
        return 4;
    var at = text.indexOf(want);
    if (at < 0)
        return -1;
    if (at === 0)
        return 3;
    while (at > 0) {
        if (!WORDY.test(text.charAt(at - 1)))
            return 2;
        at = text.indexOf(want, at + 1);
    }
    return 1;
}

function match(places, asked, most) {
    var want = asked.term;
    var out = [];
    var seen = {};
    for (var i = 0; i < places.length; i++) {
        var p = places[i];
        if (asked.only === "bookmarks" && !p.bookmark || asked.only === "history" && p.bookmark)
            continue;
        var score;
        if (!want) {
            score = 1;
        } else {
            if (p.titleLow.indexOf(want) < 0 && p.hostLow.indexOf(want) < 0)
                continue;
            score = Math.max(placeIn(p.titleLow, want), placeIn(p.hostLow, want));
            if (!p.bookmark && score < 2 && !asked.only)
                continue;
        }
        var hit = {
            place: p,
            score: score + Math.min(0.9, Math.log(1 + p.visits) / 10)
        };
        var same = (p.bookmark ? "b" : "h") + p.hostLow + "|" + p.titleLow;
        var kept = seen[same];
        if (kept === undefined) {
            seen[same] = out.length;
            out.push(hit);
        } else if (hit.score > out[kept].score) {
            out[kept] = hit;
        }
    }
    out.sort(function (a, b) {
        return b.score - a.score || b.place.last - a.place.last;
    });
    return out.slice(0, most);
}
