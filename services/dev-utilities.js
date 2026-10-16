.pragma library

var HEX = "0123456789abcdef";

var BASE64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

var BASE64_VALUES = (function () {
    var table = {};
    for (var i = 0; i < BASE64.length; i++)
        table[BASE64.charAt(i)] = i;
    table["-"] = 62;
    table["_"] = 63;
    return table;
})();

function utf8Bytes(text) {
    var out = [];
    var source = String(text);
    for (var i = 0; i < source.length; i++) {
        var point = source.codePointAt(i);
        if (point > 0xffff)
            i++;
        else if (point >= 0xd800 && point <= 0xdfff)
            point = 0xfffd;
        if (point < 0x80)
            out.push(point);
        else if (point < 0x800)
            out.push(0xc0 | point >> 6, 0x80 | point & 63);
        else if (point < 0x10000)
            out.push(0xe0 | point >> 12, 0x80 | point >> 6 & 63, 0x80 | point & 63);
        else
            out.push(0xf0 | point >> 18, 0x80 | point >> 12 & 63, 0x80 | point >> 6 & 63, 0x80 | point & 63);
    }
    return out;
}

function utf8Text(bytes) {
    var out = "";
    var i = 0;
    while (i < bytes.length) {
        var first = bytes[i];
        var extra = first < 0x80 ? 0 : first >= 0xc2 && first < 0xe0 ? 1 : first >= 0xe0 && first < 0xf0 ? 2 : first >= 0xf0 && first < 0xf5 ? 3 : -1;
        if (extra < 0 || i + extra >= bytes.length + (extra ? 0 : 1))
            return null;
        var point = extra === 0 ? first : first & (0x3f >> extra);
        for (var k = 1; k <= extra; k++) {
            var next = bytes[i + k];
            if (next === undefined || (next & 0xc0) !== 0x80)
                return null;
            point = point << 6 | next & 63;
        }
        if (extra === 2 && (point < 0x800 || point >= 0xd800 && point <= 0xdfff) || extra === 3 && (point < 0x10000 || point > 0x10ffff))
            return null;
        out += String.fromCodePoint(point);
        i += extra + 1;
    }
    return out;
}

function hexOf(bytes) {
    var out = "";
    for (var i = 0; i < bytes.length; i++)
        out += HEX.charAt(bytes[i] >> 4) + HEX.charAt(bytes[i] & 15);
    return out;
}

function base64Encode(bytes) {
    var out = "";
    var i = 0;
    for (; i + 2 < bytes.length; i += 3) {
        var group = bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
        out += BASE64.charAt(group >> 18 & 63) + BASE64.charAt(group >> 12 & 63) + BASE64.charAt(group >> 6 & 63) + BASE64.charAt(group & 63);
    }
    if (i < bytes.length) {
        var tail = bytes[i] << 16 | (i + 1 < bytes.length ? bytes[i + 1] << 8 : 0);
        out += BASE64.charAt(tail >> 18 & 63) + BASE64.charAt(tail >> 12 & 63) + (i + 1 < bytes.length ? BASE64.charAt(tail >> 6 & 63) : "=") + "=";
    }
    return out;
}

var BASE64_SHAPE = /^[A-Za-z0-9+/_-]*={0,2}$/;

function base64Decode(text) {
    var clean = String(text).replace(/\s+/g, "");
    if (!BASE64_SHAPE.test(clean))
        return null;
    var body = clean.replace(/=+$/, "");
    if (body.length % 4 === 1 || clean.length > body.length && clean.length % 4 !== 0)
        return null;
    var out = [];
    var gathered = 0;
    var bits = 0;
    for (var i = 0; i < body.length; i++) {
        gathered = gathered << 6 | BASE64_VALUES[body.charAt(i)];
        bits += 6;
        if (bits >= 8) {
            bits -= 8;
            out.push(gathered >> bits & 0xff);
        }
    }
    return out;
}

function printable(text) {
    return text !== null && !/[\u0000-\u0008\u000e-\u001f\u007f]/.test(text);
}

function blocks(bytes, bigEndian) {
    var length = bytes.length;
    var count = ((length + 8) >> 6) + 1;
    var words = [];
    for (var w = 0; w < count * 16; w++)
        words.push(0);
    var place = i => bigEndian ? 24 - (i & 3) * 8 : (i & 3) * 8;
    for (var i = 0; i < length; i++)
        words[i >> 2] |= bytes[i] << place(i);
    words[length >> 2] |= 0x80 << place(length);
    var low = length * 8 % 4294967296;
    var high = Math.floor(length * 8 / 4294967296);
    words[count * 16 - 2] = bigEndian ? high : low;
    words[count * 16 - 1] = bigEndian ? low : high;
    return words;
}

function wordsHex(words, bigEndian) {
    var out = "";
    for (var i = 0; i < words.length; i++) {
        var word = words[i] >>> 0;
        for (var k = 0; k < 4; k++) {
            var shift = bigEndian ? 24 - k * 8 : k * 8;
            var value = word >>> shift & 0xff;
            out += HEX.charAt(value >> 4) + HEX.charAt(value & 15);
        }
    }
    return out;
}

var SHA256_ROUNDS = [0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2];

function sha256(bytes) {
    var words = blocks(bytes, true);
    var state = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19];
    var schedule = [];
    for (var block = 0; block < words.length; block += 16) {
        for (var t = 0; t < 64; t++) {
            if (t < 16) {
                schedule[t] = words[block + t];
            } else {
                var x = schedule[t - 15];
                var y = schedule[t - 2];
                var sigma0 = (x >>> 7 | x << 25) ^ (x >>> 18 | x << 14) ^ x >>> 3;
                var sigma1 = (y >>> 17 | y << 15) ^ (y >>> 19 | y << 13) ^ y >>> 10;
                schedule[t] = schedule[t - 16] + sigma0 + schedule[t - 7] + sigma1 | 0;
            }
        }
        var a = state[0], b = state[1], c = state[2], d = state[3], e = state[4], f = state[5], g = state[6], h = state[7];
        for (t = 0; t < 64; t++) {
            var sum1 = (e >>> 6 | e << 26) ^ (e >>> 11 | e << 21) ^ (e >>> 25 | e << 7);
            var choose = e & f ^ ~e & g;
            var first = h + sum1 + choose + SHA256_ROUNDS[t] + schedule[t] | 0;
            var sum0 = (a >>> 2 | a << 30) ^ (a >>> 13 | a << 19) ^ (a >>> 22 | a << 10);
            var majority = a & b ^ a & c ^ b & c;
            var second = sum0 + majority | 0;
            h = g;
            g = f;
            f = e;
            e = d + first | 0;
            d = c;
            c = b;
            b = a;
            a = first + second | 0;
        }
        state = [state[0] + a | 0, state[1] + b | 0, state[2] + c | 0, state[3] + d | 0, state[4] + e | 0, state[5] + f | 0, state[6] + g | 0, state[7] + h | 0];
    }
    return wordsHex(state, true);
}

