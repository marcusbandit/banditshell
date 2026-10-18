.pragma library

var ASK = /^(?:define|definition of|meaning of|dictionary|dict)\s+([^\s].*)$/i;
var WAITING = /^\s*(?:define|definition of|meaning of)\s+$/i;
var MEANING = /^what does\s+(.+?)\s+mean\??$/i;
var WORD = /^[^\s\d<>{}()\[\]\/\\|=+*^%$#@~`",;:?!][^\d<>{}()\[\]\/\\|=+*^%$#@~`",;:?!]{0,47}$/;
var TAGS = /<[^>]*>/g;
var ENTITIES = /&(#\d+|#x[0-9a-f]+|amp|lt|gt|quot|apos|nbsp);/gi;
var SPACES = /\s+/g;
var MOST = 12;
var ENDING = /[?!.]+$/;

function ask(input) {
    var text = String(input || "").trim();
    var hit = ASK.exec(text) || MEANING.exec(text);
    if (!hit)
        return "";
    var word = hit[1].trim().replace(ENDING, "");
    return WORD.test(word) ? word.toLowerCase() : "";
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

function fromDictionaryApi(data) {
    if (!Array.isArray(data))
        return null;
    var first = data[0] || {};
    var phonetic = first.phonetic || ((first.phonetics || []).filter(function (p) {
        return p && p.text;
    })[0] || {}).text || "";
    var senses = [];
    data.forEach(function (entry) {
        (entry.meanings || []).forEach(function (meaning) {
            (meaning.definitions || []).forEach(function (d) {
                if (d && d.definition)
                    senses.push({
                        part: String(meaning.partOfSpeech || "").toLowerCase(),
                        text: plain(d.definition),
                        example: plain(d.example || "")
                    });
            });
        });
    });
    return {
        word: first.word || "",
        phonetic: phonetic,
        senses: senses.slice(0, MOST),
        source: "dictionaryapi"
    };
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
    var found = Array.isArray(data) ? fromDictionaryApi(data) : fromWiktionary(data);
    if (!found || !found.senses.length)
        return null;
    if (!found.word)
        found.word = word || "";
    return found;
}

function pageUrl(word) {
    return "https://en.wiktionary.org/wiki/" + encodeURIComponent(String(word || "").replace(/ /g, "_"));
}
