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

function upgradeUpdateColours(values) {
    const updates = values.updates;
    if (!isPlainObject(updates) || updates.coloursUpgraded === true || (!owns(updates, "availableColour") && !owns(updates, "failedColour")))
        return values;
    const next = Object.assign({}, updates, { coloursUpgraded: true });
    if (next.availableColour === "alarm" || next.availableColour === "#ff5252")
        next.availableColour = "text";
    if (next.failedColour === "bright" || next.failedColour === "#ffb454")
        next.failedColour = "warning";
    return Object.assign({}, values, { updates: next });
}

function giveGridKey(values, chord, action) {
    const grid = values.files?.grid;
    if (!isPlainObject(grid) || owns(grid, chord) || Object.values(grid).includes(action))
        return values;
    const files = Object.assign({}, values.files, { grid: Object.assign({}, grid, { [chord]: action }) });
    return Object.assign({}, values, { files });
}

function upgradeFilesGrid(values) {
    return giveGridKey(giveGridKey(values, "Ctrl+Z", "undo"), "F5", "refresh");
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

function upgradeClipboard(values) {
    if (!isPlainObject(values.clipboard) || !owns(values.clipboard, "preview"))
        return values;
    const clipboard = Object.assign({}, values.clipboard);
    delete clipboard.preview;
    return Object.assign({}, values, { clipboard });
}

function upgradeChannel(values, keepChannel) {
    const updates = values.updates;
    if (!isPlainObject(updates) || updates.channelUpgraded === true)
        return values;
    const next = Object.assign({}, updates, { channelUpgraded: true });
    if (next.channel === "main" && !keepChannel)
        next.channel = "stable";
    return Object.assign({}, values, { updates: next });
}

function upgrade(values, keepChannel) {
    if (!isPlainObject(values))
        return values;
    return upgradeClipboard(upgradeUpdateColours(upgradeChannel(upgradeFilesGrid(upgradeFiles(upgradeSidebarClock(upgradeLauncher(values)))), keepChannel === true)));
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

function refusal(key) {
    return { values: null, refused: key, changed: [] };
}

function fork(node, fresh) {
    if (fresh.has(node))
        return node;
    const copy = Array.isArray(node) ? node.slice() : Object.assign({}, node);
    fresh.add(copy);
    return copy;
}

function detached(value) {
    return value !== null && typeof value === "object" ? JSON.parse(JSON.stringify(value)) : value;
}

function assign(values, pairs, literals) {
    const fresh = new Set();
    const changed = [];
    let next = values;

    for (const pair of pairs) {
        const key = String(pair[0]);
        const segments = key.split(".");
        if (segments.some(segment => segment === "" || reservedSegments.includes(segment)))
            return refusal(key);

        const path = segments.slice(0, -1);
        let node = next;
        for (const segment of path) {
            if (!holds(node, segment))
                return refusal(key);
            node = node[segment];
        }

        const last = segments[segments.length - 1];
        if (!holds(node, last) || !fits(node[last], pair[1], literals, key))
            return refusal(key);
        if (JSON.stringify(node[last]) === JSON.stringify(pair[1]))
            continue;

        next = fork(next, fresh);
        let at = next;
        for (const segment of path) {
            at[segment] = fork(at[segment], fresh);
            at = at[segment];
        }
        at[last] = detached(pair[1]);
        if (!changed.includes(segments[0]))
            changed.push(segments[0]);
    }

    return { values: next, refused: "", changed };
}

function reuse(before, after) {
    if (before === after)
        return before;
    const lists = Array.isArray(before) && Array.isArray(after);
    if (!lists && !(isPlainObject(before) && isPlainObject(after)))
        return after;
    const keys = Object.keys(after);
    let same = keys.length === Object.keys(before).length;
    const out = lists ? [] : {};
    for (const key of keys) {
        out[key] = owns(before, key) ? reuse(before[key], after[key]) : after[key];
        if (!owns(before, key) || out[key] !== before[key])
            same = false;
    }
    return same ? before : out;
}

function reapply(values, pairs, literals) {
    if (!pairs.length)
        return values;
    const again = assign(values, pairs, literals);
    return again.refused ? values : again.values;
}

function saveDelay(unsavedSince, now, quiet, longest) {
    return Math.max(0, Math.min(quiet, unsavedSince + longest - now));
}

function jsonErrorAt(text) {
    const raw = String(text);
    let at = 0;
    const fail = reason => {
        throw { at: at, reason: reason || "" };
    };
    const ended = () => at >= raw.length;
    const space = () => {
        while (at < raw.length && " \t\n\r".includes(raw[at]))
            at++;
    };
    const word = w => {
        if (raw.startsWith(w, at))
            at += w.length;
        else
            fail();
    };
    const string = () => {
        at++;
        while (at < raw.length && raw[at] !== '"') {
            if (raw[at] === "\n")
                fail("Unclosed string");
            if (raw.charCodeAt(at) < 0x20)
                fail();
            if (raw[at] === "\\") {
                at++;
                if (raw[at] === "u") {
                    if (!/^[0-9a-fA-F]{4}$/.test(raw.slice(at + 1, at + 5)))
                        fail("Bad escape in a string");
                    at += 4;
                } else if (!'"\\/bfnrt'.includes(raw[at] ?? "x")) {
                    fail("Bad escape in a string");
                }
            }
            at++;
        }
        if (ended())
            fail("Unclosed string");
        at++;
    };
    const number = () => {
        const match = /^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?/.exec(raw.slice(at));
        if (!match)
            fail();
        at += match[0].length;
    };
    const after = close => {
        space();
        if (ended())
            fail("The file ends too early");
        if (raw[at] === ",") {
            at++;
            return true;
        }
        if (raw[at] === close) {
            at++;
            return false;
        }
        if (raw[at] === '"' || raw[at] === "{" || raw[at] === "[" || (close === "]" && /[-0-9tfn]/.test(raw[at])))
            fail("Missing comma");
        if (raw[at] === "}" || raw[at] === "]")
            fail(`Unexpected ${raw[at]}`);
        fail();
    };
    const value = () => {
        space();
        if (ended())
            fail("The file ends too early");
        const c = raw[at];
        if (c === "{") {
            at++;
            space();
            if (raw[at] === "}") {
                at++;
                return;
            }
            let comma = false;
            for (;;) {
                space();
                if (ended())
                    fail("The file ends too early");
                if (raw[at] === "}" && comma)
                    fail("Extra comma before }");
                if (raw[at] !== '"')
                    fail();
                string();
                space();
                if (ended())
                    fail("The file ends too early");
                if (raw[at] !== ":")
                    fail("Missing : after the key");
                at++;
                value();
                comma = after("}");
                if (!comma)
                    return;
            }
        }
        if (c === "[") {
            at++;
            space();
            if (raw[at] === "]") {
                at++;
                return;
            }
            for (;;) {
                space();
                if (raw[at] === "]")
                    fail("Extra comma before ]");
                value();
                if (!after("]"))
                    return;
            }
        }
        if (c === "}" || c === "]" || c === ",")
            fail(`Unexpected ${c}`);
        if (c === '"')
            return string();
        if (c === "t")
            return word("true");
        if (c === "f")
            return word("false");
        if (c === "n")
            return word("null");
        number();
    };
    try {
        value();
        space();
        if (!ended())
            fail();
        return null;
    } catch (stop) {
        if (typeof stop?.at !== "number")
            throw stop;
        const before = raw.slice(0, Math.min(stop.at, raw.length));
        const lines = before.split("\n");
        return { line: lines.length, column: lines[lines.length - 1].length + 1, reason: stop.reason };
    }
}

function errorSnippet(text, line, column, width) {
    const rows = String(text).split("\n").map(r => r.replace(/\r$/, ""));
    if (line < 1 || line > rows.length + 1)
        return "";
    const expand = r => r.replace(/\t/g, "    ");
    const own = rows[line - 1] ?? "";
    const caret = expand(own.slice(0, Math.max(0, column - 1))).length;
    const numbers = line > 1 ? [line - 1, line] : [line];
    const gutter = String(line).length + 2;
    const room = Math.max(8, width - gutter);
    const start = caret < room - 2 ? 0 : caret - room + 8;
    const cut = r => {
        const shown = expand(r);
        if (start > 0 && shown.length <= start)
            return "";
        let piece = shown.slice(start, start + room);
        if (start > 0)
            piece = "\u2026" + piece.slice(1);
        if (shown.length > start + room)
            piece = piece.slice(0, -1) + "\u2026";
        return piece.replace(/\s+$/, "");
    };
    const out = numbers.map(n => String(n).padStart(gutter - 2) + "  " + cut(rows[n - 1] ?? ""));
    out.push(" ".repeat(gutter + caret - start) + "^");
    return out.join("\n");
}

function readText(raw, state, defaults, keepChannel, opaque, literals) {
    let parsed = null;
    let problem = "not an object";
    let at = null;
    try {
        parsed = JSON.parse(raw);
    } catch (e) {
        problem = e.message;
        at = jsonErrorAt(raw);
    }
    if (!isPlainObject(parsed))
        return { values: state.values, loaded: true, unreadable: true, problem: problem, at: at, save: false };
    const values = merge(defaults, upgrade(parsed, keepChannel), "", opaque, literals);
    return { values: values, loaded: true, unreadable: false, problem: "", at: null, save: JSON.stringify(values) !== JSON.stringify(parsed) };
}

function readFailed(missing) {
    if (!missing)
        return { loaded: true, unreadable: true, fresh: false, save: false };
    return { loaded: true, unreadable: false, fresh: true, save: true };
}
