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

var NAME = /^[A-Za-z_][A-Za-z_0-9]*$/;

function written(n) {
    const s = String(n);
    return /e/i.test(s) ? n.toFixed(20) : s;
}

function namesIn(text) {
    return String(text).match(/[A-Za-z_][A-Za-z_0-9]*/g) || [];
}

function substitute(expr, vars) {
    let missing = false;
    const out = String(expr).replace(/(\d|\))?(\s*)([A-Za-z_][A-Za-z_0-9]*)/g, (whole, before, gap, name) => {
        if (!(name in vars)) {
            missing = true;
            return whole;
        }
        return `${before ? `${before}×` : gap}(${written(vars[name])})`;
    });
    return missing ? null : out;
}

function valueOf(expr, vars, evaluate, loose) {
    const plain = substitute(expr, vars);
    if (plain === null)
        return null;
    const got = loose ? lenient(plain, evaluate) : evaluate(plain);
    return got && typeof got.value === "number" && isFinite(got.value) ? got.value : null;
}

function solve(left, right, name, vars, evaluate) {
    const f = x => {
        const at = Object.assign({}, vars);
        at[name] = x;
        const a = valueOf(left, at, evaluate, false);
        const b = valueOf(right, at, evaluate, false);
        return a === null || b === null ? null : a - b;
    };
    const f0 = f(0), f1 = f(1), f2 = f(2);
    if (f0 === null || f1 === null || f2 === null)
        return null;
    const slope = f1 - f0;
    if (Math.abs(slope) < 1e-12 || Math.abs(f2 - f0 - 2 * slope) > 1e-9 * Math.max(1, Math.abs(slope)))
        return null;
    return -f0 / slope;
}

function program(text, evaluate, format) {
    const t = String(text || "").trim();
    if (!t || t[0] === "=" || !/[=;]/.test(t) || /==|[<>!]=/.test(t))
        return null;
    const parts = t.split(";").map(s => s.trim()).filter(s => !!s);
    const vars = {
        pi: Math.PI,
        e: Math.E
    };
    let last = null;
    for (let i = 0; i < parts.length; i++) {
        const loose = i === parts.length - 1;
        const sides = parts[i].split("=");
        if (sides.length > 2)
            return null;
        if (sides.length === 1) {
            const v = valueOf(sides[0], vars, evaluate, loose);
            if (v === null)
                return null;
            last = {
                value: v,
                text: format(v)
            };
            continue;
        }
        const left = sides[0].trim();
        const right = sides[1].trim();
        if (!left || !right)
            return null;
        if (NAME.test(left) && namesIn(right).indexOf(left) < 0) {
            const v = valueOf(right, vars, evaluate, loose);
            if (v === null)
                return null;
            vars[left] = v;
            last = {
                value: v,
                text: `${left} = ${format(v)}`
            };
            continue;
        }
        const unknown = namesIn(`${left} ${right}`).filter((n, k, all) => !(n in vars) && all.indexOf(n) === k);
        if (unknown.length > 1)
            return null;
        if (unknown.length === 1) {
            const x = solve(left, right, unknown[0], vars, evaluate);
            if (x === null || !isFinite(x))
                return null;
            vars[unknown[0]] = x;
            last = {
                value: x,
                text: `${unknown[0]} = ${format(x)}`
            };
            continue;
        }
        const a = valueOf(left, vars, evaluate, false);
        const b = valueOf(right, vars, evaluate, false);
        if (a === null || b === null)
            return null;
        last = {
            value: a === b ? 1 : 0,
            text: Math.abs(a - b) <= 1e-12 * Math.max(1, Math.abs(a)) ? "true" : "false"
        };
    }
    return last;
}
