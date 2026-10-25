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
    var least = n;
    for (var i = 1; i <= n; i++) {
        var row = [i];
        var rowLeast = i;
        for (j = 1; j <= m; j++) {
            var cost = want.charAt(i - 1) === hay.charAt(j - 1) ? 0 : 1;
            var d = Math.min(above[j] + 1, row[j - 1] + 1, above[j - 1] + cost);
            if (before && i > 1 && j > 1 && want.charAt(i - 1) === hay.charAt(j - 2) && want.charAt(i - 2) === hay.charAt(j - 1))
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
    for (j = 0; j <= m; j++)
        if (above[j] < least)
            least = above[j];
    return least;
}

function shuffled(haystack, needle) {
    var hay = String(haystack || "").toLowerCase().slice(0, String(needle || "").length);
    var want = String(needle || "").toLowerCase();
    return want.length > 1 && hay.charAt(0) === want.charAt(0) && hay !== want && hay.split("").sort().join("") === want.split("").sort().join("");
}

var GUESS_LEAST = 5;

function typoLimit(needle) {
    return String(needle || "").length >= 9 ? 2 : 1;
}

function closest(needle, labels) {
    var want = String(needle || "").trim().toLowerCase();
    if (want.replace(/\s+/g, "").length < GUESS_LEAST)
        return -1;
    var limit = typoLimit(want);
    var best = -1;
    var bestTypos = limit + 1;
    var bestLate = true;
    var bestLength = Infinity;
    for (var k = 0; k < labels.length; k++) {
        var label = String(labels[k] || "").toLowerCase();
        var starts = [0];
        for (var s = 1; s < label.length; s++)
            if (/[a-z0-9]/.test(label.charAt(s)) && !/[a-z0-9]/.test(label.charAt(s - 1)))
                starts.push(s);
        for (var w = 0; w < starts.length; w++) {
            var from = label.slice(starts[w]);
            var count = shuffled(from, want) ? 1 : typos(from, want, limit);
            var late = w > 0;
            if (count > limit)
                continue;
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
