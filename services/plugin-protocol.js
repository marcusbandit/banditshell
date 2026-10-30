.pragma library

var API = 1;

var ID = /^[a-z0-9][a-z0-9-]{0,63}$/;

var PREF_KEY = /^[A-Za-z0-9_]{1,64}$/;

var PREF_TYPES = ["text", "secret", "toggle"];

var LINK = /^(?:https?:\/\/|mailto:|file:\/\/\/)/i;

var SCHEME = /^([a-z][a-z0-9+.-]*):/i;

var ICON_NAME = /^[a-z0-9_]+$/;

var ITEM_LIMIT = 50;

var LINE_LIMIT = 1048576;

var CRASH_WINDOW = 60000;

var CRASH_LIMIT = 3;

var EFFECTS = ["copy", "open", "notify", "close"];

var VIEW_KINDS = ["detail", "list", "form"];

var FIELD_TYPES = ["text", "secret", "toggle", "choice"];

function textOf(value, limit) {
    if (typeof value === "number" && isFinite(value))
        return String(value);
    return typeof value === "string" ? value.slice(0, limit || 300) : "";
}

function given(value) {
    return value !== undefined && value !== null && value !== "" && !(Array.isArray(value) && !value.length);
}

function iconOf(icon, folder) {
    var t = textOf(icon, 4096).trim();
    if (!t)
        return {};
    if (ICON_NAME.test(t))
        return { name: t };
    if (t.charAt(0) === "/")
        return { file: t };
    if (folder && /^\.?\.?\/|\.(?:png|svg|jpe?g|webp)$/i.test(t))
        return { file: `${folder}/${t.replace(/^\.\//, "")}` };
    return { glyph: t };
}

function targetRefusal(target) {
    if (target.charAt(0) === "-")
        return "refused a target starting with -";
    if (target.charAt(0) === "/" || LINK.test(target))
        return "";
    var m = SCHEME.exec(target);
    return m ? `refused a ${m[1].toLowerCase()}: link` : "refused a path that is not absolute";
}

function readDoing(raw) {
    var out = { open: "", copy: "", run: [], refusal: "" };
    if (given(raw.open)) {
        out.open = textOf(raw.open, 4096);
        out.refusal = out.open ? targetRefusal(out.open) : "open is a link or an absolute path";
    } else if (given(raw.copy))
        out.copy = textOf(raw.copy, 65536);
    else if (given(raw.run)) {
        if (!Array.isArray(raw.run) || raw.run.length > 64 || raw.run.some(a => typeof a !== "string") || !raw.run[0] || raw.run[0].charAt(0) === "-")
            out.refusal = "refused a run that is not a list of strings, the program first";
        else
            out.run = raw.run.slice();
    }
    return out;
}

function local(doing) {
    return !!(doing.open || doing.copy || doing.run.length);
}

function readManifest(text, folder) {
    var name = folder.slice(folder.lastIndexOf("/") + 1);
    var raw;
    try {
        raw = JSON.parse(text);
    } catch (e) {
        return { error: "plugin.json is not JSON", id: name };
    }
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return { error: "plugin.json is not an object", id: name };
    if (raw.id !== name || !ID.test(name))
        return { error: `the id must be the folder's name, ${name}, in lowercase letters, digits and -`, id: name };
    var title = textOf(raw.name).trim();
    if (!title)
        return { error: "plugin.json has no name", id: name };
    if (raw.api !== API)
        return { error: `asks for api ${raw.api === undefined ? "nothing" : textOf(raw.api)}, the shell speaks ${API}`, id: name, name: title };
    if (!Array.isArray(raw.exec) || !raw.exec.length || raw.exec.some(a => typeof a !== "string") || !raw.exec[0])
        return { error: "exec is a list of strings, the program first", id: name, name: title };
    var prefix = (Array.isArray(raw.prefix) ? raw.prefix : typeof raw.prefix === "string" ? [raw.prefix] : []).filter(w => typeof w === "string" && /^\S+$/.test(w)).map(w => w.toLowerCase()).slice(0, 8);
    var global = raw.global && typeof raw.global === "object" ? {
        minLength: Math.max(1, Math.min(32, Math.round(Number(raw.global.minLength) || 3))),
        cap: Math.max(1, Math.min(5, Math.round(Number(raw.global.cap) || 3)))
    } : null;
    if (!prefix.length && !global)
        return { error: "plugin.json needs a prefix, global or both", id: name, name: title };
    var preferences = [];
    for (var p of Array.isArray(raw.preferences) ? raw.preferences : []) {
        if (!p || !PREF_KEY.test(p.key) || PREF_TYPES.indexOf(p.type) < 0 || preferences.some(q => q.key === p.key))
            return { error: `a preference needs a key of letters, digits and _, and a type of ${PREF_TYPES.join(", ")}`, id: name, name: title };
        preferences.push({
            key: p.key,
            type: p.type,
            title: textOf(p.title).trim() || p.key,
            placeholder: textOf(p.placeholder),
            fallback: p.type === "toggle" ? !!p.default : p.type === "text" ? textOf(p.default, 4096) : "",
            required: p.required === true
        });
    }
    var exec = raw.exec.slice();
    if (exec[0].indexOf("./") === 0)
        exec[0] = `${folder}/${exec[0].slice(2)}`;
    return {
        plugin: {
            id: name,
            name: title,
            about: textOf(raw.about).trim(),
            icon: iconOf(raw.icon, folder),
            exec: exec,
            folder: folder,
            prefix: prefix,
            global: global,
            preferences: preferences
        }
    };
}

