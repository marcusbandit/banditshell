.pragma library

// G2-continuous ("squircle") corner geometry.
//
// A normal rounded rectangle is G1: the straight edge meets the circular arc with
// an instant jump in curvature from 0 to 1/r, which the eye reads as a pinch. A G2
// corner shrinks the arc to less than 90 degrees and spends the leftover corner
// budget on a cubic Bezier either side, ramping curvature 0 -> 1/r -> 0.
//
// This is the Figma corner-smoothing construction. See ~/.claude/rules/g2-corners.md.

function toRad(deg) {
    return deg * Math.PI / 180;
}

// Geometry of one corner, given its radius and a smoothing factor in [0, 1].
//   p    - how far down each adjacent side the corner reaches
//   arc  - chord length of the (shortened) circular arc
//   a b c d - the Bezier control offsets that ease curvature in and out
function corner(radius, smoothing) {
    if (radius <= 0)
        return {
            r: 0,
            a: 0,
            b: 0,
            c: 0,
            d: 0,
            p: 0,
            arc: 0
        };

    const p = (1 + smoothing) * radius;
    const arcMeasure = 90 * (1 - smoothing);           // degrees left for the true arc
    const arc = Math.sin(toRad(arcMeasure / 2)) * radius * Math.SQRT2;

    const alpha = (90 - arcMeasure) / 2;
    const p3p4 = radius * Math.tan(toRad(alpha / 2));

    const beta = 45 * smoothing;
    const c = p3p4 * Math.cos(toRad(beta));
    const d = c * Math.tan(toRad(beta));

    const b = (p - arc - c - d) / 3;
    const a = 2 * b;

    return {
        r: radius,
        a: a,
        b: b,
        c: c,
        d: d,
        p: p,
        arc: arc
    };
}

// Two corners share a side. If together they want more than the side is long,
// scale both down proportionally rather than letting either one win.
function share(r1, r2, len) {
    const total = r1 + r2;
    if (total <= len || total <= 0)
        return [r1, r2];
    const k = len / total;
    return [r1 * k, r2 * k];
}

// How much room each corner actually gets: the smaller of its two sides' allowances.
function budgets(tl, tr, br, bl, w, h) {
    const top = share(tl, tr, w);
    const bottom = share(bl, br, w);
    const left = share(tl, bl, h);
    const right = share(tr, br, h);
    return {
        tl: Math.min(top[0], left[0]),
        tr: Math.min(top[1], right[0]),
        br: Math.min(bottom[1], right[1]),
        bl: Math.min(bottom[0], left[1])
    };
}

// Fit a corner into its budget. Radius is preserved where possible and smoothing
// is what degrades, because a slightly less smooth corner reads better than a
// visibly wrong radius.
function fit(radius, smoothing, budget) {
    const r = Math.max(0, Math.min(radius, budget));
    if (r <= 0)
        return corner(0, 0);
    const s = Math.max(0, Math.min(smoothing, budget / r - 1));
    return corner(r, s);
}

function n(x) {
    return Math.round(x * 1000) / 1000;
}

function seq() {
    const parts = [];
    for (let i = 0; i < arguments.length; i++)
        parts.push(n(arguments[i]));
    return parts.join(" ");
}

// Full closed path, drawn clockwise starting on the top edge.
function path(w, h, tl, tr, br, bl, smoothing) {
    if (w <= 0 || h <= 0)
        return "";

    const s = Math.max(0, Math.min(1, smoothing));
    const bud = budgets(tl, tr, br, bl, w, h);
    const TL = fit(tl, s, bud.tl);
    const TR = fit(tr, s, bud.tr);
    const BR = fit(br, s, bud.br);
    const BL = fit(bl, s, bud.bl);

    let out = "M " + seq(w - TR.p, 0);

    // top-right
    out += TR.r ? " c " + seq(TR.a, 0, TR.a + TR.b, 0, TR.a + TR.b + TR.c, TR.d) + " a " + seq(TR.r, TR.r) + " 0 0 1 " + seq(TR.arc, TR.arc) + " c " + seq(TR.d, TR.c, TR.d, TR.b + TR.c, TR.d, TR.a + TR.b + TR.c) : "";

    out += " L " + seq(w, h - BR.p);

    // bottom-right
    out += BR.r ? " c " + seq(0, BR.a, 0, BR.a + BR.b, -BR.d, BR.a + BR.b + BR.c) + " a " + seq(BR.r, BR.r) + " 0 0 1 " + seq(-BR.arc, BR.arc) + " c " + seq(-BR.c, BR.d, -(BR.b + BR.c), BR.d, -(BR.a + BR.b + BR.c), BR.d) : "";

    out += " L " + seq(BL.p, h);

    // bottom-left
    out += BL.r ? " c " + seq(-BL.a, 0, -(BL.a + BL.b), 0, -(BL.a + BL.b + BL.c), -BL.d) + " a " + seq(BL.r, BL.r) + " 0 0 1 " + seq(-BL.arc, -BL.arc) + " c " + seq(-BL.d, -BL.c, -BL.d, -(BL.b + BL.c), -BL.d, -(BL.a + BL.b + BL.c)) : "";

    out += " L " + seq(0, TL.p);

    // top-left
    out += TL.r ? " c " + seq(0, -TL.a, 0, -(TL.a + TL.b), TL.d, -(TL.a + TL.b + TL.c)) + " a " + seq(TL.r, TL.r) + " 0 0 1 " + seq(TL.arc, -TL.arc) + " c " + seq(TL.c, -TL.d, TL.b + TL.c, -TL.d, TL.a + TL.b + TL.c, -TL.d) : "";

    return out + " Z";
}
