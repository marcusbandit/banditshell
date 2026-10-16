.pragma library

var OPENING = ["lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit"];

var WORDS = ["sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore", "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud", "exercitation", "ullamco", "laboris", "nisi", "aliquip", "ex", "ea", "commodo", "consequat", "duis", "aute", "irure", "in", "reprehenderit", "voluptate", "velit", "esse", "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint", "occaecat", "cupidatat", "non", "proident", "sunt", "culpa", "qui", "officia", "deserunt", "mollit", "anim", "id", "est", "laborum", "praesent", "lectus", "mauris", "vitae", "urna", "porta", "integer", "feugiat", "pellentesque", "habitant", "morbi", "tristique", "senectus", "netus", "fames", "turpis", "egestas", "viverra", "orci", "sagittis", "eu", "volutpat", "odio", "facilisis", "massa", "nunc", "aenean", "vel", "elementum", "pulvinar", "etiam", "dignissim", "diam", "quisque", "nibh", "sapien", "tellus", "cras", "ornare", "arcu", "dui", "vivamus", "faucibus", "interdum", "posuere", "lacinia"];

var LIMITS = {
    words: 2000,
    sentences: 200,
    paragraphs: 50
};

var ASK = /^(?:lorem(?:\s+ipsum)?|ipsum)(?:\s+(\d{1,4}))?(?:\s+(words?|sentences?|paragraphs?|paras?))?$/i;

function loremAsk(text) {
    var m = ASK.exec(String(text || "").trim());
    if (!m)
        return null;
    var said = (m[2] || "paragraphs").toLowerCase();
    var unit = said.indexOf("word") === 0 ? "words" : said.indexOf("sentence") === 0 ? "sentences" : "paragraphs";
    var count = m[1] ? Number(m[1]) : unit === "words" ? 50 : unit === "sentences" ? 5 : 1;
    if (count <= 0)
        return null;
    return {
        count: Math.min(LIMITS[unit], count),
        unit: unit
    };
}

function random(seed) {
    var state = seed >>> 0;
    return () => {
        state = state + 0x6d2b79f5 >>> 0;
        var t = state;
        t = Math.imul(t ^ t >>> 15, t | 1);
        t ^= t + Math.imul(t ^ t >>> 7, t | 61);
        return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
}

function between(next, low, high) {
    return low + Math.floor(next() * (high - low + 1));
}

function capital(word) {
    return word.charAt(0).toUpperCase() + word.slice(1);
}

function wordStream(next) {
    var used = 0;
    return () => used < OPENING.length ? OPENING[used++] : WORDS[Math.floor(next() * WORDS.length)];
}

function sentence(take, next, length) {
    var words = [];
    for (var i = 0; i < length; i++)
        words.push(take());
    if (length > 7)
        words[between(next, 2, length - 4)] += ",";
    return `${capital(words.join(" "))}.`;
}

function generate(count, unit, seed) {
    var next = random(seed === undefined ? count * 31 + unit.length : seed);
    var take = wordStream(next);
    if (unit === "words") {
        var words = [];
        for (var i = 0; i < count; i++)
            words.push(take());
        return capital(words.join(" "));
    }
    var sentences = n => {
        var out = [];
        for (var j = 0; j < n; j++)
            out.push(sentence(take, next, between(next, 6, 14)));
        return out.join(" ");
    };
    if (unit === "sentences")
        return sentences(count);
    var paragraphs = [];
    for (var k = 0; k < count; k++)
        paragraphs.push(sentences(between(next, 4, 7)));
    return paragraphs.join("\n\n");
}

function describe(count, unit) {
    return `${count} ${count === 1 ? unit.slice(0, -1) : unit}`;
}

function preview(text, length) {
    var t = String(text || "");
    if (t.length <= length)
        return t;
    var cut = t.lastIndexOf(" ", length);
    return `${t.slice(0, cut > 0 ? cut : length)}…`;
}
