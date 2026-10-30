.pragma library

const GROUND = 0.99;
const INK = 0.16;
const CURVE = 1.6;
const PIVOT = 0.62;
const WARNING_FLOOR = 0.52;
const READABLE = 4.5;

function channel(hex, shift) {
    return (parseInt(hex.slice(1), 16) >> shift & 255) / 255;
}

function linear(c) {
    return c <= 0.04045 ? c / 12.92 : Math.pow((c + 0.055) / 1.055, 2.4);
}

function encoded(c) {
    const k = Math.max(0, Math.min(1, c));
    return k <= 0.0031308 ? 12.92 * k : 1.055 * Math.pow(k, 1 / 2.4) - 0.055;
}

function toLch(hex) {
    const r = linear(channel(hex, 16));
    const g = linear(channel(hex, 8));
    const b = linear(channel(hex, 0));
    const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
    const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
    const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
    const L = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s;
    const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
    const B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
    return { l: L, c: Math.hypot(A, B), h: Math.atan2(B, A) };
}

function rawRgb(L, C, H) {
    const A = C * Math.cos(H);
    const B = C * Math.sin(H);
    const l = Math.pow(L + 0.3963377774 * A + 0.2158037573 * B, 3);
    const m = Math.pow(L - 0.1055613458 * A - 0.0638541728 * B, 3);
    const s = Math.pow(L - 0.0894841775 * A - 1.2914855480 * B, 3);
    return [4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s];
}

function inGamut(rgb) {
    return rgb.every(v => v >= -0.0001 && v <= 1.0001);
}

function fromLch(L, C, H) {
    let chroma = C;
    if (!inGamut(rawRgb(L, C, H))) {
        let lo = 0;
        let hi = C;
        for (let i = 0; i < 20; i++) {
            const mid = (lo + hi) / 2;
            if (inGamut(rawRgb(L, mid, H)))
                lo = mid;
            else
                hi = mid;
        }
        chroma = lo;
    }
    return "#" + rawRgb(L, chroma, H).map(v => Math.round(encoded(v) * 255).toString(16).padStart(2, "0")).join("");
}

function lightRamp(ramp) {
    const stops = ramp.map(toLch);
    const ground = Math.min(...stops.map(s => s.l));
    const reach = Math.max(0.0001, Math.max(...stops.map(s => s.l)) - ground);
    return stops.map(s => {
        const t = Math.max(0, Math.min(1, (s.l - ground) / reach));
        return fromLch(GROUND - (GROUND - INK) * Math.pow(t, CURVE), s.c, s.h);
    });
}

function lightAccent(hex, floor) {
    const s = toLch(hex);
    return fromLch(Math.max(floor ?? 0.2, Math.min(0.75, 2 * PIVOT - s.l)), s.c * (floor ? 1.6 : 1), s.h);
}

function lightTheme(theme) {
    return {
        name: theme.name,
        ramp: lightRamp(theme.ramp.map(String)),
        dim: lightAccent(String(theme.dim)),
        mid: lightAccent(String(theme.mid)),
        bright: lightAccent(String(theme.bright)),
        alarm: lightAccent(String(theme.alarm)),
        brass: theme.brass ? lightAccent(String(theme.brass), WARNING_FLOOR) : undefined,
        error: theme.error ? lightAccent(String(theme.error), WARNING_FLOOR) : undefined
    };
}

const MODES = ["light", "dark", "auto"];

function modeOf(value) {
    return MODES.includes(value) ? value : "dark";
}

function isLight(mode, daylight) {
    const m = modeOf(mode);
    return m === "light" || (m === "auto" && daylight === true);
}

function lightCard(card) {
    const tone = (hex, l) => {
        const s = toLch(String(hex));
        return fromLch(l, s.c, s.h);
    };
    return Object.assign({}, card, {
        background: card.background ? tone(card.background, 0.96) : card.background,
        foreground: card.foreground ? tone(card.foreground, 0.3) : card.foreground,
        dim: lightAccent(String(card.dim)),
        mid: lightAccent(String(card.mid)),
        bright: lightAccent(String(card.bright)),
        alarm: lightAccent(String(card.alarm))
    });
}

function luminance(rgb) {
    return 0.2126 * linear(rgb[0]) + 0.7152 * linear(rgb[1]) + 0.0722 * linear(rgb[2]);
}

function over(top, alpha, under) {
    return top.map((t, i) => alpha * t + (1 - alpha) * under[i]);
}

function contrast(a, b) {
    const x = luminance(a);
    const y = luminance(b);
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05);
}

function worstContrast(surface, ink, label, alpha) {
    return Math.min(...[[0, 0, 0], [1, 1, 1]].map(behind => {
        const ground = over(surface, alpha, behind);
        return contrast(over(ink, label, ground), ground);
    }));
}

function readableAlpha(surface, ink, label, alpha) {
    const want = Math.min(READABLE, worstContrast(surface, ink, label, 1));
    let a = Math.max(0, Math.min(1, alpha));
    while (a < 1 && worstContrast(surface, ink, label, a) < want)
        a = Math.min(1, Math.round((a + 0.01) * 100) / 100);
    return a;
}
