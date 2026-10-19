.pragma library

var LETTER = "a-z\\u00c0-\\u024f";
var HEAD = /^(?:define|def|defn|definition(?:\s+of)?|meaning(?:\s+of)?|dictionary|dict|synonyms?(?:\s+(?:of|for))?)\s*:?\s+(\S.*)$/i;
var TAIL = /^(.+?)\s+(?:meaning|definition|defined|synonyms?)\s*\??$/i;
var MEAN = /^what(?:\s+does|\s+do|'s|\u2019s)\s+(.+?)\s+mean\s*\??$/i;
var MEANING_OF = /^what(?:'s|\u2019s|\s+is)\s+the\s+(?:meaning|definition)\s+of\s+(.+?)\s*\??$/i;
var WAITING = /^\s*(?:define|def|definition of|meaning of|synonyms? (?:of|for))\s+$/i;
var WORD = new RegExp("^[" + LETTER + "][" + LETTER + "'\u2019.-]*(?: [" + LETTER + "'\u2019.-]+){0,3}$", "i");
var BARE = new RegExp("^[" + LETTER + "][" + LETTER + "'-]{3,29}$", "i");
var QUOTES = /^["'\u201c\u2018]+|["'\u201d\u2019]+$/g;
var ENDING = /[?!.,:;]+$/;
var TAGS = /<[^>]*>/g;
var ENTITIES = /&(#\d+|#x[0-9a-f]+|amp|lt|gt|quot|apos|nbsp);/gi;
var SPACES = /\s+/g;
var MOST = 12;

function cleanWord(text) {
    var word = String(text || "").trim().replace(ENDING, "").replace(QUOTES, "").replace(SPACES, " ").trim();
    return word.length <= 48 && WORD.test(word) ? word.toLowerCase() : "";
}

function ask(input) {
    var text = String(input || "").trim().replace(SPACES, " ");
    var hit = HEAD.exec(text) || MEAN.exec(text) || MEANING_OF.exec(text) || TAIL.exec(text);
    if (hit) {
        var word = cleanWord(hit[1]);
        return word ? { word: word, explicit: true } : null;
    }
    return BARE.test(text) ? { word: text.toLowerCase(), explicit: false } : null;
}

function waitingForWord(input) {
    return WAITING.test(String(input || ""));
}

function entity(match, name) {
    var n = name.toLowerCase();
    if (n.charAt(0) === "#")
        return String.fromCharCode(n.charAt(1) === "x" ? parseInt(n.slice(2), 16) : parseInt(n.slice(1), 10));
    return {
        amp: "&",
        lt: "<",
        gt: ">",
        quot: "\"",
        apos: "'",
        nbsp: " "
    }[n];
}

function plain(html) {
    return String(html || "").replace(TAGS, "").replace(ENTITIES, entity).replace(SPACES, " ").trim();
}

function fromWiktionary(data) {
    var english = data && Array.isArray(data.en) ? data.en : null;
    if (!english)
        return null;
    var senses = [];
    english.forEach(function (meaning) {
        (meaning.definitions || []).forEach(function (d) {
            var text = plain(d && d.definition);
            if (text)
                senses.push({
                    part: String(meaning.partOfSpeech || "").toLowerCase(),
                    text: text,
                    example: plain((d.examples || [])[0] || "")
                });
        });
    });
    return {
        word: "",
        phonetic: "",
        senses: senses.slice(0, MOST),
        source: "wiktionary"
    };
}

function readAnswer(raw, word) {
    var data;
    try {
        data = JSON.parse(String(raw || ""));
    } catch (e) {
        return null;
    }
    var found = fromWiktionary(data);
    if (!found || !found.senses.length)
        return null;
    if (!found.word)
        found.word = word || "";
    return found;
}

function pageUrl(word) {
    return "https://en.wiktionary.org/wiki/" + encodeURIComponent(String(word || "").replace(/ /g, "_"));
}

function escape(text) {
    return String(text || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function senseLine(part, text) {
    return part ? "<b>" + escape(part) + "</b>&nbsp; " + escape(text) : escape(text);
}

function unique(words, leaveOut) {
    var seen = {};
    seen[String(leaveOut || "").toLowerCase()] = true;
    var kept = [];
    (words || []).forEach(function (word) {
        var key = String(word || "").toLowerCase();
        if (key && !seen[key]) {
            seen[key] = true;
            kept.push(word);
        }
    });
    return kept;
}

function sensesOf(entry) {
    var out = [];
    ((entry && entry.groups) || []).forEach(function (group) {
        group.senses.forEach(function (sense) {
            out.push({
                part: group.part,
                text: sense.text,
                examples: sense.examples || [],
                synonyms: sense.synonyms || [],
                antonyms: sense.antonyms || []
            });
        });
    });
    return out;
}

function onlineSensesOf(answer) {
    return ((answer && answer.senses) || []).map(function (sense) {
        return {
            part: sense.part,
            text: sense.text,
            examples: sense.example ? [sense.example] : [],
            synonyms: [],
            antonyms: []
        };
    });
}
