.pragma library

var SYMBOLS = {
    "€": "EUR",
    "$": "USD",
    "£": "GBP",
    "¥": "JPY",
    "₹": "INR",
    "₩": "KRW",
    "₺": "TRY",
    "₪": "ILS",
    "฿": "THB",
    "₱": "PHP",
    "zł": "PLN",
    "r$": "BRL",
    "kč": "CZK",
    "ft": "HUF"
};

var NAMES = {
    euro: "EUR",
    euros: "EUR",
    dollar: "USD",
    dollars: "USD",
    pound: "GBP",
    pounds: "GBP",
    sterling: "GBP",
    yen: "JPY",
    franc: "CHF",
    francs: "CHF",
    zloty: "PLN",
    forint: "HUF",
    yuan: "CNY",
    rupee: "INR",
    rupees: "INR",
    won: "KRW",
    lira: "TRY",
    real: "BRL",
    reais: "BRL"
};

var KRONE = ["DKK", "NOK", "SEK", "ISK"];

function codeOf(word, known, home) {
    const w = String(word || "").trim().toLowerCase();
    if (!w)
        return "";
    if (SYMBOLS[w])
        return SYMBOLS[w];
    if (w === "kr" || w === "kr." || w === "krone" || w === "kroner" || w === "kronor" || w === "krona")
        return KRONE.indexOf(home) >= 0 ? home : "DKK";
    if (NAMES[w])
        return NAMES[w];
    const up = w.toUpperCase();
    return /^[A-Z]{3}$/.test(up) && known.indexOf(up) >= 0 ? up : "";
}

var UNIT = "([a-zA-Z]{2,8}\\.?|[€$£¥₹₩₺₪฿₱]|zł|r\\$)";
var NUMBER = "(\\d+(?:[.,]\\d+)?)";
var SHAPE = new RegExp(`^${UNIT}?\\s*${NUMBER}\\s*${UNIT}?(?:\\s*(?:to|in|til|i|->|→|=)\\s*${UNIT})?$`, "i");

function parse(text, known, home) {
    const m = SHAPE.exec(String(text || "").trim());
    if (!m)
        return null;
    const before = m[1] ? codeOf(m[1], known, home) : "";
    const after = m[3] ? codeOf(m[3], known, home) : "";
    if ((m[1] && !before) || (m[3] && !after) || (before && after))
        return null;
    const from = before || after;
    if (!from)
        return null;
    const target = m[4] ? codeOf(m[4], known, home) : "";
    if (m[4] && !target)
        return null;
    const to = target || home;
    if (!to || to === from)
        return null;
    return {
        amount: parseFloat(m[2].replace(",", ".")),
        from: from,
        to: to
    };
}

function convert(amount, from, to, rates) {
    const a = from === "EUR" ? 1 : rates[from];
    const b = to === "EUR" ? 1 : rates[to];
    if (!a || !b)
        return NaN;
    return amount / a * b;
}

function money(value) {
    if (!isFinite(value))
        return "?";
    const digits = Math.abs(value) >= 1 || value === 0 ? 2 : Math.min(8, 1 - Math.floor(Math.log10(Math.abs(value))));
    return value.toFixed(digits);
}

function readEcb(xml) {
    const text = String(xml || "");
    const day = /time=['"](\d{4}-\d{2}-\d{2})['"]/.exec(text);
    const rates = {};
    const pair = /currency=['"]([A-Z]{3})['"]\s+rate=['"]([\d.]+)['"]/g;
    let m;
    while ((m = pair.exec(text)) !== null)
        rates[m[1]] = parseFloat(m[2]);
    return day && Object.keys(rates).length ? {
        date: day[1],
        rates: rates
    } : null;
}
