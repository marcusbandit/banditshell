.pragma library

var EXACT = 4;
var PREFIX = 3;
var WORD = 2;
var ANYWHERE = 1;
var NONE = -1;

function escapeRegex(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

var startsWord = {
    want: null,
    pattern: null
};

function wordStart(want) {
    if (startsWord.want !== want) {
        startsWord.want = want;
        startsWord.pattern = new RegExp("\\b" + escapeRegex(want));
    }
    return startsWord.pattern;
}

function place(haystack, needle) {
    var hay = String(haystack || "").toLowerCase();
    var want = String(needle || "").toLowerCase();
    if (!want || hay === want)
        return EXACT;
    if (hay.indexOf(want) === 0)
        return PREFIX;
    if (wordStart(want).test(hay))
        return WORD;
    if (hay.indexOf(want) >= 0)
        return ANYWHERE;
    return NONE;
}

function subsequence(haystack, needle) {
    var hay = String(haystack || "").toLowerCase();
    var want = String(needle || "").toLowerCase();
    if (!want)
        return true;
    var found = 0;
    for (var i = 0; i < hay.length; i++) {
        if (hay.charAt(i) === want.charAt(found))
            found++;
        if (found === want.length)
            return true;
    }
    return false;
}
