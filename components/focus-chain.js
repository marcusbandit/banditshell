.pragma library

function arrange(rects, line) {
    const sorted = [];
    for (let i = 0; i < rects.length; i++)
        sorted.push(i);
    sorted.sort((a, b) => {
        const p = rects[a];
        const q = rects[b];
        return p.y - q.y || p.x - q.x || q.w * q.h - p.w * p.h || a - b;
    });
    const bands = [];
    for (const i of sorted) {
        const r = rects[i];
        const middle = r.y + r.h / 2;
        let band = null;
        for (let k = bands.length - 1; k >= 0 && !band; k--)
            if (middle >= bands[k].top && middle <= bands[k].bottom)
                band = bands[k];
        if (!band) {
            band = {
                top: r.y,
                bottom: r.y + Math.min(r.h, line),
                members: []
            };
            bands.push(band);
        }
        band.members.push(i);
    }
    const order = [];
    const lines = [];
    bands.forEach((band, n) => {
        band.members.sort((a, b) => rects[a].x - rects[b].x || rects[b].w * rects[b].h - rects[a].w * rects[a].h || a - b);
        for (const i of band.members) {
            order.push(i);
            lines.push(n);
        }
    });
    return {
        order: order,
        lines: lines
    };
}

function move(lines, at, direction) {
    const count = lines.length;
    if (at < 0 || at >= count)
        return -1;
    const forward = direction === "down" || direction === "right";
    const to = at + (forward ? 1 : -1);
    if (to < 0 || to >= count)
        return -1;
    if ((direction === "left" || direction === "right") && lines[to] !== lines[at])
        return -1;
    return to;
}

function last(lines) {
    let at = lines.length - 1;
    while (at > 0 && lines[at - 1] === lines[at])
        at--;
    return at;
}

function first(rects, width) {
    for (let i = 0; i < rects.length; i++)
        if (rects[i].w >= width / 2)
            return i;
    return rects.length ? 0 : -1;
}

function page(rects, from, forward, span) {
    const c = rects[from];
    if (!c)
        return -1;
    let far = -1;
    let farRise = -1;
    let near = -1;
    let nearRise = Infinity;
    for (let i = 0; i < rects.length; i++) {
        const rise = forward ? rects[i].y - c.y : c.y - rects[i].y;
        if (rise <= 0.5)
            continue;
        if (rise <= span && rise > farRise + 0.01) {
            far = i;
            farRise = rise;
        }
        if (rise < nearRise - 0.01) {
            near = i;
            nearRise = rise;
        }
    }
    return far >= 0 ? far : near;
}

function starts(groups) {
    const list = [];
    for (let i = 0; i < groups.length; i++)
        if (i === 0 || !groups[i] || groups[i] !== groups[i - 1])
            list.push(i);
    return list;
}

function group(groups, from, forward) {
    const heads = starts(groups);
    if (!heads.length)
        return -1;
    if (from < 0)
        return forward ? heads[0] : heads[heads.length - 1];
    let own = 0;
    while (own + 1 < heads.length && heads[own + 1] <= from)
        own++;
    const next = forward ? own + 1 : own - 1;
    return heads[(next + heads.length) % heads.length];
}

function reveal(goal, view, top, bottom, margin) {
    if (bottom - top + margin * 2 > view) {
        if (bottom < goal)
            return bottom + margin - view;
        if (top > goal + view)
            return top - margin;
        return goal;
    }
    if (top - margin < goal)
        return top - margin;
    if (bottom + margin > goal + view)
        return bottom + margin - view;
    return goal;
}

function read(goal, view, top, bottom, margin, notch, forward) {
    if (forward)
        return bottom + margin > goal + view ? Math.min(goal + notch, bottom + margin - view) : goal;
    return top - margin < goal ? Math.max(goal - notch, top - margin) : goal;
}

function cut(outer, inner) {
    if (!outer)
        return inner;
    const x = Math.max(outer.x, inner.x);
    const y = Math.max(outer.y, inner.y);
    return {
        x: x,
        y: y,
        w: Math.max(0, Math.min(outer.x + outer.w, inner.x + inner.w) - x),
        h: Math.max(0, Math.min(outer.y + outer.h, inner.y + inner.h) - y)
    };
}

function nearest(rects, spot) {
    let best = -1;
    let bestScore = Infinity;
    for (let i = 0; i < rects.length; i++) {
        const r = rects[i];
        const score = Math.abs(r.y - spot.y) * 2 + Math.abs(r.x + r.w / 2 - (spot.x + spot.w / 2));
        if (score < bestScore - 0.01) {
            best = i;
            bestScore = score;
        }
    }
    return best;
}
