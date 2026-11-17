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

function toLinear(c) {
    const v = c / 255;
    return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
}

function fromLinear(v) {
    const c = v <= 0.0031308 ? v * 12.92 : 1.055 * Math.pow(Math.max(v, 0), 1 / 2.4) - 0.055;
    return c * 255;
}

var D50 = [0.96422, 1, 0.82521];
var LAB_EPSILON = 216 / 24389;
var LAB_KAPPA = 24389 / 27;

function labOf(c) {
    const r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b);
    const xyz = [
        0.4360747 * r + 0.3850649 * g + 0.1430804 * b,
        0.2225045 * r + 0.7168786 * g + 0.0606169 * b,
        0.0139322 * r + 0.0971045 * g + 0.7141733 * b
    ].map((v, i) => v / D50[i]).map(t => t > LAB_EPSILON ? Math.cbrt(t) : (LAB_KAPPA * t + 16) / 116);
    return [116 * xyz[1] - 16, 500 * (xyz[0] - xyz[1]), 200 * (xyz[1] - xyz[2])];
}

function fromLab(L, a, b) {
    const fy = (L + 16) / 116;
    const fx = a / 500 + fy;
    const fz = fy - b / 200;
    const x = (fx * fx * fx > LAB_EPSILON ? fx * fx * fx : (116 * fx - 16) / LAB_KAPPA) * D50[0];
    const y = L > LAB_KAPPA * LAB_EPSILON ? fy * fy * fy : L / LAB_KAPPA;
    const z = (fz * fz * fz > LAB_EPSILON ? fz * fz * fz : (116 * fz - 16) / LAB_KAPPA) * D50[2];
    return [
        fromLinear(3.1338561 * x - 1.6168667 * y - 0.4906146 * z),
        fromLinear(-0.9787684 * x + 1.9161415 * y + 0.0334540 * z),
        fromLinear(0.0719453 * x - 0.2289914 * y + 1.4052427 * z)
    ];
}

function oklabOf(c) {
    const r = toLinear(c.r), g = toLinear(c.g), b = toLinear(c.b);
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    return [
        0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
        1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
        0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
    ];
}

