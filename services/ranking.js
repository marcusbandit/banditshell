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

function typos(haystack, needle, limit) {
    var hay = String(haystack || "").toLowerCase();
    var want = String(needle || "").toLowerCase();
    var n = want.length;
    var m = hay.length;
    var before = null;
    var above = [];
    for (var j = 0; j <= m; j++)
        above.push(j);
    for (var i = 1; i <= n; i++) {
        var row = [i];
        var rowLeast = i;
        for (j = 1; j <= m; j++) {
            var cost = want.charAt(i - 1) === hay.charAt(j - 1) ? 0 : 1;
            var d = Math.min(above[j] + 1, row[j - 1] + 1, above[j - 1] + cost);
            if (before && j > 1 && want.charAt(i - 1) === hay.charAt(j - 2) && want.charAt(i - 2) === hay.charAt(j - 1))
                d = Math.min(d, before[j - 2] + 1);
            row.push(d);
            if (d < rowLeast)
                rowLeast = d;
        }
        if (limit !== undefined && rowLeast > limit)
            return rowLeast;
        before = above;
        above = row;
    }
    return above[m];
}

function sortedLetters(text) {
    return text.split("").sort().join("");
}

function wordChar(c) {
    return c.toLowerCase() !== c.toUpperCase() || c >= "0" && c <= "9";
}

function tails(label) {
    var out = [label];
    for (var s = 1; s < label.length; s++)
        if (wordChar(label.charAt(s)) && !wordChar(label.charAt(s - 1)))
            out.push(label.slice(s));
    return out;
}

var GUESS_LEAST = 5;

function closest(needle, labels) {
    var want = String(needle || "").trim().toLowerCase();
    if (want.replace(/\s+/g, "").length < GUESS_LEAST)
        return -1;
    var wantSorted = sortedLetters(want);
    var best = -1;
    var bestTypos = Infinity;
    var bestLate = true;
    var bestLength = Infinity;
    for (var k = 0; k < labels.length; k++) {
        var label = String(labels[k] || "").toLowerCase();
        var from = tails(label);
        for (var w = 0; w < from.length; w++) {
            var tail = from[w];
            if (tail.charAt(0) !== want.charAt(0))
                continue;
            var limit = Math.min(want.length, tail.length) >= 9 ? 2 : 1;
            if (Math.abs(tail.length - want.length) > limit)
                continue;
            var count = tail.length === want.length && tail !== want && sortedLetters(tail) === wantSorted ? 1 : typos(tail, want, limit);
            if (count > limit)
                continue;
            var late = w > 0;
            if (count < bestTypos || count === bestTypos && (bestLate && !late || bestLate === late && label.length < bestLength)) {
                best = k;
                bestTypos = count;
                bestLate = late;
                bestLength = label.length;
            }
        }
    }
    return best;
}
