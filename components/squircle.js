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

// Two corners share a side. Each gets a slice of it in proportion to how much
// it asked for, so the bigger radius keeps the bigger allowance when they
// collide. This is an allowance along the SIDE, not a radius: a corner may spend
// it on radius and on smoothing both.
function share(r1, r2, len) {
    const total = r1 + r2;
    if (total <= 0)
        return [len / 2, len / 2];
    return [len * r1 / total, len * r2 / total];
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


// Fit a corner into its budget. The radius is preserved where possible and the
// smoothing is what degrades, because a slightly less smooth corner reads better
// than a visibly wrong radius. A negative radius means a CONCAVE corner.
function fit(radius, smoothing, budget) {
    const r = Math.min(Math.abs(radius), budget);
    const k = r <= 0 ? corner(0, 0) : corner(r, Math.max(0, Math.min(smoothing, budget / r - 1)));
    k.concave = radius < 0;
    return k;
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

// How far a corner reaches along each of its two sides. Anything sizing itself
// around a concave corner needs this: the flare is exactly this wide.
function extent(radius, smoothing) {
    return (1 + Math.max(0, Math.min(1, smoothing))) * Math.abs(radius);
}

// CONVEX (positive radius) cuts the corner off the bounding box: the shape pulls
// away from its own corner. Right for a floating card.
//
// CONCAVE (negative radius) does the reverse: the side pulls IN by p, and the
// corner flares back OUT to touch the bounding-box corner, arriving tangent to
// the perpendicular edge. That is what you want where a panel meets a screen
// edge, because the panel then sweeps into the edge instead of curling away from
// it and leaving a notch of dead space at the very corner.
//
// A concave corner is the convex path mirrored in x, which also flips the arc's
// sweep flag. Both are written out per corner rather than generated, because the
// four corners enter and leave on different axes and a clever generator here is
// harder to check than twelve literal numbers.
function segment(k, which) {
    if (k.r <= 0)
        return "";

    const abc = k.a + k.b + k.c;
    const ab = k.a + k.b;
    const bc = k.b + k.c;
    const arcTo = (sx, sy, sweep) => " a " + seq(k.r, k.r) + " 0 0 " + sweep + " " + seq(sx * k.arc, sy * k.arc);

    switch (which) {
    // enters travelling +x along the top edge, leaves travelling +y
    case "tr":
        return k.concave ? " c " + seq(-k.a, 0, -ab, 0, -abc, k.d) + arcTo(-1, 1, 0) + " c " + seq(-k.d, k.c, -k.d, bc, -k.d, abc) : " c " + seq(k.a, 0, ab, 0, abc, k.d) + arcTo(1, 1, 1) + " c " + seq(k.d, k.c, k.d, bc, k.d, abc);

    // enters travelling +y down the right edge, leaves travelling -x
    case "br":
        return k.concave ? " c " + seq(0, k.a, 0, ab, k.d, abc) + arcTo(1, 1, 0) + " c " + seq(k.c, k.d, bc, k.d, abc, k.d) : " c " + seq(0, k.a, 0, ab, -k.d, abc) + arcTo(-1, 1, 1) + " c " + seq(-k.c, k.d, -bc, k.d, -abc, k.d);

    // enters travelling -x along the bottom edge, leaves travelling -y
    case "bl":
        return k.concave ? " c " + seq(k.a, 0, ab, 0, abc, -k.d) + arcTo(1, -1, 0) + " c " + seq(k.d, -k.c, k.d, -bc, k.d, -abc) : " c " + seq(-k.a, 0, -ab, 0, -abc, -k.d) + arcTo(-1, -1, 1) + " c " + seq(-k.d, -k.c, -k.d, -bc, -k.d, -abc);

    // enters travelling -y up the left edge, leaves travelling +x
    case "tl":
        return k.concave ? " c " + seq(0, -k.a, 0, -ab, -k.d, -abc) + arcTo(-1, -1, 0) + " c " + seq(-k.c, -k.d, -bc, -k.d, -abc, -k.d) : " c " + seq(0, -k.a, 0, -ab, k.d, -abc) + arcTo(1, -1, 1) + " c " + seq(k.c, -k.d, bc, -k.d, abc, -k.d);
    }
    return "";
}

// Where each corner starts and finishes, in absolute coordinates. The straight
// sides are just the lines between one corner's exit and the next one's entry,
// so a concave corner automatically pulls its side inwards.
function ends(k, which, w, h) {
    const p = k.p;
    switch (which) {
    case "tr":
        return k.concave ? [[w, 0], [w - p, p]] : [[w - p, 0], [w, p]];
    case "br":
        return k.concave ? [[w - p, h - p], [w, h]] : [[w, h - p], [w - p, h]];
    case "bl":
        return k.concave ? [[0, h], [p, h - p]] : [[p, h], [0, h - p]];
    case "tl":
        return k.concave ? [[p, p], [0, 0]] : [[0, p], [p, 0]];
    }
}

// Full closed path, drawn clockwise starting on the top edge.
function path(w, h, tl, tr, br, bl, smoothing) {
    if (w <= 0 || h <= 0)
        return "";

    const s = Math.max(0, Math.min(1, smoothing));
    const bud = budgets(Math.abs(tl), Math.abs(tr), Math.abs(br), Math.abs(bl), w, h);

    const order = [["tr", fit(tr, s, bud.tr)], ["br", fit(br, s, bud.br)], ["bl", fit(bl, s, bud.bl)], ["tl", fit(tl, s, bud.tl)]];

    const geom = order.map(([which, k]) => {
        const e = ends(k, which, w, h);
        return {
            entry: e[0],
            exit: e[1],
            seg: segment(k, which)
        };
    });

    // Start where the top-left corner finishes, i.e. on the top edge.
    let out = "M " + seq(geom[3].exit[0], geom[3].exit[1]);
    for (const g of geom)
        out += " L " + seq(g.entry[0], g.entry[1]) + g.seg;

    return out + " Z";
}

// The sliver of a screen corner that a rounded desktop leaves uncovered.
//
// Filled black, these four pieces frame the desktop: the display appears to have
// rounded corners. The shape is the corner curve itself plus two straight runs
// back through the physical corner, so it matches the window rounding exactly
// rather than approximating it.
//
// Drawn in a `p` x `p` box, where p is extent(radius, smoothing).
function cornerPatch(radius, smoothing, which) {
    const s = Math.max(0, Math.min(1, smoothing));
    const k = corner(Math.abs(radius), s);
    if (k.r <= 0)
        return "";

    k.concave = false;
    const p = n(k.p);
    const seg = segment(k, which);

    switch (which) {
    case "tl":
        return `M 0 ${p}${seg} L 0 0 Z`;
    case "tr":
        return `M 0 0${seg} L ${p} 0 Z`;
    case "br":
        return `M ${p} 0${seg} L ${p} ${p} Z`;
    case "bl":
        return `M ${p} ${p}${seg} L 0 ${p} Z`;
    }
    return "";
}
