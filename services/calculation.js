.pragma library

var CONVERSION_WORDS = /^(hex|hexadecimal|bin|binary|oct|octal|dec|decimal|duo|duodecimal|roman|sexa|sexagesimal|time|date|utc|unicode|factors|fraction|fractions|partial|base|bases|bijective|calendars|cis|polar|rectangular|optimal|prefix|mixed|si)\b/i;

function looksLikeCalculation(text) {
    const t = String(text || "").trim();
    if (!t)
        return false;
    if (t[0] === "=")
        return t.length > 1;
    if (/[+\-*/×÷^]$/.test(t) || !/\d/.test(t))
        return false;
    return /^[\d(.\-+√]/.test(t) || /^[a-z]\w*\s*\(/i.test(t) || /[+\-*/×÷^%!]/.test(t);
}

function qalcExpression(text) {
    return String(text || "").trim().replace(/^=\s*/, "").replace(/(\s)(to|->|→)\s+([^\s\-+].*)$/i, (whole, gap, word, target) => CONVERSION_WORDS.test(target) || /^\d/.test(target) ? whole : `${gap}${word} -${target}`);
}

function squeeze(text) {
    return String(text || "").replace(/\s+/g, "").toLowerCase();
}

function readQalc(output, text) {
    const lines = String(output || "").split("\n").map(l => l.trim()).filter(l => l && !/^(error|warning)\b/i.test(l));
    if (lines.length !== 1)
        return "";
    const out = lines[0].replace(/^"(.*)"$/, "$1");
    if (/[·×]|[A-Za-z]\(/.test(out) || squeeze(out) === squeeze(qalcExpression(text)) || squeeze(out) === squeeze(text))
        return "";
    return out;
}

var MATH_ONLY = /^[\d\s.+\-−–*×xX÷/()]+$/;

function mathOnly(text) {
    const t = String(text || "").trim();
    return !!t && MATH_ONLY.test(t) && /\d/.test(t);
}

function firm(text) {
    return /[+\-−–*×xX÷/()]/.test(String(text || "").replace(/^\s*[-−–]/, ""));
}

function lenient(text, evaluate) {
    let t = String(text || "").trim();
    while (t) {
        const open = (t.match(/\(/g) || []).length - (t.match(/\)/g) || []).length;
        const answer = evaluate(open > 0 ? t + ")".repeat(open) : t);
        if (answer)
            return answer;
        t = t.slice(0, -1).trim();
    }
    return null;
}
