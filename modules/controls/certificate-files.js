.pragma library

var BUNDLES = /\.(p12|pfx)$/i;
var KEYS = /\.key$/i;

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

function read(text) {
    var out = [];
    var records = String(text || "").split("\x1e");
    for (var i = 0; i < records.length; i++) {
        var lines = records[i].split("\n");
        var path = lines[0];
        if (path.charAt(0) !== "/")
            continue;
        var kind = kindOf(path, lines.slice(1));
        if (kind)
            out.push({ path: path, kind: kind, key: holdsKey(path, lines) });
    }
    return out;
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
