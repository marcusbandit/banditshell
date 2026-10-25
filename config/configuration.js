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
    if (path === "launcher.concept" && value === "niagara")
        return "alphabet";
    if (path === "sidebar.clock.style" && value === "small")
        return "stacked";
    if (path === "files.sort" && (value === "date" || value === "type"))
        return value === "date" ? "mtime" : "kind";
    if (path === "files.markdown" && value === "source")
        return "raw";
    return value;
}

function upgradeFiles(values) {
    const files = values.files;
    if (!isPlainObject(files) || (!["date", "type"].includes(files.sort) && files.markdown !== "source"))
        return values;
    const next = Object.assign({}, files);
    for (const key of ["sort", "markdown"])
        if (owns(files, key))
            next[key] = upgradeValue(`files.${key}`, files[key]);
    return Object.assign({}, values, { files: next });
}

function upgradeFilesUndo(values) {
    const grid = values.files?.grid;
    if (!isPlainObject(grid) || owns(grid, "Ctrl+Z") || Object.values(grid).includes("undo"))
        return values;
    const files = Object.assign({}, values.files, { grid: Object.assign({}, grid, { "Ctrl+Z": "undo" }) });
    return Object.assign({}, values, { files });
}

function upgradeFilesRefresh(values) {
    const grid = values.files?.grid;
    if (!isPlainObject(grid) || owns(grid, "F5") || Object.values(grid).includes("refresh"))
        return values;
    const files = Object.assign({}, values.files, { grid: Object.assign({}, grid, { F5: "refresh" }) });
    return Object.assign({}, values, { files });
}

function upgradeLauncher(values) {
    if (!isPlainObject(values.launcher))
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

function upgradeSidebarClock(values) {
    const clock = values.sidebar?.clock;
    if (!isPlainObject(clock) || !["small", "off"].includes(clock.style))
        return values;
    const choice = clock.style === "small" ? { style: "stacked", size: "small" } : {};
    if (!owns(clock, "wideStyle") && !owns(clock, "wideSize"))
        Object.assign(choice, clock.style === "small" ? { wideStyle: "stacked", wideSize: "small" } : { wideStyle: "off" });
    const sidebar = Object.assign({}, values.sidebar, { clock: Object.assign({}, clock, choice) });
    return Object.assign({}, values, { sidebar });
}

function upgrade(values) {
    if (!isPlainObject(values))
        return values;
    return upgradeFilesRefresh(upgradeFilesUndo(upgradeFiles(upgradeSidebarClock(upgradeLauncher(values)))));
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
