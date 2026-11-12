.pragma library

var DAY = 86400000;

function parseList(text) {
    return String(text || "").split(/[,\n]/).map(function (s) {
        return s.trim().toLowerCase();
    }).filter(function (s) {
        return s !== "";
    });
}

function excluded(app, listText) {
    var cls = String(app || "").toLowerCase();
    if (!cls)
        return false;
    var names = parseList(listText);
    for (var i = 0; i < names.length; i++) {
        if (cls === names[i] || cls.slice(-names[i].length - 1) === "." + names[i])
            return true;
    }
    return false;
}

function stale(entry, now, days) {
    return days > 0 && !entry.pinned && now - entry.recorded > days * DAY;
}

function withoutStale(entries, now, days) {
    if (!(days > 0))
        return entries;
    return entries.filter(function (e) {
        return !stale(e, now, days);
    });
}
