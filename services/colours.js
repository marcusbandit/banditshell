.pragma library

function clamp(n, lo, hi) {
    return Math.min(hi, Math.max(lo, n));
}

function channel(text, scale) {
    const t = String(text).trim();
    if (!/^-?\d*\.?\d+%?$/.test(t))
        return NaN;
    return t.endsWith("%") ? parseFloat(t) / 100 * scale : parseFloat(t);
}

function fromHsl(h, s, l) {
    const k = n => (n + h / 30) % 12;
    const a = s * Math.min(l, 1 - l);
    const f = n => l - a * Math.max(-1, Math.min(k(n) - 3, 9 - k(n), 1));
    return [f(0) * 255, f(8) * 255, f(4) * 255];
}

function parseColour(text) {
    const t = String(text || "").trim().toLowerCase();
    let m = /^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/.exec(t);
    if (m) {
        const hex = m[1].length <= 4 ? m[1].split("").map(c => c + c).join("") : m[1];
        return {
            r: parseInt(hex.slice(0, 2), 16),
            g: parseInt(hex.slice(2, 4), 16),
            b: parseInt(hex.slice(4, 6), 16),
            a: hex.length === 8 ? parseInt(hex.slice(6, 8), 16) / 255 : 1,
            form: "hex"
        };
    }
    m = /^(rgba?|hsla?)\s*\(\s*([^)]*)\)$/.exec(t);
    if (!m)
        return null;
    const parts = m[2].split(/\s*[,/]\s*|\s+/).filter(Boolean);
    if (parts.length < 3 || parts.length > 4)
        return null;
    const alpha = parts.length === 4 ? channel(parts[3], 1) : 1;
    if (m[1].startsWith("rgb")) {
        const [r, g, b] = parts.slice(0, 3).map(p => channel(p, 255));
        if ([r, g, b, alpha].some(n => !isFinite(n)) || [r, g, b].some(n => n < 0 || n > 255) || alpha < 0 || alpha > 1)
            return null;
        return {
            r: r,
            g: g,
            b: b,
            a: alpha,
            form: "rgb"
        };
    }
    const h = parseFloat(parts[0]);
    const s = channel(parts[1], 1), l = channel(parts[2], 1);
    if ([h, s, l, alpha].some(n => !isFinite(n)) || s < 0 || s > 1 || l < 0 || l > 1 || alpha < 0 || alpha > 1)
        return null;
    const [r, g, b] = fromHsl(((h % 360) + 360) % 360, s, l);
    return {
        r: r,
        g: g,
        b: b,
        a: alpha,
        form: "hsl"
    };
}

function two(n) {
    return Math.round(clamp(n, 0, 255)).toString(16).padStart(2, "0");
}

function hexOf(c) {
    return `#${two(c.r)}${two(c.g)}${two(c.b)}${c.a < 1 ? two(c.a * 255) : ""}`;
}

function alphaText(a) {
    return String(Math.round(a * 100) / 100);
}

function rgbOf(c) {
    const rgb = [c.r, c.g, c.b].map(n => Math.round(clamp(n, 0, 255))).join(", ");
    return c.a < 1 ? `rgba(${rgb}, ${alphaText(c.a)})` : `rgb(${rgb})`;
}

function hslOf(c) {
    const r = c.r / 255, g = c.g / 255, b = c.b / 255;
    const hi = Math.max(r, g, b), lo = Math.min(r, g, b);
    const l = (hi + lo) / 2;
    const d = hi - lo;
    const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
    let h = 0;
    if (d !== 0)
        h = hi === r ? 60 * (((g - b) / d) % 6) : hi === g ? 60 * ((b - r) / d + 2) : 60 * ((r - g) / d + 4);
    const parts = `${Math.round((h + 360) % 360)}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%`;
    return c.a < 1 ? `hsla(${parts}, ${alphaText(c.a)})` : `hsl(${parts})`;
}

var FORMS = {
    hex: hexOf,
    rgb: rgbOf,
    rgba: rgbOf,
    hsl: hslOf,
    hsla: hslOf
};

function colourAnswer(text) {
    const m = /^(.+?)(?:\s+(?:to|in|as|->|→)\s+(hex|rgba?|hsla?))?\s*$/i.exec(String(text || "").trim());
    const c = m ? parseColour(m[1]) : null;
    if (!c)
        return null;
    const want = m[2] ? m[2].toLowerCase().replace(/a$/, "") : c.form === "hex" ? "rgb" : "hex";
    const others = ["hex", "rgb", "hsl"].filter(f => f !== want && f !== c.form);
    return {
        text: FORMS[want](c),
        detail: others.map(f => FORMS[f](c)).join(" · "),
        swatch: `#${c.a < 1 ? two(c.a * 255) : ""}${two(c.r)}${two(c.g)}${two(c.b)}`
    };
}
