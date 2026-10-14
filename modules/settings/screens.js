.pragma library

const CONTACT = 100;

function rectOf(name, spec) {
    const m = /^(\d+)x(\d+)(?:@([\d.]+))?/.exec(spec && spec.mode || "");
    const pw = m ? +m[1] : 1920;
    const ph = m ? +m[2] : 1080;
    const transform = (spec && spec.transform || 0) % 4;
    const turned = transform % 2 === 1;
    const scale = spec && spec.scale > 0 ? spec.scale : 1;
    const at = /^(-?\d+)x(-?\d+)$/.exec(String(spec && spec.position || "0x0"));
    return {
        name: name,
        x: at ? +at[1] : 0,
        y: at ? +at[2] : 0,
        w: Math.round((turned ? ph : pw) / scale),
        h: Math.round((turned ? pw : ph) / scale),
        pw: pw,
        ph: ph,
        hz: m && m[3] ? Math.round(+m[3]) : 0,
        scale: scale,
        transform: transform,
        off: !!(spec && spec.disabled),
        mirror: spec && spec.mirror || ""
    };
}

function overlaps(a, b) {
    return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h;
}

function contact(a, b) {
    const along = Math.min(a.y + a.h, b.y + b.h) - Math.max(a.y, b.y);
    const across = Math.min(a.x + a.w, b.x + b.w) - Math.max(a.x, b.x);
    if ((a.x === b.x + b.w || b.x === a.x + a.w) && along > 0)
        return along;
    if ((a.y === b.y + b.h || b.y === a.y + a.h) && across > 0)
        return across;
    return 0;
}

function moved(r, x, y) {
    return Object.assign({}, r, { x: x, y: y });
}

function placedOthers(rects, name) {
    return rects.filter(r => r.name !== name && !r.off && !r.mirror);
}

function issues(everything) {
    const rects = everything.filter(r => !r.off && !r.mirror);
    const clash = [];
    const loose = [];
    for (let i = 0; i < rects.length; i++)
        for (let j = i + 1; j < rects.length; j++)
            if (overlaps(rects[i], rects[j]))
                clash.push([rects[i].name, rects[j].name]);
    if (rects.length > 1)
        for (const a of rects)
            if (!rects.some(b => b !== a && contact(a, b) > 0))
                loose.push(a.name);
    return { clash: clash, loose: loose };
}

function lines(o, size) {
    return [
        [o.end, "edge", o.end],
        [o.start - size, "edge", o.start],
        [o.start, "align", o.start],
        [o.end - size, "align", o.end],
        [Math.round(o.start + (o.end - o.start) / 2 - size / 2), "centre", o.start + (o.end - o.start) / 2]
    ];
}

function nearest(others, size, value, reach, axis) {
    let best = null;
    for (const o of others) {
        const span = axis === "x" ? { start: o.x, end: o.x + o.w } : { start: o.y, end: o.y + o.h };
        for (const c of lines(span, size)) {
            const d = Math.abs(c[0] - value);
            if (d <= reach && (!best || d < best.d))
                best = { v: c[0], kind: c[1], at: c[2], d: d, o: o };
        }
    }
    return best;
}

function snap(rects, name, x, y, reach) {
    const me = rects.find(r => r.name === name);
    if (!me)
        return { x: Math.round(x), y: Math.round(y), guides: [], corner: null };
    const others = placedOthers(rects, name);
    const bx = nearest(others, me.w, x, reach, "x");
    const by = nearest(others, me.h, y, reach, "y");
    const nx = bx ? bx.v : Math.round(x);
    const ny = by ? by.v : Math.round(y);
    const guides = [];
    if (bx)
        guides.push({ axis: "x", at: bx.at, from: Math.min(ny, bx.o.y), to: Math.max(ny + me.h, bx.o.y + bx.o.h), kind: bx.kind });
    if (by)
        guides.push({ axis: "y", at: by.at, from: Math.min(nx, by.o.x), to: Math.max(nx + me.w, by.o.x + by.o.w), kind: by.kind });
    const corner = bx && by && bx.o === by.o && bx.kind !== "centre" && by.kind !== "centre" ? { x: bx.at, y: by.at } : null;
    return { x: nx, y: ny, guides: guides, corner: corner };
}

