.pragma library

var GNOME = "x-special/gnome-copied-files";
var URIS = "text/uri-list";

function uri(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/");
}

function copyCommand(paths, cut) {
    var uris = paths.map(uri);
    if (cut)
        return {argv: ["wl-copy", "-t", GNOME], input: "cut\n" + uris.join("\n")};
    return {argv: ["wl-copy", "-t", URIS], input: uris.join("\r\n")};
}

function typesCommand() {
    return ["wl-paste", "--list-types"];
}

function readCommand(type) {
    return ["wl-paste", "--no-newline", "--type", type];
}

function pick(types) {
    var offered = types.split("\n").map(function (line) {
        return line.trim();
    });
    if (offered.indexOf(GNOME) >= 0)
        return GNOME;
    return offered.indexOf(URIS) >= 0 ? URIS : "";
}

function path(line) {
    if (line.indexOf("file://") !== 0)
        return "";
    var rest = line.slice(7);
    var slash = rest.indexOf("/");
    if (slash < 0 || (slash > 0 && rest.slice(0, slash) !== "localhost"))
        return "";
    try {
        return decodeURIComponent(rest.slice(slash));
    } catch (e) {
        return "";
    }
}

function parse(type, text) {
    var lines = text.split(/\r?\n/).map(function (line) {
        return line.trim();
    });
    var cut = false;
    if (type === GNOME) {
        cut = lines[0] === "cut";
        lines = lines.slice(1);
    }
    var paths = lines.map(path).filter(function (one) {
        return one !== "";
    });
    return {paths: paths, cut: cut};
}

function same(a, b) {
    return a.length === b.length && a.every(function (one, i) {
        return one === b[i];
    });
}
