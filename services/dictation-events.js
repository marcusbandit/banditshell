.pragma library

function read(line) {
    let msg;
    try {
        msg = JSON.parse(line);
    } catch (e) {
        return null;
    }
    if (!msg || typeof msg !== "object" || Array.isArray(msg))
        return null;
    const phase = typeof msg.phase === "string" ? msg.phase : null;
    return {
        phase: phase,
        lang: typeof msg.lang === "string" ? msg.lang : null,
        level: typeof msg.level === "number" ? msg.level : null,
        canCancel: msg.cancel === true,
        cancelled: msg.cancelled === true && phase === "idle",
        typed: typeof msg.typed === "boolean" ? msg.typed : null
    };
}

function outcome(typed) {
    if (typed === false)
        return "Dictation discarded";
    if (typed === true)
        return "Partly kept";
    return "Dictation discarded";
}

function startKey(binds) {
    var found = (binds || []).find(function (b) {
        return b && b.chord && /(^|[\s/;&|])voice(\s|$)/.test(b.cmd || "") && !/\bvoice\s+(cancel|stop|down|retype)\b/.test(b.cmd || "");
    });
    if (!found)
        return "";
    return String(found.chord).split("+").map(function (p) {
        return p.trim();
    }).filter(Boolean).map(function (p) {
        return p.length <= 1 ? p : p.charAt(0) + p.slice(1).toLowerCase();
    }).join(" + ");
}

var OUTPUTS = [["auto", "Automatic"], ["type", "Type it"], ["paste", "Paste it"], ["copy", "Only copy it"]];

var LANGUAGES = [["auto", "Detect it"], ["en-dk", "English (Denmark)"], ["en", "English (US)"], ["en-gb", "English (UK)"], ["da", "Danish"], ["ja", "Japanese"], ["de", "German"], ["sv", "Swedish"], ["no", "Norwegian"]];

var LANGUAGE_TAGS = { "da-DK": "da", "en-DK": "en-dk", "en-US": "en", "en-GB": "en-gb", "de-DE": "de", "sv-SE": "sv", "nb-NO": "no" };

function languageCode(tag) {
    if (!tag)
        return "auto";
    return LANGUAGE_TAGS[tag] || String(tag).toLowerCase();
}

function dictationSettings(raw) {
    var data = {};
    try {
        data = JSON.parse(raw);
    } catch (e) {}
    if (!data || typeof data !== "object" || Array.isArray(data))
        data = {};
    var out = OUTPUTS.some(function (o) {
        return o[0] === data.output;
    }) ? data.output : "auto";
    return {
        output: out,
        microphone: typeof data.microphone === "string" && data.microphone ? data.microphone : "default"
    };
}

function asking(text) {
    var typed = String(text || "").trim();
    if (!typed || /^(\?+|ask(\s|$))/i.test(typed))
        return null;
    return "ask " + typed;
}
