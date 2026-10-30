.pragma library

var NAME = /^[a-z0-9][a-z0-9._-]{0,63}$/;

var LINK = /^(?:https?:\/\/|mailto:|file:\/\/\/)/i;

var SCHEME = /^([a-z][a-z0-9+.-]*):/i;

var ICON_NAME = /^[a-z0-9_]+$/;

var TEXT_LIMIT = 300;

var ROWS_PER_TOOL = 50;

var LONGEST_TTL = 366 * 24 * 3600;

function empty() {
    return { version: 1, tools: {} };
}

function textOf(value, limit) {
    if (typeof value === "number" && isFinite(value))
        return String(value);
    return typeof value === "string" ? value.slice(0, limit || TEXT_LIMIT) : "";
}

function openRefusal(target) {
    if (target.charAt(0) === "-")
        return "refused a target starting with -";
    if (target.charAt(0) === "/" || LINK.test(target))
        return "";
    var m = SCHEME.exec(target);
    return m ? `refused a ${m[1].toLowerCase()}: link` : "refused a path that is not absolute";
}

function given(value) {
    return value !== undefined && value !== null && value !== "" && !(Array.isArray(value) && !value.length);
}

function readDoing(raw) {
    var named = ["open", "copy", "run"].filter(k => given(raw[k]));
    if (named.length > 1)
        return { error: "give one of open, copy or run, not several" };
    var out = { open: "", copy: "", run: [] };
    if (given(raw.open)) {
        out.open = textOf(raw.open, 4096);
        if (!out.open)
            return { error: "open is a link or an absolute path" };
        var refusal = openRefusal(out.open);
        if (refusal)
            return { error: refusal };
    }
    if (given(raw.copy)) {
        out.copy = textOf(raw.copy, 65536);
        if (!out.copy)
            return { error: "copy is text" };
    }
    if (given(raw.run)) {
        if (!Array.isArray(raw.run) || !raw.run.length || raw.run.length > 64 || raw.run.some(a => typeof a !== "string"))
            return { error: "run is a list of strings, the program first" };
        if (!raw.run[0] || raw.run[0].charAt(0) === "-")
            return { error: "run starts with the program" };
        out.run = raw.run.slice();
    }
    return out;
}

function keywordsOf(value) {
    var words = Array.isArray(value) ? value.filter(w => typeof w === "string") : typeof value === "string" ? value.split(/\s+/) : [];
    return words.map(w => w.trim().slice(0, 64)).filter(Boolean).slice(0, 32);
}

function readRow(raw, now) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return { error: "a row is a JSON object" };
    if (typeof raw.tool !== "string" || !NAME.test(raw.tool))
        return { error: "tool is a name of lowercase letters, digits, dots, dashes and underscores" };
    if (typeof raw.id !== "string" || !NAME.test(raw.id))
        return { error: "id is a name of lowercase letters, digits, dots, dashes and underscores" };
    var title = textOf(raw.title).trim();
    if (!title)
        return { error: "a row needs a title" };
    var ttl = raw.ttl === undefined || raw.ttl === null ? 0 : Number(raw.ttl);
    if (!(ttl >= 0) || ttl > LONGEST_TTL)
        return { error: "ttl is a number of seconds, at most a year" };
    var doing = readDoing(raw);
    if (doing.error)
        return { error: doing.error };
    return {
        row: {
            tool: raw.tool,
            id: raw.id,
            title: title,
            subtitle: textOf(raw.subtitle).trim(),
            icon: textOf(raw.icon, 4096).trim(),
            keywords: keywordsOf(raw.keywords),
            open: doing.open,
            copy: doing.copy,
            run: doing.run,
            added: now,
            expires: ttl > 0 ? now + Math.round(ttl * 1000) : 0
        }
    };
}

function parseRow(text, now) {
    var raw;
    try {
        raw = JSON.parse(text);
    } catch (e) {
        return { error: "the row is not JSON" };
    }
    return readRow(raw, now);
}

function added(store, row) {
    var tools = Object.assign({}, store.tools);
    var kept = (tools[row.tool] || []).filter(r => r.id !== row.id);
    tools[row.tool] = kept.concat([row]).slice(-ROWS_PER_TOOL);
    return { version: 1, tools: tools };
}

function removed(store, tool, id) {
    var had = store.tools[tool] || [];
    var left = id ? had.filter(r => r.id !== id) : [];
    var tools = Object.assign({}, store.tools);
    if (left.length)
        tools[tool] = left;
    else
        delete tools[tool];
    return { store: { version: 1, tools: tools }, count: had.length - left.length };
}

function live(store, now) {
    var tools = {};
    var dropped = false;
    for (var tool in store.tools) {
        var rows = store.tools[tool].filter(r => !r.expires || r.expires > now);
        dropped = dropped || rows.length !== store.tools[tool].length;
        if (rows.length)
            tools[tool] = rows;
    }
    return dropped ? { version: 1, tools: tools } : store;
}

function nextExpiry(store) {
    var next = 0;
    for (var tool in store.tools)
        for (var r of store.tools[tool])
            if (r.expires && (!next || r.expires < next))
                next = r.expires;
    return next;
}

function rowsOf(store, tool) {
    var out = [];
    for (var name of Object.keys(store.tools).sort())
        if (!tool || name === tool)
            out = out.concat(store.tools[name]);
    return out;
}

function readStore(text, now) {
    var data;
    try {
        data = JSON.parse(text);
    } catch (e) {
        return empty();
    }
    if (!data || typeof data !== "object" || !data.tools || typeof data.tools !== "object")
        return empty();
    var store = empty();
    for (var tool in data.tools) {
        if (!Array.isArray(data.tools[tool]))
            continue;
        for (var raw of data.tools[tool]) {
            var read = readRow(Object.assign({}, raw, { tool: tool, ttl: 0 }), raw && raw.added || now);
            if (read.row)
                store = added(store, Object.assign(read.row, { expires: Number(raw.expires) || 0 }));
        }
    }
    return live(store, now);
}

function scoreOf(row, typed, place) {
    return Math.max(place(row.title, typed), place(row.keywords.join(" "), typed) - 0.5, place(row.tool, typed) - 0.5);
}

function iconOf(row) {
    var icon = row.icon;
    if (!icon)
        return { name: row.open ? "open_in_new" : row.copy ? "content_copy" : row.run.length ? "play_arrow" : "push_pin" };
    if (icon.charAt(0) === "/")
        return { file: icon };
    return ICON_NAME.test(icon) ? { name: icon } : { glyph: icon };
}

function titleOfTool(tool) {
    return tool.charAt(0).toUpperCase() + tool.slice(1);
}
