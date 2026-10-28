.pragma library

var BUNDLES = /\.(p12|pfx)$/i;
var KEYS = /\.key$/i;
var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
var SHARED = ["ac", "co", "com", "edu", "gov", "net", "org"];

function holdsKey(path, lines) {
    return BUNDLES.test(path) || lines.some(function (line) {
        return line.trim() === "private key";
    });
}

function kindOf(path, lines) {
    var key = false;
    var subject = null;
    var issuer = null;
    var authority = null;
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line === "private key")
            key = true;
        else if (line.indexOf("subject=") === 0)
            subject = line.slice(8).trim();
        else if (line.indexOf("issuer=") === 0)
            issuer = line.slice(7).trim();
        else if (/^CA:TRUE\b/.test(line))
            authority = true;
        else if (/^CA:FALSE\b/.test(line))
            authority = false;
    }
    if (BUNDLES.test(path))
        return "client";
    if (subject === null)
        return key || KEYS.test(path) ? "key" : "";
    if (key)
        return "client";
    if (authority === null)
        authority = subject === issuer;
    return authority ? "authority" : "client";
}

function field(lines, name) {
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.indexOf(name + "=") === 0)
            return line.slice(name.length + 1).trim();
    }
    return "";
}

function endOf(text) {
    var m = /^([A-Z][a-z]{2})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})\s+GMT$/.exec(String(text || "").trim());
    if (!m || MONTHS.indexOf(m[1]) < 0)
        return 0;
    return Date.UTC(Number(m[6]), MONTHS.indexOf(m[1]), Number(m[2]), Number(m[3]), Number(m[4]), Number(m[5]));
}

function nameOf(dn) {
    var found = {};
    var part = /(?:^|,)\s*(O|CN)\s*=\s*([^,]*)/g;
    var m;
    while ((m = part.exec(String(dn || ""))) !== null)
        found[m[1]] = m[2].trim();
    return found.O || found.CN || "";
}

function read(text) {
    var out = [];
    var records = String(text || "").split("\x1e");
    for (var i = 0; i < records.length; i++) {
        var lines = records[i].split("\n");
        var path = lines[0];
        if (path.charAt(0) !== "/")
            continue;
        var rest = lines.slice(1);
        var kind = kindOf(path, rest);
        if (kind)
            out.push({ path: path, kind: kind, key: holdsKey(path, lines), subject: field(rest, "subject"), issuer: field(rest, "issuer"), until: endOf(field(rest, "notAfter")) });
    }
    return out;
}

function schoolLabel(server) {
    var parts = String(server || "").trim().toLowerCase().split(".").filter(function (p) {
        return p;
    });
    if (parts.length < 2)
        return "";
    var label = parts[parts.length - 2];
    if (SHARED.indexOf(label) >= 0 && parts.length >= 3)
        label = parts[parts.length - 3];
    return label.length >= 2 ? label : "";
}

function fits(file, server) {
    var label = schoolLabel(server);
    if (!label)
        return false;
    var words = (file.subject + " " + file.issuer).toLowerCase().split(/[^a-z0-9]+/);
    return words.indexOf(label) >= 0;
}

function monthOf(ms) {
    var d = new Date(ms);
    return MONTHS[d.getUTCMonth()] + " " + d.getUTCFullYear();
}

function roots(files, server, now, most) {
    var host = String(server || "").trim().toLowerCase();
    var out = [];
    for (var i = 0; i < files.length; i++) {
        var f = files[i];
        if (f.kind !== "authority")
            continue;
        var expired = f.until > 0 && f.until <= now;
        var match = fits(f, host);
        var parts = [nameOf(f.issuer) || nameOf(f.subject)];
        if (f.until > 0)
            parts.push((expired ? "expired " : "until ") + monthOf(f.until));
        if (match)
            parts.push("matches " + host);
        out.push({ path: f.path, detail: parts.filter(function (p) {
            return p;
        }).join(" · "), warn: expired, rank: (match ? 0 : 1) + (expired ? 2 : 0), order: out.length });
    }
    out.sort(function (a, b) {
        return a.rank - b.rank || a.order - b.order;
    });
    return out.slice(0, most).map(function (r) {
        return { path: r.path, detail: r.detail, warn: r.warn };
    });
}

function carriesKey(files, path) {
    for (var i = 0; i < files.length; i++) {
        if (files[i].path === path)
            return files[i].key;
    }
    return BUNDLES.test(path);
}

function needsKey(files, path) {
    for (var i = 0; i < files.length; i++) {
        if (files[i].path === path)
            return files[i].kind === "client" && !files[i].key;
    }
    return false;
}

function fitting(files, kind, most) {
    var out = [];
    for (var i = 0; i < files.length && out.length < most; i++) {
        if (files[i].kind === kind)
            out.push(files[i].path);
    }
    return out;
}
