.pragma library

const MOST_STEPS = 64;
const REREAD_GAP = 1000;

function table(keys) {
    const out = Object.create(null);
    out.repeats = 0;
    for (let i = 0; i < keys.length; i++) {
        const key = ":" + keys[i];
        if (out[key] !== undefined)
            out.repeats++;
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
    const before = table(old.map(keyOf));
    if (old.length === 0 || before.repeats)
        return fresh;
    return fresh.map(e => {
        const at = before[":" + keyOf(e)];
        const was = at === undefined ? undefined : old[at];
        return was && same(was, e) ? was : e;
    });
}

function changed(before, after, had, afterKeys) {
    const out = [];
    for (let i = 0; i < after.length; i++) {
        const at = had[":" + afterKeys[i]];
        if (at !== undefined && before[at] !== after[i])
            out.push(i);
    }
    return out;
}

function settled(keys, wanted) {
    let ordered = true;
    for (let i = 1; i < keys.length && ordered; i++)
        ordered = wanted[":" + keys[i - 1]] < wanted[":" + keys[i]];
    if (ordered)
        return null;
    const tails = [];
    const tailAt = [];
    const previous = new Array(keys.length);
    for (let i = 0; i < keys.length; i++) {
        const place = wanted[":" + keys[i]];
        let lo = 0;
        let hi = tails.length;
        while (lo < hi) {
            const mid = (lo + hi) >> 1;
            if (tails[mid] < place)
                lo = mid + 1;
            else
                hi = mid;
        }
        tails[lo] = place;
        tailAt[lo] = i;
        previous[i] = lo > 0 ? tailAt[lo - 1] : -1;
    }
    const out = Object.create(null);
    for (let i = tails.length > 0 ? tailAt[tails.length - 1] : -1; i >= 0; i = previous[i])
        out[":" + keys[i]] = true;
    return out;
}

function steps(before, after, had, wanted) {
    had = had ?? table(before);
    wanted = wanted ?? table(after);
    if (had.repeats || wanted.repeats)
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
    const stays = settled(keys, wanted);
    const parked = Object.create(null);
    for (let i = 0; i < after.length; i++) {
        while (stays && i < keys.length && keys[i] !== after[i] && !stays[":" + keys[i]] && !parked[":" + keys[i]]) {
            parked[":" + keys[i]] = true;
            out.push({move: i, to: keys.length - 1});
            keys.push(keys.splice(i, 1)[0]);
            if (out.length > MOST_STEPS)
                return null;
        }
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