function sha1(bytes) {
    var words = blocks(bytes, true);
    var state = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476, 0xc3d2e1f0];
    var schedule = [];
    for (var block = 0; block < words.length; block += 16) {
        for (var t = 0; t < 80; t++) {
            if (t < 16) {
                schedule[t] = words[block + t];
            } else {
                var x = schedule[t - 3] ^ schedule[t - 8] ^ schedule[t - 14] ^ schedule[t - 16];
                schedule[t] = x << 1 | x >>> 31;
            }
        }
        var a = state[0], b = state[1], c = state[2], d = state[3], e = state[4];
        for (t = 0; t < 80; t++) {
            var mix = t < 20 ? b & c | ~b & d : t < 40 ? b ^ c ^ d : t < 60 ? b & c | b & d | c & d : b ^ c ^ d;
            var constant = t < 20 ? 0x5a827999 : t < 40 ? 0x6ed9eba1 : t < 60 ? 0x8f1bbcdc : 0xca62c1d6;
            var next = (a << 5 | a >>> 27) + mix + e + constant + schedule[t] | 0;
            e = d;
            d = c;
            c = b << 30 | b >>> 2;
            b = a;
            a = next;
        }
        state = [state[0] + a | 0, state[1] + b | 0, state[2] + c | 0, state[3] + d | 0, state[4] + e | 0];
    }
    return wordsHex(state, true);
}

var MD5_SHIFTS = [7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21];

var MD5_ROUNDS = [0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501, 0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70, 0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391];

function md5(bytes) {
    var words = blocks(bytes, false);
    var state = [0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476];
    for (var block = 0; block < words.length; block += 16) {
        var a = state[0], b = state[1], c = state[2], d = state[3];
        for (var i = 0; i < 64; i++) {
            var mix, pick;
            if (i < 16) {
                mix = b & c | ~b & d;
                pick = i;
            } else if (i < 32) {
                mix = d & b | ~d & c;
                pick = (5 * i + 1) % 16;
            } else if (i < 48) {
                mix = b ^ c ^ d;
                pick = (3 * i + 5) % 16;
            } else {
                mix = c ^ (b | ~d);
                pick = 7 * i % 16;
            }
            var sum = a + mix + MD5_ROUNDS[i] + words[block + pick] | 0;
            a = d;
            d = c;
            c = b;
            b = b + (sum << MD5_SHIFTS[i] | sum >>> 32 - MD5_SHIFTS[i]) | 0;
        }
        state = [state[0] + a | 0, state[1] + b | 0, state[2] + c | 0, state[3] + d | 0];
    }
    return wordsHex(state, false);
}

var HASHES = {
    sha256: {
        name: "SHA-256",
        run: sha256
    },
    sha1: {
        name: "SHA-1",
        run: sha1
    },
    md5: {
        name: "MD5",
        run: md5
    }
};

function readBytes(text) {
    var out = [];
    var parts = String(text || "").split(/\s+/);
    for (var i = 0; i < parts.length; i++) {
        if (!parts[i])
            continue;
        var value = parseInt(parts[i], 10);
        if (value >= 0 && value <= 255)
            out.push(value);
    }
    return out;
}

function pickIndex(pool, from, size) {
    var limit = 256 - 256 % size;
    for (var at = from; at < pool.length; at++)
        if (pool[at] < limit)
            return {
                value: pool[at] % size,
                next: at + 1
            };
    return null;
}

function pickInteger(pool, from, low, high) {
    var range = high - low + 1;
    var width = 1;
    while (Math.pow(256, width) < range && width < 6)
        width++;
    var span = Math.pow(256, width);
    var limit = Math.floor(span / range) * range;
    for (var at = from; at + width <= pool.length; at += width) {
        var value = 0;
        for (var k = 0; k < width; k++)
            value = value * 256 + pool[at + k];
        if (value < limit)
            return {
                value: low + value % range,
                next: at + width
            };
    }
    return null;
}

var LOWER = "abcdefghijklmnopqrstuvwxyz";
var UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
var DIGITS = "0123456789";
var SYMBOLS = "!#$%&*+-=?@^_~.,:;/()[]{}<>";

var CHARACTER_SETS = {
    full: [LOWER, UPPER, DIGITS, SYMBOLS],
    simple: [LOWER, UPPER, DIGITS],
    digits: [DIGITS]
};

function setSize(set) {
    return CHARACTER_SETS[set].join("").length;
}

function strengthBits(length, set) {
    return Math.floor(length * Math.log(setSize(set)) / Math.LN2);
}

function drawPassword(pool, from, length, set) {
    var classes = CHARACTER_SETS[set];
    var alphabet = classes.join("");
    var required = length >= classes.length ? classes : [];
    var chars = [];
    var at = from;
    var picked;
    for (var i = 0; i < length; i++) {
        var source = i < required.length ? required[i] : alphabet;
        picked = pickIndex(pool, at, source.length);
        if (!picked)
            return null;
        chars.push(source.charAt(picked.value));
        at = picked.next;
    }
    for (var k = chars.length - 1; k > 0; k--) {
        picked = pickIndex(pool, at, k + 1);
        if (!picked)
            return null;
        at = picked.next;
        var held = chars[k];
        chars[k] = chars[picked.value];
        chars[picked.value] = held;
    }
    return {
        value: chars.join(""),
        next: at
    };
}

function uuidFrom(bytes) {
    var raw = bytes.slice(0, 16);
    raw[6] = raw[6] & 0x0f | 0x40;
    raw[8] = raw[8] & 0x3f | 0x80;
    var hex = hexOf(raw);
    return `${hex.slice(0, 8)}-${hex.slice(8, 12)}-${hex.slice(12, 16)}-${hex.slice(16, 20)}-${hex.slice(20, 32)}`;
}

function drawKey(ask, passwordLength) {
    if (!ask)
        return "";
    switch (ask.tool) {
    case "uuid":
        return `uuid:${ask.count}`;
    case "password":
        return `password:${ask.length || passwordLength || 20}:${ask.set}`;
    case "random":
        return `random:${ask.low}:${ask.high}`;
    case "dice":
        return `dice:${ask.count}:${ask.sides}`;
    case "coin":
        return "coin";
    }
    return "";
}

