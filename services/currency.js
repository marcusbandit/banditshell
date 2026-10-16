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

var UNIT = "[a-zA-Z]{2,8}\\.?|[€$£¥₹₩₺₪฿₱]|zł|r\\$";
var AMOUNT = "[\\d.,+\\-−\\u2013*×÷/()\\s]*\\d[\\d.,+\\-−\\u2013*×÷/()\\s]*";
var TARGET = new RegExp(`^(.*?)(?:\\s+(?:to|in|til|i)\\s+|\\s*(?:->|→|=)\\s*)(${UNIT})\\s*$`, "i");
var WHOLE = new RegExp(`^(${UNIT})?\\s*(${AMOUNT})\\s*(${UNIT})?$`, "i");
var TERM = new RegExp(`^\\s*([+\\-−\\u2013])?\\s*(${UNIT})?\\s*(\\d+(?:[.,]\\d+)?)\\s*(${UNIT})?`, "i");

function single(before, after, known, home) {
    const a = before ? codeOf(before, known, home) : "";
    const b = after ? codeOf(after, known, home) : "";
    if ((before && !a) || (after && !b) || (a && b))
        return "";
    return a || b;
}

function terms(source, known, home) {
    const out = [];
    let rest = source;
    while (rest.trim()) {
        const m = TERM.exec(rest);
        if (!m || (out.length > 0) !== !!m[1])
            return null;
        const from = single(m[2], m[4], known, home);
        if (!from)
            return null;
        out.push({
            amount: parseFloat(m[3].replace(",", ".")) * (m[1] && m[1] !== "+" ? -1 : 1),
            from: from
        });
        rest = rest.slice(m[0].length);
    }
    return out.length > 1 ? out : null;
}

function parse(text, known, home, evaluate) {
    const t = String(text || "").trim();
    const aimed = TARGET.exec(t);
    const source = aimed ? aimed[1].trim() : t;
    const target = aimed ? codeOf(aimed[2], known, home) : "";
    if (aimed && !target)
        return null;
    const to = target || home;
    if (!to)
        return null;

    const whole = WHOLE.exec(source);
    if (whole) {
        const from = single(whole[1], whole[3], known, home);
        if (!from)
            return null;
        const expression = whole[2].trim().replace(/,/g, ".");
        const plain = /^\d+(\.\d+)?$/.test(expression);
        const amount = plain ? parseFloat(expression) : evaluate ? evaluate(expression) : NaN;
        if (typeof amount !== "number" || !isFinite(amount) || (from === to && plain && !target))
            return null;
        return {
            terms: [
                {
                    amount: amount,
                    from: from
                }
            ],
            to: to,
            worked: !plain
        };
    }

    const many = terms(source, known, home);
    return many ? {
        terms: many,
        to: to,
        worked: true
    } : null;
}

function convert(amount, from, to, rates) {
    const a = from === "EUR" ? 1 : rates[from];
    const b = to === "EUR" ? 1 : rates[to];
    if (!a || !b)
        return NaN;
    return amount / a * b;
}

function total(ask, rates) {
    return ask.terms.reduce((sum, t) => sum + convert(t.amount, t.from, ask.to, rates), 0);
}

function places(value) {
    return Math.abs(value) >= 1 || value === 0 || !isFinite(value) ? 2 : Math.min(8, 1 - Math.floor(Math.log10(Math.abs(value))));
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
