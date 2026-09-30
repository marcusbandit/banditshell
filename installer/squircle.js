.pragma library

function exponent(power) {
    return Math.max(2, Math.min(12, power));
}

function unitPoint(phi, n) {
    return [Math.pow(Math.cos(phi), 2 / n), Math.pow(Math.sin(phi), 2 / n)];
}

function unitTangent(phi, n) {
    const k = 2 - 2 / n;
    return [-Math.pow(Math.sin(phi), k), Math.pow(Math.cos(phi), k)];
}

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

function piece(f, phiA, phiB, p, n) {
    const p0 = at(f, phiA, p, n);
    const p1 = at(f, phiB, p, n);
    const mid = at(f, (phiA + phiB) / 2, p, n);
    const t0 = dir(f, phiA, n);
    const t1 = dir(f, phiB, n);

    const dx = (mid[0] - (p0[0] + p1[0]) / 2) * 8 / 3;
    const dy = (mid[1] - (p0[1] + p1[1]) / 2) * 8 / 3;

    const det = t1[0] * t0[1] - t0[0] * t1[1];

    const a = Math.abs(det) < 1e-9 ? 0 : (t1[0] * dy - dx * t1[1]) / det;
    const b = Math.abs(det) < 1e-9 ? 0 : (t0[0] * dy - t0[1] * dx) / det;

    return ` C ${n3(p0[0] + a * t0[0])} ${n3(p0[1] + a * t0[1])} ${n3(p1[0] - b * t1[0])} ${n3(p1[1] - b * t1[1])} ${n3(p1[0])} ${n3(p1[1])}`;
}

var PIECES = 3;

function corner(f, p, n) {
    if (p <= 0)
        return "";
    let out = "";
    for (let i = 0; i < PIECES; i++)
        out += piece(f, atTurn(i / PIECES, n), atTurn((i + 1) / PIECES, n), p, n);
    return out;
}

function share(r1, r2, len) {
    const total = r1 + r2;
    if (total <= 0)
        return [len / 2, len / 2];
    return [len * r1 / total, len * r2 / total];
}

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

function extent(radius, power) {
    return Math.abs(radius);
}

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

        f[0] = [f[0][0] + ox, f[0][1] + oy];
        return {
            entry: at(f, 0, p, n),
            exit: at(f, Math.PI / 2, p, n),
            seg: corner(f, p, n)
        };
    });

    let out = `M ${n3(geom[3].exit[0])} ${n3(geom[3].exit[1])}`;
    for (const g of geom)

        out += ` L ${n3(g.entry[0])} ${n3(g.entry[1])}${g.seg}`;

    return out + " Z";
}

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
