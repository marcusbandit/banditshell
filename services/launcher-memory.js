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
    const keys = Object.keys(next);
    if (keys.length > keep) {
        keys.sort((a, b) => scoreOf(next, b, now, decay) - scoreOf(next, a, now, decay) || next[b].last - next[a].last);
        for (const gone of keys.slice(keep))
            delete next[gone];
    }
    return next;
}