function settle(rects, name, x, y, reach) {
    const me = rects.find(r => r.name === name);
    const others = placedOthers(rects, name);
    if (!me || !others.length)
        return { x: Math.round(x), y: Math.round(y) };
    const free = c => !others.some(o => overlaps(c, o));
    const here = moved(me, Math.round(x), Math.round(y));
    if (free(here) && others.some(o => contact(here, o) > 0))
        return { x: here.x, y: here.y };

    const spots = [];
    for (const o of others) {
        const tall = Math.min(CONTACT, me.h, o.h);
        const wide = Math.min(CONTACT, me.w, o.w);
        const slideY = v => Math.min(o.y + o.h - tall, Math.max(o.y - me.h + tall, v));
        const slideX = v => Math.min(o.x + o.w - wide, Math.max(o.x - me.w + wide, v));
        const alignY = v => {
            const hit = nearest([o], me.h, v, reach, "y");
            return hit && hit.kind !== "edge" ? hit.v : v;
        };
        const alignX = v => {
            const hit = nearest([o], me.w, v, reach, "x");
            return hit && hit.kind !== "edge" ? hit.v : v;
        };
        spots.push(moved(me, o.x - me.w, alignY(slideY(here.y))));
        spots.push(moved(me, o.x + o.w, alignY(slideY(here.y))));
        spots.push(moved(me, alignX(slideX(here.x)), o.y - me.h));
        spots.push(moved(me, alignX(slideX(here.x)), o.y + o.h));
    }
    const fine = spots.filter(c => free(c) && others.some(o => contact(c, o) > 0));
    fine.sort((a, b) => Math.hypot(a.x - here.x, a.y - here.y) - Math.hypot(b.x - here.x, b.y - here.y));
    if (fine.length)
        return { x: fine[0].x, y: fine[0].y };
    return { x: Math.max.apply(null, others.map(o => o.x + o.w)), y: Math.min.apply(null, others.map(o => o.y)) };
}

function anchor(rects) {
    const placed = rects.filter(r => !r.off && !r.mirror);
    if (!placed.length)
        return {};
    const left = Math.min.apply(null, placed.map(r => r.x));
    const top = Math.min.apply(null, placed.map(r => r.y));
    const out = {};
    if (left === 0 && top === 0)
        return out;
    for (const r of placed)
        out[r.name] = { x: r.x - left, y: r.y - top };
    return out;
}

function nudge(rects, name, dx, dy) {
    const me = rects.find(r => r.name === name);
    if (!me)
        return null;
    const others = placedOthers(rects, name);
    const next = moved(me, me.x + dx, me.y + dy);
    if (others.some(o => overlaps(next, o) && !overlaps(me, o)))
        return null;
    return { x: next.x, y: next.y };
}

function resize(rects, name, fresh) {
    const old = rects.find(r => r.name === name);
    if (!old)
        return {};
    let x = old.x;
    let y = old.y;
    for (const o of rects) {
        if (o.name === name || contact(old, o) <= 0)
            continue;
        const side = o.x === old.x + old.w || o.x + o.w === old.x;
        if (side && Math.abs(old.y + old.h / 2 - (o.y + o.h / 2)) < 1)
            y = Math.round(o.y + o.h / 2 - fresh.h / 2);
        if (!side && Math.abs(old.x + old.w / 2 - (o.x + o.w / 2)) < 1)
            x = Math.round(o.x + o.w / 2 - fresh.w / 2);
    }
    const out = {};
    out[name] = { x: x, y: y };
    const dw = x + fresh.w - (old.x + old.w);
    const dh = y + fresh.h - (old.y + old.h);
    for (const o of rects) {
        if (o.name === name)
            continue;
        const right = o.x >= old.x + old.w && dw !== 0;
        const below = o.y >= old.y + old.h && dh !== 0;
        if (right || below)
            out[o.name] = { x: o.x + (right ? dw : 0), y: o.y + (below ? dh : 0) };
    }
    return out;
}

function fit(rects, width, height, pad) {
    if (!rects.length || width <= pad * 2 || height <= pad * 2)
        return { k: 0.1, ox: 0, oy: 0 };
    const minX = Math.min.apply(null, rects.map(r => r.x));
    const minY = Math.min.apply(null, rects.map(r => r.y));
    const maxX = Math.max.apply(null, rects.map(r => r.x + r.w));
    const maxY = Math.max.apply(null, rects.map(r => r.y + r.h));
    const bw = Math.max(1, maxX - minX);
    const bh = Math.max(1, maxY - minY);
    const k = Math.min((width - pad * 2) / bw, (height - pad * 2) / bh);
    return { k: k, ox: (width - bw * k) / 2 - minX * k, oy: (height - bh * k) / 2 - minY * k };
}
