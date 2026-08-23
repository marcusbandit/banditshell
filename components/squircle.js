.pragma library

// G2-continuous corner geometry: the SUPERELLIPSE the compositor draws.
//
// A corner here is |x|^n + |y|^n = r^n, the same curve Hyprland rounds a window
// with (`decoration:rounding` and `decoration:rounding_power`) and the same one
// components/blob/blob.frag melts the chassis with. n = 2 is a plain circular
// arc; higher is fuller, hugging the corner vertex more closely, and the
// curvature ramps into the straight edge instead of jumping, which is what
// makes it read as one continuous form. See ~/.claude/rules/g2-corners.md.
//
// WHY NOT FIGMA'S CONSTRUCTION, which this file used to draw. Figma's corner
// smoothing shrinks the arc and spends the leftover corner budget on a cubic
// either side. It is a fine squircle and it is NOT this curve: it moves the
// transition further along the EDGE while leaving the distance from the curve to
// the corner vertex fixed at whatever the arc radius gives. So a Figma corner
// and a superellipse of the same size can be made to agree along the sides or at
// the vertex, never both, and the shell had one of each: every panel it draws
// sat beside a window the compositor had rounded, at a visibly different shape.
// blob.frag went superellipse for exactly this reason and said so in its header;
// this is the vector half finally catching up.
//
// THE RADIUS IS THE REACH. It is how far the corner runs along each side, which
// is what `decoration:rounding` means and what a plain `border-radius` means. The
// old file took it as the ARC's radius and then spent (1 + s) times it, so every
// shape was 60% rounder than the number it asked for, and anything asking past
// a third of its side had its smoothing quietly degraded to nothing to fit.
//
// The curve is emitted as cubic Beziers: three per corner, knotted at equal
// TURNING rather than at equal parameter, because a superellipse does nearly all
// of its turning near the diagonal and equal parameter steps put two nearly
// parallel tangents in the first segment. Max deviation from the true curve is
// under a thousandth of the radius across the whole useful range of n.

// THE EXPONENT, taken as itself. It is `decoration:rounding_power` and the same
// number components/blob/blob.frag melts the chassis with, so the shell has ONE
// corner curve rather than a shader parameter and a vector parameter that have
// to be kept in agreement by hand. 2 is circular; below it the corner would turn
// inside out, so that is the floor.
function exponent(power) {
    return Math.max(2, Math.min(12, power));
}

// A point on the unit corner, in the corner's own frame: 1 at the entry, 1 at
// the exit, and the superellipse between them.
function unitPoint(phi, n) {
    return [Math.pow(Math.cos(phi), 2 / n), Math.pow(Math.sin(phi), 2 / n)];
}

// The tangent there, as a direction. The raw derivative has a pole at both ends
// (the parameter stalls while the curve keeps moving); multiplying through by
// (cos phi sin phi)^(1 - 2/n) clears it and leaves this, which is finite and
// correct everywhere including the two endpoints.
function unitTangent(phi, n) {
    const k = 2 - 2 / n;
    return [-Math.pow(Math.sin(phi), k), Math.pow(Math.cos(phi), k)];
}

// The parameter at which the tangent has turned by `frac` of the corner's 90
// degrees. Knotting on this is what keeps the three segments comparable: with a
// high exponent the curve is nearly straight for most of the parameter range and
// then turns almost all at once.
function atTurn(frac, n) {
    if (frac <= 0)
        return 0;
    if (frac >= 1)
        return Math.PI / 2;
    const k = 2 - 2 / n;
    if (k <= 0)
        return frac * Math.PI / 2;
    return Math.atan(Math.pow(Math.tan(frac * Math.PI / 2), 1 / k));
}

// WHERE EACH CORNER SITS, as a centre and two unit axes. `u` points at the entry
// and `v` at the exit, so one formula draws all eight cases and the four corners
// differ only by this table.
//
// CONVEX (positive radius) cuts the corner off the bounding box: the centre is
// inset by the reach on both sides and the curve pulls away from the vertex.
//
// CONCAVE (negative radius) does the reverse: the side pulls IN by the reach and
// the corner flares back OUT to touch the vertex, arriving tangent to the
// perpendicular edge. That is what a panel meeting a screen edge wants, so it
// sweeps into the edge rather than curling away and leaving a notch.
function frame(which, p, w, h, concave) {
    switch (which) {
    case "tr":
        return concave ? [[w, p], [0, -1], [-1, 0]] : [[w - p, p], [0, -1], [1, 0]];
    case "br":
        return concave ? [[w - p, h], [0, -1], [1, 0]] : [[w - p, h - p], [1, 0], [0, 1]];
    case "bl":
        return concave ? [[0, h - p], [0, 1], [1, 0]] : [[p, h - p], [0, 1], [-1, 0]];
    case "tl":
        return concave ? [[p, 0], [0, 1], [-1, 0]] : [[p, p], [-1, 0], [0, -1]];
    }
    return [[0, 0], [0, 0], [0, 0]];
}

function at(f, phi, p, n) {
    const c = f[0];
    const u = f[1];
    const v = f[2];
    const q = unitPoint(phi, n);
    return [c[0] + p * (q[0] * u[0] + q[1] * v[0]), c[1] + p * (q[0] * u[1] + q[1] * v[1])];
}

