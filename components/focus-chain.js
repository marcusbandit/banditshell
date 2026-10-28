.pragma library

function overlap(a0, a1, b0, b1) {
    return Math.min(a1, b1) - Math.max(a0, b0);
}

function contains(outer, inner) {
    const slack = 0.5;
    return inner.x >= outer.x - slack && inner.y >= outer.y - slack && inner.x + inner.w <= outer.x + outer.w + slack && inner.y + inner.h <= outer.y + outer.h + slack;
}

function readingOrder(rects) {
    const order = [];
    for (let i = 0; i < rects.length; i++)
        order.push(i);
    order.sort((a, b) => {
        const p = rects[a];
        const q = rects[b];
        if (Math.abs(p.y - q.y) > 0.5)
            return p.y - q.y;
        if (Math.abs(p.x - q.x) > 0.5)
            return p.x - q.x;
        return q.w * q.h - p.w * p.h || a - b;
    });
    return order;
}

function step(rects, from, direction, line) {
    const c = rects[from];
    if (!c)
        return -1;
    const vertical = direction === "up" || direction === "down";
    const forward = direction === "down" || direction === "right";
    const found = [];
    for (let i = 0; i < rects.length; i++) {
        if (i === from)
            continue;
        const r = rects[i];
        const nested = contains(c, r) || contains(r, c);
        const rise = forward ? r.y - c.y : c.y - r.y;
        const ahead = forward ? r.x + r.w / 2 - (c.x + c.w / 2) : c.x + c.w / 2 - (r.x + r.w / 2);
        if (vertical) {
            if (nested ? rise < line : rise <= 0.5 || overlap(c.y, c.y + c.h, r.y, r.y + r.h) > Math.min(c.h, r.h) / 2)
                continue;
            found.push({
                at: i,
                score: rise + Math.max(0, -overlap(c.x, c.x + c.w, r.x, r.x + r.w)) * 2,
                off: Math.abs(r.x - c.x)
            });
        } else {
            if (ahead <= 0.5 || overlap(c.y, c.y + c.h, r.y, r.y + r.h) <= 0 || nested && Math.abs(r.y - c.y) >= line)
                continue;
            found.push({
                at: i,
                score: ahead + Math.abs(r.y - c.y) * 2,
                off: 0
            });
        }
    }
    let best = null;
    for (const f of found) {
        const r = rects[f.at];
        if (vertical && found.some(o => o !== f && contains(rects[o.at], r) && r.y - rects[o.at].y < line))
            continue;
        if (!best || f.score < best.score - 0.01 || Math.abs(f.score - best.score) <= 0.01 && f.off < best.off - 0.5)
            best = f;
    }
    return best ? best.at : -1;
}

function last(rects) {
    let at = rects.length - 1;
    while (at > 0) {
        const p = rects[at - 1];
        const q = rects[at];
        if (!contains(p, q) && overlap(p.y, p.y + p.h, q.y, q.y + q.h) <= Math.min(p.h, q.h) / 2)
            break;
        at--;
    }
    return at;
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
    if (top - margin < goal || bottom - top + margin * 2 > view)
        return top - margin;
    if (bottom + margin > goal + view)
        return bottom + margin - view;
    return goal;
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
