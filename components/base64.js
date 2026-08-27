// Base64, in JavaScript, because the bytes on the wire are not text.
//
// The pty helper frames every payload as base64 on one line (see src/bs-pty.c
// for why), so both ends need a codec. QML has Qt.atob and Qt.btoa, and they are
// not usable here: they hand back a QString, which means the decoded bytes have
// been run through a text codec on the way, and a terminal stream is full of
// bytes that are not valid UTF-8 on their own - the second byte of any accented
// character, every C1 control, the middle of any escape sequence that got split
// across two reads. Anything that does not survive that trip comes out as a
// replacement character, and a replacement character in an escape sequence is a
// sequence that no longer parses.
//
// So it is done by hand, over a string in which one character IS one byte, which
// is the representation components/vt.js consumes and produces.

var ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

var LOOKUP = (function () {
    var t = {};
    for (var i = 0; i < ALPHABET.length; i++)
        t[ALPHABET.charAt(i)] = i;
    return t;
})();

// Base64 in, one-char-per-byte string out.
function decode(text) {
    var out = "";
    var acc = 0;
    var bits = 0;

    for (var i = 0; i < text.length; i++) {
        var v = LOOKUP[text.charAt(i)];
        // Padding and anything else that is not in the alphabet. Skipped rather
        // than refused: a frame with a stray character in it still carries its
        // payload, and refusing would throw away a screenful of output over one
        // byte.
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

// One-char-per-byte string in, base64 out.
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

// A JavaScript string, as the UTF-8 BYTES that a terminal expects.
//
// Everything above deals in bytes; a keystroke arrives from Qt as text, and "ö"
// is one character there and two bytes on the wire. Without this, typing a
// non-ASCII character sends its code point as a single byte and the shell
// receives something else entirely.
function utf8(text) {
    var out = "";

    for (var i = 0; i < text.length; i++) {
        var cp = text.charCodeAt(i);

        // A surrogate pair is one code point written as two units.
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