function dir(f, phi, n) {
    const u = f[1];
    const v = f[2];
    const t = unitTangent(phi, n);
    const x = t[0] * u[0] + t[1] * v[0];
    const y = t[0] * u[1] + t[1] * v[1];
    const m = Math.hypot(x, y) || 1;
    return [x / m, y / m];
}

function n3(x) {
    return Math.round(x * 1000) / 1000;
}

// One cubic through a piece of the curve. The endpoints and their tangent
// DIRECTIONS are exact; the two magnitudes are whatever makes the Bezier pass
// through the curve's own midpoint, which is a 2x2 solve and is what keeps the
// error at four decimal places instead of eyeballing a control-point constant.
function piece(f, phiA, phiB, p, n) {
    const p0 = at(f, phiA, p, n);
    const p1 = at(f, phiB, p, n);
    const mid = at(f, (phiA + phiB) / 2, p, n);
    const t0 = dir(f, phiA, n);
    const t1 = dir(f, phiB, n);

    const dx = (mid[0] - (p0[0] + p1[0]) / 2) * 8 / 3;
    const dy = (mid[1] - (p0[1] + p1[1]) / 2) * 8 / 3;

    const det = t1[0] * t0[1] - t0[0] * t1[1];
    // Parallel tangents mean this piece is already a straight line, and the
    // solve below would divide by nothing to find that out.
    const a = Math.abs(det) < 1e-9 ? 0 : (t1[0] * dy - dx * t1[1]) / det;
    const b = Math.abs(det) < 1e-9 ? 0 : (t0[0] * dy - t0[1] * dx) / det;

    return ` C ${n3(p0[0] + a * t0[0])} ${n3(p0[1] + a * t0[1])} ${n3(p1[0] - b * t1[0])} ${n3(p1[1] - b * t1[1])} ${n3(p1[0])} ${n3(p1[1])}`;
}

// How many cubics a corner is worth. Three carries the whole exponent range;
// the cost of a fourth is one more curve in a path string rebuilt on resize.
var PIECES = 3;

function corner(f, p, n) {
    if (p <= 0)
        return "";
    let out = "";
    for (let i = 0; i < PIECES; i++)
        out += piece(f, atTurn(i / PIECES, n), atTurn((i + 1) / PIECES, n), p, n);
    return out;
}

// Two corners share a side. Each gets a slice of it in proportion to how much it
// asked for, so the bigger reach keeps the bigger allowance when they collide.
function share(r1, r2, len) {
    const total = r1 + r2;
    if (total <= 0)
        return [len / 2, len / 2];
    return [len * r1 / total, len * r2 / total];
}

// How much room each corner actually gets: the smaller of its two sides'
// allowances. In reach units, which is the same unit a side is measured in, so
// nothing has to be scaled to compare them.
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

// How far a corner reaches along each of its two sides. Anything sizing itself
// around a concave corner needs it: the flare is exactly this wide. It IS the
// radius now, and stays a function because that is the question being asked.
function extent(radius, power) {
    return Math.abs(radius);
}

// Full closed path, drawn clockwise starting on the top edge.
// ox/oy translate it, which is what lets a shape be a hole inside a bigger one.
function path(w, h, tl, tr, br, bl, power, ox, oy) {
    ox = ox || 0;
    oy = oy || 0;

    if (w <= 0 || h <= 0)
        return "";

    const n = exponent(power);
    const bud = budgets(Math.abs(tl), Math.abs(tr), Math.abs(br), Math.abs(bl), w, h);
    const order = [["tr", tr, bud.tr], ["br", br, bud.br], ["bl", bl, bud.bl], ["tl", tl, bud.tl]];

    const geom = order.map(([which, radius, budget]) => {
        const p = Math.min(Math.abs(radius), budget);
        const f = frame(which, p, w, h, radius < 0);
        // The translation rides on the centre, which every point and every
        // control point is measured from, so the whole corner arrives already
        // in place rather than being shifted afterwards.
        f[0] = [f[0][0] + ox, f[0][1] + oy];
        return {
            entry: at(f, 0, p, n),
            exit: at(f, Math.PI / 2, p, n),
            seg: corner(f, p, n)
        };
    });

    // Start where the top-left corner finishes, i.e. on the top edge.
    let out = `M ${n3(geom[3].exit[0])} ${n3(geom[3].exit[1])}`;
    for (const g of geom)
        // A corner with no reach contributes no curve, and the next line simply
        // runs to the following entry.
        out += ` L ${n3(g.entry[0])} ${n3(g.entry[1])}${g.seg}`;

    return out + " Z";
}

// The sliver of a square corner that a rounded shape leaves over: the corner
// curve plus two straight runs back through the vertex.
//
// Filled black at the screen's corners it rounds off the display; in the panel
// material where two panels meet at a right angle it fillets the join. Drawn in
// a `p` x `p` box, where p is extent(radius, power).
function cornerPatch(radius, power, which) {
    const p = Math.abs(radius);
    if (p <= 0)
        return "";

    const n = exponent(power);
    const f = frame(which, p, p, p, false);
    const entry = at(f, 0, p, n);
    const vertex = {
        tl: [0, 0],
        tr: [p, 0],
        br: [p, p],
        bl: [0, p]
    }[which];
    if (!vertex)
        return "";

    return `M ${n3(entry[0])} ${n3(entry[1])}${corner(f, p, n)} L ${n3(vertex[0])} ${n3(vertex[1])} Z`;
}
