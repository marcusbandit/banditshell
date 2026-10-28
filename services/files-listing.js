.pragma library

const MOST_STEPS = 64;
const REREAD_GAP = 1000;

function table(keys) {
    const out = Object.create(null);
    for (let i = 0; i < keys.length; i++) {
        const key = ":" + keys[i];
        if (out[key] !== undefined)
            return null;
        out[key] = i;
    }
    return out;
}

function same(a, b) {
    const keys = Object.keys(a);
    if (keys.length !== Object.keys(b).length)
        return false;
    for (const key of keys) {
        const x = a[key];
        const y = b[key];
        if (x === y)
            continue;
        if (x && y && typeof x === "object" && typeof y === "object" && JSON.stringify(x) === JSON.stringify(y))
            continue;
        return false;
    }
    return true;
}

function reuse(old, fresh, keyOf) {
    const before = old.length === 0 ? null : table(old.map(keyOf));
    if (!before)
        return fresh;
    return fresh.map(e => {
        const at = before[":" + keyOf(e)];
        const was = at === undefined ? undefined : old[at];
        return was && same(was, e) ? was : e;
    });
}

function changed(before, after, beforeKeys, afterKeys) {
    const was = table(beforeKeys);
    const out = [];
    if (!was)
        return out;
    for (let i = 0; i < after.length; i++) {
        const at = was[":" + afterKeys[i]];
        if (at !== undefined && before[at] !== after[i])
            out.push(i);
    }
    return out;
}

function steps(before, after) {
    const had = table(before);
    const wanted = table(after);
    if (!had || !wanted)
        return null;
    if (before.length === after.length && before.every((key, i) => key === after[i]))
        return [];
    const out = [];
    const keys = before.slice();
    for (let i = keys.length - 1; i >= 0;) {
        if (wanted[":" + keys[i]] !== undefined) {
            i--;
            continue;
        }
        let lo = i;
        while (lo > 0 && wanted[":" + keys[lo - 1]] === undefined)
            lo--;
        out.push({remove: lo, count: i - lo + 1});
        if (out.length > MOST_STEPS)
            return null;
        keys.splice(lo, i - lo + 1);
        i = lo - 1;
    }
    for (let i = 0; i < after.length; i++) {
        if (keys[i] === after[i])
            continue;
        if (had[":" + after[i]] !== undefined) {
            const from = keys.indexOf(after[i], i + 1);
            out.push({move: from, to: i});
            keys.splice(from, 1);
            keys.splice(i, 0, after[i]);
        } else {
            let n = 1;
            while (i + n < after.length && had[":" + after[i + n]] === undefined)
                n++;
            out.push({insert: i, count: n});
            keys.splice(i, 0, ...after.slice(i, i + n));
            i += n - 1;
        }
        if (out.length > MOST_STEPS)
            return null;
    }
    return out;
}

function stale(seen, entry) {
    return !!seen && !!entry && (seen.mtime !== entry.mtime || seen.size !== entry.size);
}

function rereadIn(now, readAt) {
    return Math.max(0, readAt + REREAD_GAP - now);
}
