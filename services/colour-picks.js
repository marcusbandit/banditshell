.pragma library

var PICK = /^(?:pick(?:\s+an?)?(?:\s+colou?r)?|colou?r\s*picker|pick\s+colou?rs?|hyprpicker|eye\s*dropper|colou?r\s+pick(?:er)?)$/i;

var HISTORY = /^(?:colou?rs|colou?r\s+history|picked\s+colou?rs|recent\s+colou?rs|my\s+colou?rs)$/i;

var HEX = /#?([0-9a-f]{6}|[0-9a-f]{8})\b/i;

function colourAsk(text) {
    var t = String(text || "").trim();
    if (PICK.test(t))
        return "pick";
    if (HISTORY.test(t))
        return "history";
    return "";
}

function readPicked(output) {
    var m = HEX.exec(String(output || "").replace(/\x1b\[[0-9;]*m/g, ""));
    return m ? `#${m[1].slice(0, 6).toLowerCase()}` : "";
}

function remember(history, hex, at, limit) {
    var lower = String(hex || "").toLowerCase();
    if (!lower)
        return history || [];
    return [{
            hex: lower,
            at: at
        }].concat((history || []).filter(h => h.hex !== lower)).slice(0, Math.max(1, limit || 12));
}

function forget(history, hex) {
    return (history || []).filter(h => h.hex !== hex);
}

function readHistory(text, limit) {
    var parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return [];
    }
    var list = Array.isArray(parsed) ? parsed : Array.isArray(parsed?.picks) ? parsed.picks : [];
    return list.filter(h => h && /^#[0-9a-f]{6}$/.test(h.hex)).map(h => ({
                hex: h.hex,
                at: Number(h.at) || 0
            })).slice(0, Math.max(1, limit || 12));
}
