.pragma library

var HINT = "x-kde-passwordManagerHint";
var MASK = "••••••••••••";
var KEY_BLOCK = /^-----BEGIN [A-Z0-9 ]*PRIVATE KEY( BLOCK)?-----/;
var TOKEN = /^(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_\w{20,}|glpat-[\w-]{20,}|sk-[\w-]{20,}|sk_(live|test)_\w{16,}|xox[abprs]-[\w-]{10,}|AKIA[0-9A-Z]{16}|AIza[\w-]{30,}|eyJ[\w-]+\.eyJ[\w-]+\.[\w-]+)$/;
var ADDRESS = /^[a-z][a-z0-9+.-]*:\/\/|^[~\/.]|^[^@\s]+@[^@\s]+\.[a-z]{2,}$/i;
var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function marked(types) {
    return (types || []).indexOf(HINT) >= 0;
}

function kind(c) {
    if (c >= "A" && c <= "Z")
        return 0;
    if (c >= "a" && c <= "z")
        return 1;
    if (c >= "0" && c <= "9")
        return 2;
    return 3;
}

function looksSecret(text) {
    var raw = String(text || "");
    if (KEY_BLOCK.test(raw.slice(0, 80).replace(/^\s+/, "")))
        return true;
    if (raw.length > 160)
        return false;
    var s = raw.trim();
    if (s.length < 10 || s.length > 128 || /\s/.test(s))
        return false;
    if (TOKEN.test(s))
        return true;
    if (ADDRESS.test(s) || UUID.test(s))
        return false;
    var counts = [0, 0, 0, 0];
    var flips = 0;
    for (var i = 0; i < s.length; i++) {
        var k = kind(s[i]);
        counts[k]++;
        if (i > 0 && k !== kind(s[i - 1]))
            flips++;
    }
    if (counts[0] < 2 || counts[1] < 2 || counts[2] + counts[3] < 2)
        return false;
    return flips / (s.length - 1) >= 0.4;
}

function sensitive(entry) {
    if (!entry || entry.file || (entry.paths || []).length)
        return false;
    return marked(entry.types) || looksSecret(entry.text);
}

function copyCommand(entry, sensitiveCopy) {
    return sensitiveCopy && sensitive(entry) ? ["wl-copy", "--sensitive", "-n"] : ["wl-copy", "-n"];
}