function envKey(key) {
    return `BANDITSHELL_PREF_${key.toUpperCase()}`;
}

function valueOf(pref, values, secrets) {
    if (pref.type === "secret")
        return textOf((secrets || {})[pref.key], 65536);
    var v = (values || {})[pref.key];
    if (pref.type === "toggle")
        return (v === undefined ? pref.fallback : !!v) ? "1" : "0";
    return v === undefined ? pref.fallback : textOf(v, 4096);
}

function missing(plugin, values, secrets) {
    return plugin.preferences.filter(p => p.required && p.type !== "toggle" && !valueOf(p, values, secrets)).map(p => p.key);
}

function environment(plugin, values, secrets) {
    var env = {
        BANDITSHELL_PLUGIN_ID: plugin.id,
        BANDITSHELL_PLUGIN_DIR: plugin.folder,
        BANDITSHELL_API: String(API)
    };
    for (var p of plugin.preferences)
        env[envKey(p.key)] = valueOf(p, values, secrets);
    return env;
}

function asked(plugin, text) {
    var typed = text.replace(/^\s+/, "");
    var lower = typed.toLowerCase();
    for (var word of plugin.prefix)
        if (lower === word || lower.indexOf(`${word} `) === 0)
            return { prefixed: true, text: typed.slice(word.length).replace(/^\s+/, ""), word: word };
    var plain = typed.trim();
    if (plugin.global && plain.length >= plugin.global.minLength)
        return { prefixed: false, text: plain, word: "" };
    return null;
}

function queryLine(seq, text, prefixed) {
    return JSON.stringify({ type: "query", seq: seq, text: text, prefixed: prefixed });
}

function activateLine(seq, id, action, view) {
    var out = { type: "activate", seq: seq, id: id, action: action || "" };
    if (view)
        out.view = view;
    return JSON.stringify(out);
}

function submitLine(view, values) {
    return JSON.stringify({ type: "submit", view: view, values: values });
}

function completeLine(id) {
    return JSON.stringify({ type: "complete", id: id });
}

function cancelLine(seq) {
    return JSON.stringify({ type: "cancel", seq: seq });
}

function readAction(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    var id = textOf(raw.id, 200);
    var title = textOf(raw.title).trim();
    if (!id || !title)
        return null;
    return Object.assign(readDoing(raw), { id: id, title: title, icon: textOf(raw.icon, 64) });
}

function readItem(raw, folder) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    var id = textOf(raw.id, 200);
    var title = textOf(raw.title).trim();
    if (!id || !title)
        return null;
    var keywords = Array.isArray(raw.keywords) ? raw.keywords.filter(w => typeof w === "string").map(w => w.slice(0, 64)).slice(0, 32) : [];
    var actions = (Array.isArray(raw.actions) ? raw.actions : []).map(readAction).filter(Boolean).slice(0, 12);
    return Object.assign(readDoing(raw), {
        id: id,
        title: title,
        subtitle: textOf(raw.subtitle).trim(),
        icon: iconOf(raw.icon, folder || ""),
        keywords: keywords,
        actions: actions
    });
}

function readItems(list, folder) {
    var out = [];
    var seen = {};
    for (var raw of Array.isArray(list) ? list : []) {
        var item = readItem(raw, folder);
        if (!item || seen[item.id])
            continue;
        seen[item.id] = true;
        out.push(item);
        if (out.length >= ITEM_LIMIT)
            break;
    }
    return out;
}

function readField(raw) {
    if (!raw || typeof raw !== "object" || !PREF_KEY.test(raw.key) || FIELD_TYPES.indexOf(raw.type) < 0)
        return null;
    var choices = raw.type === "choice" ? (Array.isArray(raw.choices) ? raw.choices : []).map(c => c && typeof c === "object" ? { value: textOf(c.value, 200), title: textOf(c.title).trim() || textOf(c.value, 200) } : { value: textOf(c, 200), title: textOf(c, 200) }).filter(c => c.value).slice(0, 20) : [];
    if (raw.type === "choice" && !choices.length)
        return null;
    var value = raw.type === "toggle" ? raw.value === true : raw.type === "choice" ? (choices.some(c => c.value === raw.value) ? raw.value : choices[0].value) : textOf(raw.value, 4096);
    return {
        key: raw.key,
        type: raw.type,
        title: textOf(raw.title).trim() || raw.key,
        placeholder: textOf(raw.placeholder),
        required: raw.required === true,
        choices: choices,
        value: value
    };
}

