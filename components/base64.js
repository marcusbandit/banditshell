var ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

var LOOKUP = (function () {
    var t = {};
    for (var i = 0; i < ALPHABET.length; i++)
        t[ALPHABET.charAt(i)] = i;
    return t;
})();

function decode(text) {
    var out = "";
    var acc = 0;
    var bits = 0;

    for (var i = 0; i < text.length; i++) {
        var v = LOOKUP[text.charAt(i)];

        if (v === undefined)
            continue;
        acc = acc << 6 | v;
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out += String.fromCharCode(acc >> bits & 0xff);
        }
    }

    return out;
}

function encode(bytes) {
    var out = "";
    var i = 0;

    for (; i + 2 < bytes.length; i += 3) {
        var v = bytes.charCodeAt(i) << 16 | bytes.charCodeAt(i + 1) << 8 | bytes.charCodeAt(i + 2);
        out += ALPHABET.charAt(v >> 18 & 63) + ALPHABET.charAt(v >> 12 & 63)
            + ALPHABET.charAt(v >> 6 & 63) + ALPHABET.charAt(v & 63);
    }

    if (i < bytes.length) {
        var tail = bytes.charCodeAt(i) << 16 | (i + 1 < bytes.length ? bytes.charCodeAt(i + 1) << 8 : 0);
        out += ALPHABET.charAt(tail >> 18 & 63) + ALPHABET.charAt(tail >> 12 & 63)
            + (i + 1 < bytes.length ? ALPHABET.charAt(tail >> 6 & 63) : "=") + "=";
    }

    return out;
}

function utf8(text) {
    var out = "";

    for (var i = 0; i < text.length; i++) {
        var cp = text.charCodeAt(i);

        if (cp >= 0xd800 && cp <= 0xdbff && i + 1 < text.length) {
            var low = text.charCodeAt(i + 1);
            if (low >= 0xdc00 && low <= 0xdfff) {
                cp = 0x10000 + ((cp - 0xd800) << 10) + (low - 0xdc00);
                i++;
            }
        }

        if (cp < 0x80) {
            out += String.fromCharCode(cp);
        } else if (cp < 0x800) {
            out += String.fromCharCode(0xc0 | cp >> 6, 0x80 | cp & 0x3f);
        } else if (cp < 0x10000) {
            out += String.fromCharCode(0xe0 | cp >> 12, 0x80 | cp >> 6 & 0x3f, 0x80 | cp & 0x3f);
        } else {
            out += String.fromCharCode(0xf0 | cp >> 18, 0x80 | cp >> 12 & 0x3f,
                0x80 | cp >> 6 & 0x3f, 0x80 | cp & 0x3f);
        }
    }

    return out;
}
