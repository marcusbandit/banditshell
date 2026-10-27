.pragma library

function scoreOf(usage, key, now, decay) {
    const rec = usage[key];
    return rec ? rec.score * decay(rec.last, now) : 0;
}

function record(usage, key, now, keep, decay) {
    const next = Object.assign({}, usage, {
        [key]: {
            score: scoreOf(usage, key, now, decay) + 1,
            last: now
        }
    });
    const others = Object.keys(next).filter(k => k !== key);
    if (others.length >= keep) {
        const scores = {};
        for (const k of others)
            scores[k] = scoreOf(next, k, now, decay);
        others.sort((a, b) => scores[b] - scores[a] || next[b].last - next[a].last);
        for (const gone of others.slice(keep - 1))
            delete next[gone];
    }
    return next;
}
