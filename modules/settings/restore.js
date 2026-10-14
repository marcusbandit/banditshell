.pragma library

const SECRET_CONFIG = ["obs.password"];
const KEPT_LOCAL = ["sourceEdits.acknowledged", "updates.remote"];
const SECRET_PLANNED = ["hotspotPass"];
const INTERNAL_PLANNED = ["modeWas"];

const CANNOT = "this machine cannot take that value";

const COPY_NAME = /^banditshell-settings-.+\.json$/;

function plain(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function same(a, b) {
    if (a === b)
        return true;
    if (Array.isArray(a) || Array.isArray(b))
        return Array.isArray(a) && Array.isArray(b) && a.length === b.length && a.every((x, i) => same(x, b[i]));
    if (plain(a) && plain(b)) {
        const keys = Object.keys(a);
        return keys.length === Object.keys(b).length && keys.every(k => Object.prototype.hasOwnProperty.call(b, k) && same(a[k], b[k]));
    }
    return false;
}

function lookup(values, path) {
    let at = values;
    for (const part of path.split(".")) {
        if (!plain(at) || !Object.prototype.hasOwnProperty.call(at, part))
            return undefined;
        at = at[part];
    }
    return at;
}

function without(config, path) {
    const out = JSON.parse(JSON.stringify(config));
    const parts = path.split(".");
    let at = out;
    for (const part of parts.slice(0, -1)) {
        if (!plain(at[part]))
            return out;
        at = at[part];
    }
    delete at[parts[parts.length - 1]];
    return out;
}

function exportable(config, planned) {
    const outPlanned = {};
    for (const k of Object.keys(planned ?? {}))
        if (!SECRET_PLANNED.includes(k) && planned[k] !== undefined)
            outPlanned[k] = planned[k];
    return {
        config: SECRET_CONFIG.reduce(without, config),
        planned: outPlanned
    };
}

function newest(names) {
    const copies = (names ?? []).filter(n => COPY_NAME.test(n)).sort();
    return copies.length ? copies[copies.length - 1] : "";
}

function read(text) {
    let data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return { why: "that file is not valid JSON" };
    }
    if (!plain(data))
        return { why: "that file is not a settings copy" };
    if (data.config === undefined && data.planned === undefined)
        return { why: "that file has neither config nor planned settings in it" };
    if (data.config !== undefined && !plain(data.config))
        return { why: "the config in that file is not a table of settings" };
    if (data.planned !== undefined && !plain(data.planned))
        return { why: "the planned settings in that file are not a table" };
    return { file: { config: data.config ?? {}, planned: data.planned ?? {} } };
}

function kindOf(value) {
    return Array.isArray(value) ? "list" : value === null ? "null" : plain(value) ? "table" : typeof value;
}

function diff(file, world) {
    const changes = [];
    const skipped = [];
    const rowKeyOf = {};
    for (const k of Object.keys(world.configBacked))
        rowKeyOf[world.configBacked[k]] = k;

    function fitsKind(base, path, value) {
        const kind = kindOf(base);
        if ((kind === "boolean" || kind === "number" || kind === "string") && kindOf(value) !== kind)
            return false;
        return world.fits(path, value);
    }

    function walk(base, over, path) {
        if (plain(base) && Object.keys(base).length > 0 && !world.opaque.includes(path)) {
            if (over !== undefined && !plain(over)) {
                skipped.push({ key: path, why: "not a section here" });
                return;
            }
            for (const key of Object.keys(base))
                walk(base[key], over === undefined ? undefined : over[key], path ? `${path}.${key}` : key);
            for (const key of Object.keys(over ?? {}))
                if (!Object.prototype.hasOwnProperty.call(base, key))
                    skipped.push({ key: path ? `${path}.${key}` : key, why: "not a setting here" });
            return;
        }
        if (over === undefined)
            return;
        if (SECRET_CONFIG.includes(path)) {
            skipped.push({ key: path, why: "passwords stay out of copies" });
            return;
        }
        if (KEPT_LOCAL.includes(path)) {
            if (!same(lookup(world.current, path), over))
                skipped.push({ key: path, why: "this machine keeps its own" });
            return;
        }
        if (!fitsKind(base, path, over)) {
            skipped.push({ key: path, why: CANNOT });
            return;
        }
        const served = world.servicePaths[path];
        if (served) {
            const from = world.rowValue(served);
            if (!same(from, over))
                changes.push({ route: "setting", path, key: served, from, to: over });
            return;
        }
        const from = lookup(world.current, path);
        if (!same(from, over))
            changes.push({ route: "config", path, key: rowKeyOf[path] ?? "", from, to: over });
    }

    walk(world.defaults, file.config, "");

    for (const k of Object.keys(file.planned)) {
        const value = file.planned[k];
        if (SECRET_PLANNED.includes(k)) {
            skipped.push({ key: k, why: "passwords stay out of copies" });
            continue;
        }
        if (INTERNAL_PLANNED.includes(k))
            continue;
        const path = world.configBacked[k];
        if (path && !(k in world.planDefaults)) {
            if (lookup(file.config, path) !== undefined)
                continue;
            const to = world.transformWrite(k, value);
            if (!fitsKind(lookup(world.defaults, path), path, to)) {
                skipped.push({ key: k, why: CANNOT });
                continue;
            }
            const from = lookup(world.current, path);
            if (!same(from, to))
                changes.push({ route: "config", path, key: k, from, to });
        } else if (k in world.planDefaults) {
            if (kindOf(world.planDefaults[k]) !== kindOf(value)) {
                skipped.push({ key: k, why: CANNOT });
                continue;
            }
            const from = world.planned[k] === undefined ? world.planDefaults[k] : world.planned[k];
            if (!same(from, value))
                changes.push({ route: "planned", path: "", key: k, from, to: value });
        } else if (world.hasRow(k)) {
            if (!same(world.rowValue(k), value))
                skipped.push({ key: k, why: "only planned when this copy was made" });
        } else {
            skipped.push({ key: k, why: "not a setting here" });
        }
    }

    return { changes, skipped };
}

function phrase(value) {
    if (value === undefined || value === null)
        return "nothing";
    if (typeof value === "boolean")
        return value ? "on" : "off";
    if (typeof value === "number")
        return String(Math.round(value * 1000) / 1000);
    if (typeof value === "string")
        return value === "" ? "empty" : value.length > 26 ? `${value.slice(0, 25)}…` : value;
    if (Array.isArray(value)) {
        if (value.length === 0)
            return "empty";
        const joined = value.every(x => typeof x !== "object") ? value.join(", ") : "";
        return joined && joined.length <= 26 ? joined : `${value.length} ${value.length === 1 ? "item" : "items"}`;
    }
    const count = Object.keys(value).length;
    return count === 0 ? "empty" : `${count} ${count === 1 ? "entry" : "entries"}`;
}

function summary(changes, skipped) {
    const parts = [`${changes.length} ${changes.length === 1 ? "change" : "changes"}`];
    if (skipped.length)
        parts.push(`${skipped.length} skipped`);
    return parts.join(" · ");
}
