.pragma library

var DOLLAR_QUOTING = ["bash", "zsh"];
var SINGLE_QUOTING = ["sh", "dash", "ash", "ksh", "mksh", "oksh", "loksh", "yash", "posh"];

function isControl(code) {
    return code < 0x20 || code === 0x7f || (code >= 0x80 && code < 0xa0);
}

function units(text) {
    var out = [];
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        if (code >= 0xd800 && code < 0xdc00) {
            var next = i + 1 < text.length ? text.charCodeAt(i + 1) : 0;
            if (next >= 0xdc00 && next < 0xe000) {
                out.push({text: text.slice(i, i + 2), code: 0x10000 + ((code - 0xd800) << 10) + (next - 0xdc00)});
                i++;
                continue;
            }
            return null;
        }
        if (code >= 0xdc00 && code < 0xe000)
            return null;
        out.push({text: text.charAt(i), code: code});
    }
    return out;
}

function hasControl(text) {
    for (var i = 0; i < text.length; i++)
        if (isControl(text.charCodeAt(i)))
            return true;
    return false;
}

function hex(value) {
    return "\\x" + (value < 16 ? "0" : "") + value.toString(16);
}

function utf8Bytes(code) {
    if (code < 0x80)
        return [code];
    if (code < 0x800)
        return [0xc0 | (code >> 6), 0x80 | (code & 0x3f)];
    if (code < 0x10000)
        return [0xe0 | (code >> 12), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f)];
    return [0xf0 | (code >> 18), 0x80 | ((code >> 12) & 0x3f), 0x80 | ((code >> 6) & 0x3f), 0x80 | (code & 0x3f)];
}

function posix(text) {
    return "'" + text.replace(/'/g, "'\\''") + "'";
}

function dollar(text) {
    var pieces = units(text);
    if (pieces === null)
        return null;
    var out = "";
    for (var i = 0; i < pieces.length; i++) {
        var piece = pieces[i];
        if (piece.code === 0)
            return null;
        if (isControl(piece.code) || piece.text === "'" || piece.text === "\\" || piece.text === "!")
            out += utf8Bytes(piece.code).map(hex).join("");
        else
            out += piece.text;
    }
    return "$'" + out + "'";
}

function fish(text) {
    return "'" + text.replace(/[\\']/g, "\\$&") + "'";
}

function forShell(shell, text) {
    if (units(text) === null || text.indexOf("\u0000") >= 0)
        return null;

    var controlled = hasControl(text);

    if (DOLLAR_QUOTING.indexOf(shell) >= 0)
        return controlled ? dollar(text) : posix(text);

    if (controlled)
        return null;

    if (SINGLE_QUOTING.indexOf(shell) >= 0)
        return posix(text);

    if (shell === "fish")
        return fish(text);

    return /['\\!]/.test(text) ? null : "'" + text + "'";
}

function visible(text) {
    var out = "";
    for (var i = 0; i < text.length; i++) {
        var code = text.charCodeAt(i);
        out += isControl(code) ? utf8Bytes(code).map(hex).join("") : text.charAt(i);
    }
    return out;
}