function readView(raw, folder) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return { error: "a view that is not an object" };
    if (VIEW_KINDS.indexOf(raw.kind) < 0)
        return { error: `a view of a kind the shell does not know: ${textOf(raw.kind, 40)}` };
    var id = textOf(raw.id, 200);
    var title = textOf(raw.title).trim();
    if (!id || !title)
        return { error: "a view needs an id and a title" };
    var view = {
        kind: raw.kind,
        id: id,
        title: title,
        actions: (Array.isArray(raw.actions) ? raw.actions : []).map(readAction).filter(Boolean).slice(0, 8)
    };
    if (raw.kind === "detail") {
        view.text = textOf(raw.text, 20000);
        view.facts = (Array.isArray(raw.facts) ? raw.facts : []).filter(f => f && typeof f === "object").map(f => ({ label: textOf(f.label, 80).trim(), value: textOf(f.value, 500) })).filter(f => f.label).slice(0, 30);
    } else if (raw.kind === "list") {
        view.placeholder = textOf(raw.placeholder) || "Filter";
        view.items = readItems(raw.items, folder);
    } else {
        var fields = [];
        for (var f of Array.isArray(raw.fields) ? raw.fields : []) {
            var field = readField(f);
            if (!field || fields.some(g => g.key === field.key))
                return { error: "a form field needs a key of letters, digits and _, and a type of text, secret, toggle or choice with choices" };
            fields.push(field);
        }
        if (!fields.length)
            return { error: "a form with no fields" };
        view.fields = fields.slice(0, 20);
        view.submit = textOf(raw.submit, 40).trim() || "Submit";
    }
    return { view: view };
}

function formValues(view, values) {
    var out = {};
    for (var f of view.fields)
        out[f.key] = values && Object.prototype.hasOwnProperty.call(values, f.key) ? values[f.key] : f.value;
    return out;
}

function formMissing(view, values) {
    var out = formValues(view, values);
    return view.fields.filter(f => f.required && f.type !== "toggle" && !out[f.key]).map(f => f.key);
}

function listed(view, typed, place) {
    var t = typed.trim();
    if (!t)
        return view.items;
    return view.items.map((item, i) => ({ item: item, i: i, score: plainScore(item, t, place) })).filter(m => m.score > 0).sort((a, b) => b.score - a.score || a.i - b.i).map(m => m.item);
}

function readMessage(line, folder) {
    if (line.length > LINE_LIMIT)
        return { error: "a line longer than 1 MB" };
    var raw;
    try {
        raw = JSON.parse(line);
    } catch (e) {
        return { error: "a line that is not JSON" };
    }
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return { error: "a line that is not a JSON object" };
    switch (raw.type) {
    case "results":
        if (!Number.isInteger(raw.seq))
            return { error: "results without a seq" };
        return { type: "results", seq: raw.seq, items: readItems(raw.items, folder) };
    case "fill":
        return typeof raw.text === "string" ? { type: "fill", text: raw.text.slice(0, 1000) } : { error: "fill without text" };
    case "view":
        var read = readView(raw.view, folder);
        return read.error ? { error: read.error } : { type: "view", view: read.view };
    case "effect":
        if (EFFECTS.indexOf(raw.do) < 0)
            return { error: `an effect the shell does not know: ${textOf(raw.do, 40)}` };
        if (raw.do === "copy")
            return typeof raw.text === "string" ? { type: "effect", do: "copy", text: raw.text.slice(0, 65536) } : { error: "copy without text" };
        if (raw.do === "open") {
            var target = textOf(raw.target, 4096);
            var refusal = target ? targetRefusal(target) : "open without a target";
            return refusal ? { error: refusal } : { type: "effect", do: "open", target: target };
        }
        if (raw.do === "notify")
            return { type: "effect", do: "notify", title: textOf(raw.title).trim() || "Plugin", body: textOf(raw.body, 1000) };
        return { type: "effect", do: "close" };
    }
    return { error: `a message the shell does not know: ${textOf(raw.type, 40)}` };
}

function enterOf(item) {
    if (local(item) || item.refusal)
        return { local: item };
    var first = item.actions[0];
    if (!first)
        return { action: "" };
    return local(first) || first.refusal ? { local: first } : { action: first.id };
}

function fileUrl(path) {
    return "file://" + path.split("/").map(encodeURIComponent).join("/");
}

function plainScore(item, typed, place) {
    return Math.max(place(item.title, typed), place(item.keywords.join(" "), typed) - 0.5);
}

function crashes(times, now) {
    var recent = times.filter(t => now - t < CRASH_WINDOW);
    return {
        recent: recent,
        off: recent.length >= CRASH_LIMIT,
        delay: recent.length ? Math.min(30000, 1000 * Math.pow(2, recent.length - 1)) : 0
    };
}