function fromOklab(L, a, b) {
    const l = Math.pow(L + 0.3963377774 * a + 0.2158037573 * b, 3);
    const m = Math.pow(L - 0.1055613458 * a - 0.0638541728 * b, 3);
    const s = Math.pow(L - 0.0894841775 * a - 1.2914855480 * b, 3);
    return [
        fromLinear(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
        fromLinear(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
        fromLinear(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
    ];
}

function polar(a, b) {
    const h = Math.atan2(b, a) * 180 / Math.PI;
    return [Math.sqrt(a * a + b * b), (h + 360) % 360];
}

function cartesian(chroma, hue) {
    const h = hue * Math.PI / 180;
    return [chroma * Math.cos(h), chroma * Math.sin(h)];
}

function fromHwb(h, w, b) {
    if (w + b >= 1) {
        const grey = w / (w + b) * 255;
        return [grey, grey, grey];
    }
    return fromHsl(h, 1, 0.5).map(v => v * (1 - w - b) + w * 255);
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
    m = /^(rgba?|hsla?|hwb|oklab|oklch|lab|lch)\s*\(\s*([^)]*)\)$/.exec(t);
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
    if (!m[1].startsWith("hsl"))
        return parseModern(m[1], parts, alpha);
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

function parseModern(name, parts, alpha) {
    if (!isFinite(alpha) || alpha < 0 || alpha > 1)
        return null;
    const hue = text => /^-?\d*\.?\d+(?:deg)?$/.test(text) ? ((parseFloat(text) % 360) + 360) % 360 : NaN;
    let rgb;
    if (name === "hwb") {
        const h = hue(parts[0]);
        const w = channel(parts[1], 1), b = channel(parts[2], 1);
        if ([h, w, b].some(n => !isFinite(n)) || w < 0 || w > 1 || b < 0 || b > 1)
            return null;
        rgb = fromHwb(h, w, b);
    } else if (name === "lab" || name === "oklab") {
        const ok = name === "oklab";
        const L = channel(parts[0], ok ? 1 : 100);
        const a = channel(parts[1], ok ? 0.4 : 125), b = channel(parts[2], ok ? 0.4 : 125);
        if ([L, a, b].some(n => !isFinite(n)) || L < 0 || L > (ok ? 1 : 100))
            return null;
        rgb = ok ? fromOklab(L, a, b) : fromLab(L, a, b);
    } else {
        const ok = name === "oklch";
        const L = channel(parts[0], ok ? 1 : 100);
        const C = channel(parts[1], ok ? 0.4 : 150);
        const h = hue(parts[2]);
        if ([L, C, h].some(n => !isFinite(n)) || L < 0 || L > (ok ? 1 : 100) || C < 0)
            return null;
        const [a, b] = cartesian(C, h);
        rgb = ok ? fromOklab(L, a, b) : fromLab(L, a, b);
    }
    return {
        r: clamp(rgb[0], 0, 255),
        g: clamp(rgb[1], 0, 255),
        b: clamp(rgb[2], 0, 255),
        a: alpha,
        form: name
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
    const parts = `${Math.round((h + 360) % 360) % 360}, ${Math.round(s * 100)}%, ${Math.round(l * 100)}%`;
    return c.a < 1 ? `hsla(${parts}, ${alphaText(c.a)})` : `hsl(${parts})`;
}

function decimals(n, places) {
    const v = Math.round(n * Math.pow(10, places)) / Math.pow(10, places);
    return String(Object.is(v, -0) ? 0 : v);
}

function slash(c) {
    return c.a < 1 ? ` / ${alphaText(c.a)}` : "";
}

function hwbOf(c) {
    const r = c.r / 255, g = c.g / 255, b = c.b / 255;
    const hue = /^hsl\((\d+)/.exec(hslOf({ r: c.r, g: c.g, b: c.b, a: 1 }));
    return `hwb(${hue[1]} ${Math.round(Math.min(r, g, b) * 100)}% ${Math.round((1 - Math.max(r, g, b)) * 100)}%${slash(c)})`;
}

function labText(c) {
    const [L, a, b] = labOf(c);
    return `lab(${decimals(L, 2)}% ${decimals(a, 2)} ${decimals(b, 2)}${slash(c)})`;
}

function lchText(c) {
    const [L, a, b] = labOf(c);
    const [C, h] = polar(a, b);
    return `lch(${decimals(L, 2)}% ${decimals(C, 2)} ${decimals(C < 0.5 ? 0 : h, 2)}${slash(c)})`;
}

function oklabText(c) {
    const [L, a, b] = oklabOf(c);
    return `oklab(${decimals(L, 3)} ${decimals(a, 3)} ${decimals(b, 3)}${slash(c)})`;
}

function oklchText(c) {
    const [L, a, b] = oklabOf(c);
    const [C, h] = polar(a, b);
    return `oklch(${decimals(L, 3)} ${decimals(C, 3)} ${decimals(C < 0.004 ? 0 : h, 1)}${slash(c)})`;
}

var FORMS = {
    hwb: hwbOf,
    lab: labText,
    lch: lchText,
    oklab: oklabText,
    oklch: oklchText,
    hex: hexOf,
    rgb: rgbOf,
    rgba: rgbOf,
    hsl: hslOf,
    hsla: hslOf
};

function colourAnswer(text) {
    const m = /^(.+?)(?:\s+(?:to|in|as|->|→)\s+(hex|rgba?|hsla?|hwb|oklab|oklch|lab|lch))?\s*$/i.exec(String(text || "").trim());
    const c = m ? parseColour(m[1]) : null;
    if (!c)
        return null;
    const want = m[2] ? m[2].toLowerCase().replace(/a$/, "") : c.form === "hex" ? "rgb" : "hex";
    const others = ["hex", "rgb", "hsl", "oklch"].filter(f => f !== want && f !== c.form);
    return {
        text: FORMS[want](c),
        detail: others.map(f => FORMS[f](c)).join(" · "),
        swatch: `#${c.a < 1 ? two(c.a * 255) : ""}${two(c.r)}${two(c.g)}${two(c.b)}`
    };
}

function withColour(text, hex) {
    const m = /^(.+?)((?:\s+(?:to|in|as|->|→)\s+(?:hex|rgba?|hsla?|hwb|oklab|oklch|lab|lch))?)$/i.exec(String(text || "").trim());
    const was = m ? parseColour(m[1]) : null;
    const c = parseColour(hex);
    if (!was || !c)
        return "";
    return FORMS[was.form](c) + m[2];
}