function draw(key, pool, from) {
    var parts = String(key).split(":");
    var at = from;
    var values = [];
    var picked;
    switch (parts[0]) {
    case "uuid":
        for (var u = 0; u < parseInt(parts[1], 10); u++) {
            if (at + 16 > pool.length)
                return null;
            values.push(uuidFrom(pool.slice(at, at + 16)));
            at += 16;
        }
        return {
            value: values,
            next: at
        };
    case "password":
        picked = drawPassword(pool, at, parseInt(parts[1], 10), parts[2]);
        return picked;
    case "random":
        return pickInteger(pool, at, parseInt(parts[1], 10), parseInt(parts[2], 10));
    case "dice":
        for (var r = 0; r < parseInt(parts[1], 10); r++) {
            picked = pickInteger(pool, at, 1, parseInt(parts[2], 10));
            if (!picked)
                return null;
            values.push(picked.value);
            at = picked.next;
        }
        return {
            value: values,
            next: at
        };
    case "coin":
        picked = pickIndex(pool, at, 2);
        return picked ? {
            value: picked.value === 0 ? "Heads" : "Tails",
            next: picked.next
        } : null;
    }
    return null;
}

var URL_KEPT = /[A-Za-z0-9_.~-]/;

function urlEncode(text) {
    var bytes = utf8Bytes(text);
    var out = "";
    for (var i = 0; i < bytes.length; i++) {
        var c = String.fromCharCode(bytes[i]);
        out += bytes[i] < 0x80 && URL_KEPT.test(c) ? c : `%${HEX.charAt(bytes[i] >> 4).toUpperCase()}${HEX.charAt(bytes[i] & 15).toUpperCase()}`;
    }
    return out;
}

function urlDecode(text) {
    try {
        return decodeURIComponent(String(text));
    } catch (error) {
        return null;
    }
}

var HTML_ESCAPES = {
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    "\"": "&quot;",
    "'": "&#39;"
};

var HTML_NAMED = {
    amp: "&",
    lt: "<",
    gt: ">",
    quot: "\"",
    apos: "'",
    nbsp: " ",
    copy: "©",
    reg: "®",
    trade: "™",
    hellip: "…",
    mdash: "\u2014",
    ndash: "\u2013",
    lsquo: "‘",
    rsquo: "’",
    ldquo: "“",
    rdquo: "”",
    euro: "€",
    pound: "£",
    yen: "¥",
    cent: "¢",
    deg: "°",
    times: "×",
    divide: "÷",
    middot: "·",
    laquo: "«",
    raquo: "»",
    bull: "•",
    aelig: "æ",
    AElig: "Æ",
    oslash: "ø",
    Oslash: "Ø",
    aring: "å",
    Aring: "Å",
    szlig: "ß"
};

