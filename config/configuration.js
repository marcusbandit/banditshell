const reservedSegments = ["__proto__", "constructor", "prototype"];

function isPlainObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function owns(node, key) {
    return Object.prototype.hasOwnProperty.call(node, key);
}

function allowedLiteral(literals, path, value) {
    return typeof value === "string" && (literals?.[path] ?? []).includes(value);
}

function fits(current, value, literals, key) {
    if (allowedLiteral(literals, key, value))
        return true;
    if (allowedLiteral(literals, key, current))
        return Array.isArray(value);
    return sameShape(current, value);
}

function merge(base, over, path, opaque, literals) {
    if (opaque.includes(path))
        return over && typeof over === "object" ? over : base;

    if (allowedLiteral(literals, path, over))
        return over;

    if (Array.isArray(base))
        return Array.isArray(over) ? over : base;

    if (isPlainObject(base)) {
        if (!isPlainObject(over))
            return base;
        if (Object.keys(base).length === 0)
            return over;
        const out = {};
        for (const key of Object.keys(base))
            out[key] = merge(base[key], owns(over, key) ? over[key] : undefined, path ? `${path}.${key}` : key, opaque, literals);
        return out;
    }

    return over === undefined || !sameShape(base, over) ? base : over;
}

function upgradeValue(path, value) {
    return path === "launcher.concept" && value === "niagara" ? "alphabet" : value;
}

function upgrade(values) {
    if (!isPlainObject(values) || !isPlainObject(values.launcher))
        return values;
    const launcher = Object.assign({}, values.launcher);
    if (owns(launcher, "niagara")) {
        if (!owns(launcher, "alphabet"))
            launcher.alphabet = launcher.niagara;
        delete launcher.niagara;
    }
    if (owns(launcher, "concept"))
        launcher.concept = upgradeValue("launcher.concept", launcher.concept);
    return Object.assign({}, values, { launcher });
}

function holds(node, segment) {
    if (Array.isArray(node))
        return /^\d+$/.test(segment) && Number(segment) < node.length;
    return isPlainObject(node) && owns(node, segment);
}

function sameShape(current, value) {
    if (Array.isArray(current))
        return Array.isArray(value);
    if (isPlainObject(current))
        return isPlainObject(value);
    return value === null || typeof value !== "object";
}

function lookup(values, key) {
    let node = values;
    for (const segment of String(key).split(".")) {
        if (reservedSegments.includes(segment) || !holds(node, segment))
            return undefined;
        node = node[segment];
    }
    return node;
}

function assign(values, pairs, literals) {
    const next = JSON.parse(JSON.stringify(values));

    for (const pair of pairs) {
        const key = String(pair[0]);
        const segments = key.split(".");
        if (segments.some(segment => segment === "" || reservedSegments.includes(segment)))
            return { values: null, refused: key };

        let node = next;
        for (const segment of segments.slice(0, -1)) {
            if (!holds(node, segment))
                return { values: null, refused: key };
            node = node[segment];
        }

        const last = segments[segments.length - 1];
        if (!holds(node, last) || !fits(node[last], pair[1], literals, key))
            return { values: null, refused: key };

        node[last] = pair[1];
    }

    return { values: next, refused: "" };
}
