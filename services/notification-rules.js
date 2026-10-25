const DEFAULT_RULE = { pop: true, snd: true, lock: false, muteUntil: 0 };

function ruleFor(rules, key) {
    const mine = rules && key && Object.prototype.hasOwnProperty.call(rules, key) ? rules[key] : null;
    const out = Object.assign({}, DEFAULT_RULE);
    if (mine && typeof mine === "object")
        for (const field of Object.keys(DEFAULT_RULE))
            if (typeof mine[field] === typeof DEFAULT_RULE[field] && (typeof mine[field] !== "number" || (isFinite(mine[field]) && mine[field] >= 0)))
                out[field] = mine[field];
    return out;
}

function keyFor(appName, desktopEntry, desktopId) {
    return desktopId || desktopEntry || String(appName ?? "").toLowerCase();
}

function withRule(rules, key, changes) {
    const next = Object.assign({}, rules);
    next[key] = Object.assign(ruleFor(rules, key), changes);
    return next;
}

function fromList(list) {
    const out = {};
    for (const item of Array.isArray(list) ? list : [])
        if (item && typeof item.id === "string" && item.id)
            out[item.id] = ruleFor({ [item.id]: item }, item.id);
    return out;
}

function candidates(keys, rules, limit) {
    const seen = new Set();
    const out = [];
    for (const key of keys) {
        if (!key || seen.has(key) || Object.prototype.hasOwnProperty.call(rules ?? {}, key))
            continue;
        seen.add(key);
        out.push(key);
        if (out.length >= limit)
            break;
    }
    return out;
}

const HUSHED = ["pop", "snd", "muteUntil"];

function muted(rule, now) {
    return (!rule.pop && !rule.snd) || rule.muteUntil > now;
}

function unmuted(rule, now) {
    return rule.muteUntil > now && (rule.pop || rule.snd) ? { muteUntil: 0 } : { pop: true, snd: true, muteUntil: 0 };
}

function restored(rules, key, was) {
    const back = ruleFor(was === undefined ? {} : { [key]: was }, key);
    const rule = ruleFor(rules, key);
    for (const field of HUSHED)
        rule[field] = back[field];
    const next = Object.assign({}, rules);
    if (was === undefined && Object.keys(DEFAULT_RULE).every(field => rule[field] === DEFAULT_RULE[field]))
        delete next[key];
    else
        next[key] = rule;
    return next;
}