var HTML_ENTITY = /&(#[0-9]+|#[xX][0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);/g;

function htmlEscape(text) {
    return String(text).replace(/[&<>"']/g, c => HTML_ESCAPES[c]);
}

function htmlUnescape(text) {
    return String(text).replace(HTML_ENTITY, (whole, name) => {
        if (name.charAt(0) === "#") {
            var code = name.charAt(1) === "x" || name.charAt(1) === "X" ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10);
            return code > 0 && code <= 0x10ffff && !(code >= 0xd800 && code <= 0xdfff) ? String.fromCodePoint(code) : whole;
        }
        return Object.prototype.hasOwnProperty.call(HTML_NAMED, name) ? HTML_NAMED[name] : whole;
    });
}

var FOLDED = {
    "æ": "ae",
    "ø": "o",
    "å": "a",
    "ß": "ss",
    "œ": "oe",
    "ł": "l",
    "đ": "d",
    "ð": "d",
    "þ": "th",
    "ı": "i"
};

var FOLDABLE = /[æøåßœłđðþı]/g;
var MARKS = /[̀-ͯ]/g;

function folded(text) {
    var lower = String(text).toLowerCase().replace(FOLDABLE, c => FOLDED[c]);
    return typeof lower.normalize === "function" ? lower.normalize("NFD").replace(MARKS, "") : lower;
}

var WORD_PIECES = /[A-ZÀ-Þ]+(?![a-zß-ÿ])|[A-ZÀ-Þ]?[a-zß-ÿĀ-ɏ]+|[0-9]+|[Ā-ɏͰ-ϿЀ-ӿ]+/g;

function words(text) {
    var found = String(text).match(WORD_PIECES);
    return found ? found : [];
}

function capital(word) {
    return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
}

var SMALL_WORDS = ["a", "an", "and", "as", "at", "but", "by", "for", "in", "nor", "of", "on", "or", "the", "to", "up", "via", "vs"];

var CASES = [
    {
        id: "camel",
        name: "camel case"
    },
    {
        id: "pascal",
        name: "pascal case"
    },
    {
        id: "snake",
        name: "snake case"
    },
    {
        id: "constant",
        name: "constant case"
    },
    {
        id: "kebab",
        name: "kebab case"
    },
    {
        id: "title",
        name: "title case"
    },
    {
        id: "sentence",
        name: "sentence case"
    },
    {
        id: "upper",
        name: "upper case"
    },
    {
        id: "lower",
        name: "lower case"
    },
    {
        id: "dot",
        name: "dot case"
    },
    {
        id: "slug",
        name: "slug"
    }
];

function caseName(id) {
    var found = CASES.find(c => c.id === id);
    return found ? found.name : id;
}

function convertCase(id, text) {
    var source = String(text);
    var pieces = words(source);
    var lower = pieces.map(w => w.toLowerCase());
    switch (id) {
    case "upper":
        return source.toUpperCase();
    case "lower":
        return source.toLowerCase();
    case "camel":
        return lower.map((w, i) => i === 0 ? w : capital(w)).join("");
    case "pascal":
        return lower.map(capital).join("");
    case "snake":
        return lower.join("_");
    case "constant":
        return lower.join("_").toUpperCase();
    case "kebab":
        return lower.join("-");
    case "dot":
        return lower.join(".");
    case "slug":
        return words(folded(source)).map(w => w.toLowerCase()).join("-");
    case "sentence":
        {
            var flat = source.toLowerCase().replace(/\s+/g, " ").trim();
            return flat.charAt(0).toUpperCase() + flat.slice(1);
        }
    case "title":
        {
            var spaced = source.replace(/\s+/g, " ").trim().split(" ");
            return spaced.map((w, i) => i > 0 && i < spaced.length - 1 && SMALL_WORDS.indexOf(w.toLowerCase()) >= 0 ? w.toLowerCase() : w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()).join(" ");
        }
    }
    return source;
}

function counts(text) {
    var source = String(text);
    var characters = 0;
    for (var i = 0; i < source.length; i++) {
        var unit = source.charCodeAt(i);
        if (!(unit >= 0xdc00 && unit <= 0xdfff && i > 0 && source.charCodeAt(i - 1) >= 0xd800 && source.charCodeAt(i - 1) <= 0xdbff))
            characters++;
    }
    var spoken = source.trim() ? source.trim().split(/\s+/).length : 0;
    return {
        characters: characters,
        words: spoken,
        lines: source ? source.split(/\r\n|\r|\n/).length : 0,
        bytes: utf8Bytes(source).length
    };
}

function plural(n, one, many) {
    return `${n} ${n === 1 ? one : many || `${one}s`}`;
}

var JSON_NUMBER = /^-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/;
var JSON_HEX4 = /^[0-9a-fA-F]{4}$/;

function jsonProblem(text) {
    var source = String(text);
    var at = 0;
    var problem = null;

    function fail(expected) {
        if (!problem)
            problem = {
                offset: at,
                expected: expected
            };
        return false;
    }
    function space() {
        while (at < source.length && " \t\n\r".indexOf(source.charAt(at)) >= 0)
            at++;
    }
    function literal(word) {
        if (source.substr(at, word.length) !== word)
            return false;
        at += word.length;
        return true;
    }
    function string() {
        at++;
        while (at < source.length) {
            var c = source.charAt(at);
            if (c === "\"") {
                at++;
                return true;
            }
            if (c === "\\") {
                var escaped = source.charAt(at + 1);
                if ("\"\\/bfnrt".indexOf(escaped) >= 0 && escaped) {
                    at += 2;
                    continue;
                }
                if (escaped === "u" && JSON_HEX4.test(source.substr(at + 2, 4))) {
                    at += 6;
                    continue;
                }
                at++;
                return fail("a valid escape after \\");
            }
            if (c < " ")
                return fail("a closing quote");
            at++;
        }
        return fail("a closing quote");
    }
    function value(depth) {
        space();
        if (depth > 512)
            return fail("less nesting");
        if (at >= source.length)
            return fail("a value");
        var c = source.charAt(at);
        if (c === "{")
            return object(depth);
        if (c === "[")
            return array(depth);
        if (c === "\"")
            return string();
        if (c === "-" || c >= "0" && c <= "9") {
            var number = JSON_NUMBER.exec(source.slice(at, at + 400));
            if (!number)
                return fail("a number");
            at += number[0].length;
            return true;
        }
        if (literal("true") || literal("false") || literal("null"))
            return true;
        return fail(c === "'" ? "double quotes" : "a value");
    }
    function object(depth) {
        at++;
        space();
        if (source.charAt(at) === "}") {
            at++;
            return true;
        }
        for (;;) {
            space();
            if (source.charAt(at) !== "\"")
                return fail(source.charAt(at) === "}" ? "a key after the comma" : "a quoted key");
            if (!string())
                return false;
            space();
            if (source.charAt(at) !== ":")
                return fail("a colon");
            at++;
            if (!value(depth + 1))
                return false;
            space();
            if (source.charAt(at) === ",") {
                at++;
                continue;
            }
            if (source.charAt(at) === "}") {
                at++;
                return true;
            }
            return fail("a comma or }");
        }
    }
    function array(depth) {
        at++;
        space();
        if (source.charAt(at) === "]") {
            at++;
            return true;
        }
        for (;;) {
            space();
            if (source.charAt(at) === "]")
                return fail("a value after the comma");
            if (!value(depth + 1))
                return false;
            space();
            if (source.charAt(at) === ",") {
                at++;
                continue;
            }
            if (source.charAt(at) === "]") {
                at++;
                return true;
            }
            return fail("a comma or ]");
        }
    }

    if (value(0)) {
        space();
        if (at < source.length)
            fail("nothing more");
    }
    if (!problem)
        return null;
    var before = source.slice(0, problem.offset);
    var lineStart = before.lastIndexOf("\n") + 1;
    var found = problem.offset >= source.length ? "the end" : source.charAt(problem.offset);
    return {
        offset: problem.offset,
        line: before.split("\n").length,
        column: problem.offset - lineStart + 1,
        expected: problem.expected,
        found: found,
        excerpt: source.slice(lineStart, source.indexOf("\n", problem.offset) < 0 ? source.length : source.indexOf("\n", problem.offset))
    };
}

function jsonShape(value) {
    if (Array.isArray(value))
        return plural(value.length, "item");
    if (value && typeof value === "object")
        return plural(Object.keys(value).length, "key");
    return value === null ? "null" : typeof value;
}

var JSON_SPACE = " \t\n\r";
var JSON_STOPS = ",:{}[] \t\n\r\"";

function jsonReflow(text, pretty) {
    var source = String(text);
    var out = "";
    var depth = 0;
    var i = 0;
    var newline = () => pretty ? `\n${"  ".repeat(depth)}` : "";
    while (i < source.length) {
        var c = source.charAt(i);
        if (c === "\"") {
            var j = i + 1;
            while (j < source.length && source.charAt(j) !== "\"")
                j += source.charAt(j) === "\\" ? 2 : 1;
            out += source.slice(i, j + 1);
            i = j + 1;
        } else if (JSON_SPACE.indexOf(c) >= 0) {
            i++;
        } else if (c === "{" || c === "[") {
            var close = c === "{" ? "}" : "]";
            var k = i + 1;
            while (k < source.length && JSON_SPACE.indexOf(source.charAt(k)) >= 0)
                k++;
            if (source.charAt(k) === close) {
                out += c + close;
                i = k + 1;
            } else {
                depth++;
                out += c + newline();
                i++;
            }
        } else if (c === "}" || c === "]") {
            depth--;
            out += newline() + c;
            i++;
        } else if (c === ",") {
            out += `,${newline()}`;
            i++;
        } else if (c === ":") {
            out += pretty ? ": " : ":";
            i++;
        } else {
            var begin = i;
            while (i < source.length && JSON_STOPS.indexOf(source.charAt(i)) < 0)
                i++;
            out += source.slice(begin, i);
        }
    }
    return out;
}

function jsonFormat(text, minify) {
    var source = String(text).trim();
    var parsed;
    try {
        parsed = JSON.parse(source);
    } catch (error) {
        var problem = jsonProblem(source) || {
            line: 1,
            column: 1,
            expected: "valid JSON",
            found: "",
            excerpt: source.split("\n")[0]
        };
        return {
            ok: false,
            problem: problem
        };
    }
    var pretty = jsonReflow(source, true);
    var compact = jsonReflow(source, false);
    return {
        ok: true,
        text: minify ? compact : pretty,
        other: minify ? pretty : compact,
        compact: compact,
        lines: pretty.split("\n").length,
        shape: jsonShape(parsed)
    };
}

var JWT_SHAPE = /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$/;

function jsonPart(text) {
    var bytes = base64Decode(text);
    var decoded = bytes ? utf8Text(bytes) : null;
    if (decoded === null)
        return null;
    try {
        var value = JSON.parse(decoded);
        return value && typeof value === "object" && !Array.isArray(value) ? value : null;
    } catch (error) {
        return null;
    }
}

var JWT_TIMES = [["exp", "Expires"], ["iat", "Issued"], ["nbf", "Valid from"], ["auth_time", "Signed in"]];

function jwtRead(token) {
    var clean = String(token || "").trim().replace(/^bearer\s+/i, "");
    if (!JWT_SHAPE.test(clean))
        return null;
    var parts = clean.split(".");
    var header = jsonPart(parts[0]);
    var payload = jsonPart(parts[1]);
    if (!header || !payload)
        return null;
    var times = [];
    for (var i = 0; i < JWT_TIMES.length; i++) {
        var seconds = payload[JWT_TIMES[i][0]];
        if (typeof seconds === "number" && isFinite(seconds) && Math.abs(seconds * 1000) < 8.64e15)
            times.push({
                claim: JWT_TIMES[i][0],
                name: JWT_TIMES[i][1],
                ms: seconds * 1000
            });
    }
    return {
        header: header,
        payload: payload,
        signed: parts[2].length > 0,
        algorithm: typeof header.alg === "string" ? header.alg : "",
        times: times
    };
}

var EPOCH_UNITS = [[11, 1000, "seconds"], [14, 1, "milliseconds"], [17, 0.001, "microseconds"], [19, 0.000001, "nanoseconds"]];

function epochRead(text) {
    var m = /^(-?)(\d{1,19})(?:\.(\d{1,9}))?$/.exec(String(text || "").trim());
    if (!m)
        return null;
    var unit = EPOCH_UNITS.find(u => m[2].length <= u[0]);
    if (!unit || m[3] && unit[2] !== "seconds")
        return null;
    var ms = parseFloat(`${m[1]}${m[2]}${m[3] ? `.${m[3]}` : ""}`) * unit[1];
    return isFinite(ms) && Math.abs(ms) < 8.64e15 ? {
        ms: ms,
        unit: unit[2]
    } : null;
}

var PLAUSIBLE_FROM = Date.UTC(2000, 0, 1);
var PLAUSIBLE_TO = Date.UTC(2100, 0, 1);

function isoText(ms) {
    var d = new Date(ms);
    var pad = (n, w) => String(n).padStart(w || 2, "0");
    var fraction = d.getUTCMilliseconds() ? `.${pad(d.getUTCMilliseconds(), 3)}` : "";
    return `${pad(d.getUTCFullYear(), 4)}-${pad(d.getUTCMonth() + 1)}-${pad(d.getUTCDate())}T${pad(d.getUTCHours())}:${pad(d.getUTCMinutes())}:${pad(d.getUTCSeconds())}${fraction}Z`;
}

function span(ms) {
    var seconds = Math.round(Math.abs(ms) / 1000);
    var steps = [[31557600, "year"], [2629800, "month"], [604800, "week"], [86400, "day"], [3600, "hour"], [60, "minute"], [1, "second"]];
    for (var i = 0; i < steps.length; i++)
        if (seconds >= steps[i][0]) {
            var n = Math.floor(seconds / steps[i][0]);
            return `${n} ${steps[i][1]}${n === 1 ? "" : "s"}`;
        }
    return "";
}

function relative(ms, now) {
    var gap = span(ms - now);
    if (!gap)
        return "now";
    return ms > now ? `in ${gap}` : `${gap} ago`;
}

var ASK = {
    uuid: /^(?:new\s+|generate\s+(?:an?\s+)?|random\s+)?(?:uuid|guid)s?(?:\s*v4|4)?(?:\s+(\d{1,2}))?$/i,
    password: /^(?:new\s+|generate\s+(?:an?\s+)?|random\s+|make\s+(?:me\s+)?an?\s+)?(?:(\d{1,3})\s*(?:char(?:acter)?s?\s+)?(?:long\s+)?)?(?:password|passwd)(?:\s+(.*))?$/i,
    pin: /^(?:new\s+|random\s+|generate\s+(?:an?\s+)?)?pin(?:\s+code)?\s+(\d{1,2})$/i,
    randomRange: /^(?:pick\s+a\s+|a\s+)?(?:random|rand|rng)(?:\s+(?:number|int|integer|num))?(?:\s+(?:between|from))?\s+(-?\d{1,15})(?:\s*(?:-|to|and|\.\.|,)\s*|\s+)(-?\d{1,15})$/i,
    randomTo: /^(?:pick\s+a\s+|a\s+)?(?:random|rand|rng)(?:\s+(?:number|int|integer|num))?\s+(?:up\s+to\s+|to\s+|below\s+|under\s+)?(\d{1,15})$/i,
    pickBetween: /^pick\s+a\s+number\s+(?:between|from)\s+(-?\d{1,15})\s+(?:and|to)\s+(-?\d{1,15})$/i,
    randomBare: /^(?:random|random\s+number|rng)$/i,
    dice: /^(?:roll|throw)\s+(?:an?\s+|the\s+)?(?:(\d{1,2})\s*)?(?:d(\d{1,4})|dice|die)$/i,
    diceBare: /^(\d{1,2})?d(\d{1,4})$/i,
    coin: /^(?:(?:flip|toss)\s+(?:an?\s+|the\s+)?coin|coin\s*(?:flip|toss)?|heads\s+or\s+tails\??)$/i,
    base64: /^(?:base\s?64|b64)(?:\s+(encode|decode|enc|dec|-d))?(?:\s+([\s\S]+))?$/i,
    base64Lead: /^(encode|decode)\s+(?:base\s?64|b64|from\s+base\s?64)(?:\s+([\s\S]+))?$/i,
    url: /^(?:url|uri|percent)[\s-]?(encode|decode|escape|unescape)(?:\s+([\s\S]+))?$/i,
    urlLead: /^(encode|decode|escape|unescape)\s+(?:url|uri)(?:\s+([\s\S]+))?$/i,
    html: /^html[\s-]?(escape|unescape|encode|decode|entities)(?:\s+([\s\S]+))?$/i,
    htmlLead: /^(escape|unescape|encode|decode)\s+html(?:\s+([\s\S]+))?$/i,
    hash: /^(sha-?256|sha-?1|md5|hash|hashes|checksum)(?:sum)?(?:\s+([\s\S]+))?$/i,
    json: /^(?:(pretty|format|beautify|minify|compact|validate)\s+)?json(?:\s+(pretty|format|beautify|min|minify|compact|validate|lint))?(?:\s+([\s\S]+))?$/i,
    jwt: /^(?:jwt\s+decode|decode\s+jwt|jwt)(?:\s+(\S+(?:\s+\S+)?))?$/i,
    jwtBare: /^(?:bearer\s+)?eyJ[A-Za-z0-9_-]*\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*$/i,
    caseNamed: /^(snake|camel|pascal|kebab|constant|screaming|title|sentence|upper|lower|dot)[\s_-]?case(?:\s+([\s\S]+))?$/i,
    caseShort: /^(to\s+upper|to\s+lower|uppercase|lowercase|capitali[sz]e|titlecase|slugify|slug)\s+([\s\S]+)$/i,
    caseLoose: /^(upper|lower)\s+(?!(?:the\s+)?(?:volume|sound|brightness|music)$)([\s\S]+)$/i,
    caseAll: /^(?:case|cases|convert\s+case|change\s+case)(?:\s+([\s\S]+))?$/i,
    epoch: /^(?:epoch|unix|timestamp|unix\s+time(?:stamp)?|from\s+epoch|epoch\s+to\s+date)\s+@?(-?\d{1,19}(?:\.\d{1,9})?)$/i,
    epochDate: /^date\s+@?(\d{9,19}(?:\.\d{1,9})?)$/i,
    epochAt: /^@(\d{1,19}(?:\.\d{1,9})?)$/,
    epochBare: /^(\d{10}(?:\.\d{1,6})?|\d{13})$/,
    now: /^(?:unix\s+now|epoch\s+now|current\s+(?:unix\s+)?(?:time\s?stamp|epoch|unix\s+time)|unix\s+time(?:\s?stamp)?|time\s?stamp|epoch|unix\s+epoch|time\s?stamp\s+now)$/i,
    nowBare: /^(?:now|unix)$/i,
    count: /^(?:count|wc)(?:\s+(words?|characters|chars|letters|lines))?(?:\s+(?:in|of)(?=\s))?(?:\s+([\s\S]+))?$/i,
    countNamed: /^(word|character|char|letter|line)\s+count(?:\s+([\s\S]+))?$/i,
    countHowMany: /^how\s+many\s+(words|characters|chars|letters|lines)\s+(?:are\s+)?in\s+([\s\S]+)$/i
};

var PASSWORD_WORDS = [[/^(?:simple|no\s+symbols|without\s+symbols|alphanumeric|letters\s+(?:and\s+)?digits|letters\s+(?:and\s+)?numbers)$/i, "simple"], [/^(?:digits|numbers|digits\s+only|numbers\s+only|numeric)$/i, "digits"], [/^(?:strong|with\s+symbols|symbols|full)$/i, "full"]];

var PASSWORD_LENGTH = /^(\d{1,3})(?:\s*(?:char(?:acter)?s?|long))?(?:\s+|$)/i;

function passwordOptions(rest, length) {
    var out = {
        length: length,
        set: "full"
    };
    var left = String(rest || "").trim();
    for (var guard = 0; left && guard < 4; guard++) {
        var sized = PASSWORD_LENGTH.exec(left);
        if (sized) {
            out.length = parseInt(sized[1], 10);
            left = left.slice(sized[0].length).trim();
            continue;
        }
        var matched = false;
        var lead = /^(?:with\s+|without\s+|no\s+|letters\s+(?:and\s+)?)?\S+(?:\s+only)?/i.exec(left);
        var phrase = lead ? lead[0] : left;
        for (var i = 0; i < PASSWORD_WORDS.length; i++)
            if (PASSWORD_WORDS[i][0].test(phrase)) {
                out.set = PASSWORD_WORDS[i][1];
                matched = true;
            }
        if (!matched)
            return null;
        left = left.slice(phrase.length).trim();
    }
    if (left)
        return null;
    return out.length === 0 || out.length >= 4 && out.length <= 128 ? out : null;
}

function inputOf(text) {
    return text === undefined || text === null || text === "" ? null : String(text);
}

function devAsk(text) {
    var t = String(text || "").trim();
    if (t.length < 2)
        return null;
    var m;
    if ((m = ASK.uuid.exec(t))) {
        var many = m[1] ? parseInt(m[1], 10) : 1;
        return many >= 1 && many <= 20 ? {
            tool: "uuid",
            count: many,
            explicit: true
        } : null;
    }
    if ((m = ASK.pin.exec(t))) {
        var digits = parseInt(m[1], 10);
        return digits >= 3 && digits <= 32 ? {
            tool: "password",
            length: digits,
            set: "digits",
            pin: true,
            explicit: true
        } : null;
    }
    if ((m = ASK.password.exec(t))) {
        var options = passwordOptions(m[2], m[1] ? parseInt(m[1], 10) : 0);
        if (!options || m[1] && (parseInt(m[1], 10) < 4 || parseInt(m[1], 10) > 128))
            return null;
        return {
            tool: "password",
            length: options.length,
            set: options.set,
            explicit: !!(m[1] || m[2]) || /^(?:new|generate|random|make)\b/i.test(t)
        };
    }
    if ((m = ASK.randomRange.exec(t) || ASK.pickBetween.exec(t))) {
        var a = parseInt(m[1], 10);
        var b = parseInt(m[2], 10);
        return Math.abs(a) <= 1e15 && Math.abs(b) <= 1e15 ? {
            tool: "random",
            low: Math.min(a, b),
            high: Math.max(a, b),
            explicit: true
        } : null;
    }
    if ((m = ASK.randomTo.exec(t))) {
        var top = parseInt(m[1], 10);
        return top >= 1 ? {
            tool: "random",
            low: 1,
            high: top,
            explicit: true
        } : null;
    }
    if (ASK.randomBare.test(t))
        return {
            tool: "random",
            low: 1,
            high: 100,
            explicit: false
        };
    if ((m = ASK.dice.exec(t) || ASK.diceBare.exec(t))) {
        var rolls = m[1] ? parseInt(m[1], 10) : 1;
        var sides = m[2] ? parseInt(m[2], 10) : 6;
        return rolls >= 1 && rolls <= 20 && sides >= 2 ? {
            tool: "dice",
            count: rolls,
            sides: sides,
            explicit: !ASK.diceBare.test(t)
        } : null;
    }
    if (ASK.coin.test(t))
        return {
            tool: "coin",
            explicit: !/^coin$/i.test(t)
        };
    if ((m = ASK.base64.exec(t) || ASK.base64Lead.exec(t))) {
        var direction = (m[1] || "").toLowerCase();
        return {
            tool: "base64",
            decode: direction === "decode" || direction === "dec" || direction === "-d",
            either: !direction,
            input: inputOf(m[2]),
            explicit: true
        };
    }
    if ((m = ASK.url.exec(t) || ASK.urlLead.exec(t)))
        return {
            tool: "url",
            decode: /^(?:decode|unescape)$/i.test(m[1]),
            input: inputOf(m[2]),
            explicit: true
        };
    if ((m = ASK.html.exec(t) || ASK.htmlLead.exec(t)))
        return {
            tool: "html",
            decode: /^(?:decode|unescape)$/i.test(m[1]),
            input: inputOf(m[2]),
            explicit: true
        };
    if ((m = ASK.hash.exec(t))) {
        var named = m[1].toLowerCase().replace("-", "");
        return {
            tool: "hash",
            algorithms: HASHES[named] ? [named] : ["sha256", "sha1", "md5"],
            input: inputOf(m[2]),
            explicit: !!HASHES[named] || !m[2] || m[1].toLowerCase() !== "hash"
        };
    }
    if ((m = ASK.json.exec(t))) {
        var inline = inputOf(m[3]);
        if (inline !== null && !/^[\s]*[\[{"]/.test(inline))
            return null;
        return {
            tool: "json",
            minify: /^(?:min|minify|compact)$/i.test(m[1] || m[2] || ""),
            input: inline,
            explicit: true
        };
    }
    if ((m = ASK.jwt.exec(t)))
        return {
            tool: "jwt",
            input: inputOf(m[1]),
            explicit: true
        };
    if (ASK.jwtBare.test(t) && jwtRead(t))
        return {
            tool: "jwt",
            input: t,
            explicit: true
        };
    if ((m = ASK.caseNamed.exec(t))) {
        var kind = m[1].toLowerCase() === "screaming" ? "constant" : m[1].toLowerCase();
        return {
            tool: "case",
            cases: [kind],
            input: inputOf(m[2]),
            explicit: true
        };
    }
    if ((m = ASK.caseShort.exec(t) || ASK.caseLoose.exec(t))) {
        var short = m[1].toLowerCase();
        var picked = short.indexOf("upper") >= 0 ? "upper" : short.indexOf("lower") >= 0 ? "lower" : short.indexOf("slug") === 0 ? "slug" : "title";
        return {
            tool: "case",
            cases: [picked],
            input: m[2],
            explicit: !ASK.caseLoose.test(t)
        };
    }
    if ((m = ASK.caseAll.exec(t)))
        return {
            tool: "case",
            cases: CASES.map(c => c.id),
            input: inputOf(m[1]),
            explicit: !!m[1] && !/^case$/i.test(t.split(/\s+/)[0])
        };
    if ((m = ASK.epoch.exec(t) || ASK.epochDate.exec(t) || ASK.epochAt.exec(t))) {
        var stamp = epochRead(m[1]);
        return stamp ? {
            tool: "epoch",
            ms: stamp.ms,
            unit: stamp.unit,
            explicit: true
        } : null;
    }
    if ((m = ASK.epochBare.exec(t))) {
        var bare = epochRead(m[1]);
        return bare && bare.ms >= PLAUSIBLE_FROM && bare.ms < PLAUSIBLE_TO ? {
            tool: "epoch",
            ms: bare.ms,
            unit: bare.unit,
            explicit: false
        } : null;
    }
    if (ASK.now.test(t) || ASK.nowBare.test(t))
        return {
            tool: "now",
            explicit: !ASK.nowBare.test(t)
        };
    if ((m = ASK.count.exec(t) || ASK.countNamed.exec(t) || ASK.countHowMany.exec(t))) {
        var measure = (m[1] || "").toLowerCase();
        return {
            tool: "count",
            only: measure.indexOf("word") === 0 ? "words" : measure.indexOf("line") === 0 ? "lines" : measure ? "characters" : "",
            input: inputOf(m[2]),
            explicit: !!m[1] || /^wc\b/i.test(t)
        };
    }
    return null;
}

function readPaste(output) {
    var text = String(output || "");
    if (text === "secret")
        return {
            secret: true,
            text: ""
        };
    return {
        secret: false,
        text: text.indexOf("text\n") === 0 ? text.slice(5) : ""
    };
}

function answer(id, label, detail, copy, extra) {
    var out = {
        id: id,
        label: label,
        detail: detail,
        copy: copy === undefined ? label : copy
    };
    for (var key in extra || {})
        out[key] = extra[key];
    return out;
}

function secretClipboard() {
    return answer("clipboard:secret", "The clipboard holds a secret", "not read", null, {
        failed: true
    });
}

function clipped(text, size) {
    var flat = String(text).replace(/\s+/g, " ");
    return flat.length > size ? `${flat.slice(0, size - 1)}…` : flat;
}

function answers(ask, input, drawn, now) {
    if (!ask)
        return [];
    var source = ask.input !== null && ask.input !== undefined ? ask.input : input;
    var from = ask.input === null || ask.input === undefined ? "clipboard" : "";
    var tagged = parts => parts.filter(Boolean).join(" · ");
    var out = [];
    var bytes;
    switch (ask.tool) {
    case "uuid":
        return (drawn || []).map((id, i) => answer(`uuid:${i}`, id, i === 0 ? "v4" : "", id, {
                    redraw: true
                }));
    case "password":
        return drawn ? [answer("password", drawn, tagged([plural(drawn.length, ask.pin ? "digit" : "character"), `${strengthBits(drawn.length, ask.set)} bits`]), drawn, {
                    secret: true,
                    redraw: true
                })] : [];
    case "random":
        return drawn !== undefined && drawn !== null ? [answer("random", String(drawn), `${ask.low} to ${ask.high}`, undefined, {
                    redraw: true
                })] : [];
    case "dice":
        if (!drawn)
            return [];
        return [answer("dice", String(drawn.reduce((sum, n) => sum + n, 0)), tagged([`${ask.count}d${ask.sides}`, drawn.length > 1 ? drawn.join(" + ") : ""]), undefined, {
                    redraw: true
                })];
    case "coin":
        return drawn ? [answer("coin", drawn, "coin flip", undefined, {
                    redraw: true
                })] : [];
    case "epoch":
        return [answer("epoch:local", "", tagged([ask.unit, relative(ask.ms, now)]), null, {
                when: ask.ms
            }), answer("epoch:iso", isoText(ask.ms), "UTC")];
    case "now":
        {
            var seconds = Math.floor(now / 1000);
            return [answer("now:seconds", String(seconds), "unix seconds"), answer("now:milliseconds", String(Math.floor(now)), "unix milliseconds"), answer("now:iso", isoText(Math.floor(now / 1000) * 1000), "UTC")];
        }
    }
    if (source === null || source === undefined || source === "")
        return [];
    switch (ask.tool) {
    case "base64":
        if (ask.decode) {
            bytes = base64Decode(source);
            if (!bytes)
                return [answer("base64:bad", "Not valid base64", tagged([from, plural(String(source).length, "character")]), null, {
                        failed: true
                    })];
            var text = utf8Text(bytes);
            return printable(text) ? [answer("base64:decoded", clipped(text, 200), tagged([from, "decoded", plural(bytes.length, "byte")]), text, {
                        peek: text.length > 80 || text.indexOf("\n") >= 0 ? text : ""
                    })] : [answer("base64:binary", clipped(hexOf(bytes.slice(0, 64)), 200), tagged([from, "binary", plural(bytes.length, "byte")]), hexOf(bytes))];
        }
        bytes = utf8Bytes(source);
        out.push(answer("base64:encoded", clipped(base64Encode(bytes), 200), tagged([from, "base64", plural(bytes.length, "byte")]), base64Encode(bytes)));
        if (ask.either && String(source).length >= 4 && !/\s/.test(source)) {
            var back = base64Decode(source);
            var readable = back && back.length ? utf8Text(back) : null;
            if (printable(readable) && readable.length > 0 && /[A-Za-z0-9]/.test(readable))
                out.push(answer("base64:decoded", clipped(readable, 200), tagged(["decoded", plural(back.length, "byte")]), readable));
        }
        return out;
    case "url":
        if (ask.decode) {
            var plain = urlDecode(source);
            return plain === null ? [answer("url:bad", "Not valid percent encoding", from, null, {
                        failed: true
                    })] : [answer("url:decoded", clipped(plain, 200), tagged([from, "decoded"]), plain)];
        }
        return [answer("url:encoded", clipped(urlEncode(source), 200), tagged([from, "percent encoded"]), urlEncode(source))];
    case "html":
        {
            var turned = ask.decode ? htmlUnescape(source) : htmlEscape(source);
            return [answer(ask.decode ? "html:decoded" : "html:escaped", clipped(turned, 200), tagged([from, ask.decode ? "unescaped" : "escaped"]), turned)];
        }
    case "hash":
        bytes = utf8Bytes(source);
        return ask.algorithms.map(name => answer(`hash:${name}`, HASHES[name].run(bytes), tagged([HASHES[name].name, from, plural(bytes.length, "byte")])));
    case "json":
        {
            var formatted = jsonFormat(source, ask.minify);
            if (!formatted.ok) {
                var p = formatted.problem;
                var start = Math.max(0, p.column - 1 - 36);
                var lead = start > 0 ? "…" : "";
                var pointer = `${lead}${p.excerpt.slice(start, start + 72)}\n${" ".repeat(lead.length + p.column - 1 - start)}^`;
                return [answer("json:bad", `Invalid JSON at ${p.line}:${p.column}`, tagged([from, `expected ${p.expected}`, p.found === "the end" ? "found the end" : `found ${p.found}`]), null, {
                        failed: true,
                        peek: pointer
                    })];
            }
            return [answer(ask.minify ? "json:minified" : "json:formatted", clipped(formatted.compact, 200), tagged([from, formatted.shape, ask.minify ? "minified" : plural(formatted.lines, "line")]), formatted.text, {
                    peek: formatted.text,
                    alternate: formatted.other,
                    alternateLabel: ask.minify ? "Copy formatted" : "Copy minified",
                    alternateShort: ask.minify ? "Formatted" : "Minified"
                })];
        }
    case "jwt":
        {
            var token = jwtRead(source);
            if (!token)
                return [answer("jwt:bad", "Not a JWT", from, null, {
                        failed: true
                    })];
            var header = JSON.stringify(token.header, null, 2);
            var payload = JSON.stringify(token.payload, null, 2);
            var both = `${header}\n\n${payload}`;
            out.push(answer("jwt:payload", clipped(JSON.stringify(token.payload), 200), tagged(["payload", token.algorithm, token.signed ? "not verified" : "unsigned"]), payload, {
                peek: both
            }));
            out.push(answer("jwt:header", clipped(JSON.stringify(token.header), 200), "header", header, {
                peek: both
            }));
            for (var i = 0; i < token.times.length; i++) {
                var time = token.times[i];
                out.push(answer(`jwt:${time.claim}`, "", tagged([time.claim, relative(time.ms, now)]), isoText(time.ms), {
                    when: time.ms,
                    prefix: time.name,
                    expired: time.claim === "exp" && time.ms <= now
                }));
            }
            return out;
        }
    case "case":
        return ask.cases.map(id => answer(`case:${id}`, clipped(convertCase(id, source), 200), tagged([caseName(id), from]), convertCase(id, source)));
    case "count":
        {
            var counted = counts(source);
            var all = [plural(counted.characters, "character"), plural(counted.words, "word"), plural(counted.lines, "line"), plural(counted.bytes, "byte")];
            var lead = ask.only === "words" ? 1 : ask.only === "lines" ? 2 : 0;
            var rest = all.filter((part, i) => i !== lead);
            return [answer("count", all[lead], tagged([from].concat(rest)), String(lead === 1 ? counted.words : lead === 2 ? counted.lines : counted.characters))];
        }
    }
    return [];
}

var PHRASES = [
    {
        head: "uuid",
        picks: [" 5"]
    },
    {
        head: "password ",
        picks: ["16", "20", "32", "20 simple"]
    },
    {
        head: "pin ",
        picks: ["4", "6"]
    },
    {
        head: "random ",
        picks: ["1 10", "1 100", "1 1000"]
    },
    {
        head: "roll ",
        picks: ["d6", "d20", "2d6"]
    },
    {
        head: "flip ",
        picks: ["a coin"]
    },
    {
        head: "base64 ",
        picks: ["decode ", "encode "]
    },
    {
        head: "url ",
        picks: ["encode ", "decode "]
    },
    {
        head: "html ",
        picks: ["escape ", "unescape "]
    },
    {
        head: "sha256 ",
        picks: [""]
    },
    {
        head: "sha1 ",
        picks: [""]
    },
    {
        head: "md5 ",
        picks: [""]
    },
    {
        head: "json",
        picks: [" min"]
    },
    {
        head: "jwt ",
        picks: [""]
    },
    {
        head: "snake case ",
        picks: [""]
    },
    {
        head: "camel case ",
        picks: [""]
    },
    {
        head: "kebab case ",
        picks: [""]
    },
    {
        head: "title case ",
        picks: [""]
    },
    {
        head: "case ",
        picks: [""]
    },
    {
        head: "slug ",
        picks: [""]
    },
    {
        head: "epoch ",
        picks: ["now"]
    },
    {
        head: "count ",
        picks: ["words ", "lines "]
    }
];
