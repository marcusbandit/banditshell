.pragma library

function read(line) {
    const bits = String(line ?? "").split("\t");
    const path = bits[1] ?? "";
    switch (bits[0]) {
    case "file":
        return bits.length === 2 && path ? {
            kind: "file",
            path
        } : null;
    case "listed":
        return {
            kind: "listed",
            changed: bits[1] !== "same"
        };
    case "shape":
        {
            const width = parseInt(bits[2], 10);
            const height = parseInt(bits[3], 10);
            const known = width > 0 && height > 0;
            return bits.length === 4 && path ? {
                kind: "shape",
                path,
                width: known ? width : 0,
                height: known ? height : 0
            } : null;
        }
    case "poster":
        return bits.length === 3 && path ? {
            kind: "poster",
            path,
            poster: bits[2]
        } : null;
    case "frozen":
        return bits.length === 3 && path ? {
            kind: "frozen",
            path,
            frozen: bits[2] === "1"
        } : null;
    case "done":
        return {
            kind: "done"
        };
    }
    return null;
}

function kept(map, paths) {
    const wanted = {};
    for (const path of paths)
        wanted[path] = true;
    const out = {};
    let gone = false;
    for (const key in map) {
        if (wanted[key])
            out[key] = map[key];
        else
            gone = true;
    }
    return gone ? out : map;
}

function merged(map, updates) {
    const keys = Object.keys(updates);
    if (!keys.length)
        return map;
    const out = Object.assign({}, map);
    for (const key of keys) {
        if (updates[key] === null)
            delete out[key];
        else
            out[key] = updates[key];
    }
    return out;
}
