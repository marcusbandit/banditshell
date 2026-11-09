.pragma library

var API = 3;

var APIS = [1, 2, 3];

var ID = /^[a-z0-9][a-z0-9-]{0,63}$/;

var PREF_KEY = /^[A-Za-z0-9_]{1,64}$/;

var PREF_TYPES = ["text", "secret", "toggle"];

var LINK = /^(?:https?:\/\/|mailto:|file:\/\/\/)/i;

var SCHEME = /^([a-z][a-z0-9+.-]*):/i;

var ICON_NAME = /^[a-z0-9_]+$/;

var ITEM_LIMIT = 50;

var TALLEST = 12;

var RANKS = ["first", "mixed", "last"];

var LIFT = { first: 10, mixed: 0.5, last: -4 };

var PROPS_LIMIT = 65536;

var QML_PATH = /^(?![./])[A-Za-z0-9_./-]{1,200}\.qml$/;

var LINE_LIMIT = 1048576;

var CRASH_WINDOW = 60000;

var CRASH_LIMIT = 3;

var EFFECTS = ["copy", "open", "notify", "close"];

var VIEW_KINDS = ["detail", "list", "form"];

var FIELD_TYPES = ["text", "secret", "toggle", "choice"];

var STATUS_PLACES = ["rail", "island"];

var STATUS_TONES = ["plain", "active", "alert", "warning", "alarm"];

var STATUS_LIMIT = 4;

var ARG_TYPES = ["text", "choice"];

var ARG_LIMIT = 3;

var COMMAND_WORD = /^[a-z0-9][a-z0-9-]{0,31}$/;

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

function readManifest(text, folder, loose) {
    var name = folder.slice(folder.lastIndexOf("/") + 1);
    var raw;
    try {
        raw = JSON.parse(text);
    } catch (e) {
        return { error: "plugin.json is not JSON", id: name };
    }
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return { error: "plugin.json is not an object", id: name };
    if (loose) {
        if (typeof raw.id !== "string" || !ID.test(raw.id))
            return { error: "the id must be lowercase letters, digits and -", id: name };
        name = raw.id;
        folder = `${folder.slice(0, folder.lastIndexOf("/") + 1)}${name}`;
    } else if (raw.id !== name || !ID.test(name))
        return { error: `the id must be the folder's name, ${name}, in lowercase letters, digits and -`, id: name };
    var title = textOf(raw.name).trim();
    if (!title)
        return { error: "plugin.json has no name", id: name };
    if (APIS.indexOf(raw.api) < 0)
        return { error: `asks for api ${raw.api === undefined ? "nothing" : textOf(raw.api)}, the shell speaks ${APIS.slice(0, -1).join(", ")} and ${APIS[APIS.length - 1]}`, id: name, name: title };
    if (!Array.isArray(raw.exec) || !raw.exec.length || raw.exec.some(a => typeof a !== "string") || !raw.exec[0])
        return { error: "exec is a list of strings, the program first", id: name, name: title };
    var prefix = (Array.isArray(raw.prefix) ? raw.prefix : typeof raw.prefix === "string" ? [raw.prefix] : []).filter(w => typeof w === "string" && /^\S+$/.test(w)).map(w => w.toLowerCase()).slice(0, 8);
    var global = raw.global && typeof raw.global === "object" ? {
        minLength: Math.max(1, Math.min(32, Math.round(Number(raw.global.minLength) || 3))),
        cap: Math.max(1, Math.min(ITEM_LIMIT, Math.round(Number(raw.global.cap) || 3)))
    } : null;
    var status = [];
    for (var st of Array.isArray(raw.status) ? raw.status : []) {
        if (!st || typeof st.id !== "string" || !ID.test(st.id) || STATUS_PLACES.indexOf(st.place) < 0 || status.some(x => x.id === st.id))
            return { error: "a status item needs an id of lowercase letters, digits and -, and a place of rail or island", id: name, name: title };
        status.push({ id: st.id, place: st.place, title: textOf(st.title).trim() || title, icon: statusIcon(st.icon) || statusIcon(raw.icon) || "extension" });
    }
    if (status.length > STATUS_LIMIT)
        return { error: `a plugin has at most ${STATUS_LIMIT} status items`, id: name, name: title };
    var commands = [];
    for (var c of Array.isArray(raw.commands) ? raw.commands : []) {
        var word = c && typeof c.word === "string" ? c.word.toLowerCase() : "";
        if (!COMMAND_WORD.test(word) || commands.some(x => x.word === word))
            return { error: "a command needs a word of lowercase letters, digits and -, used once", id: name, name: title };
        var args = [];
        for (var a of Array.isArray(c.arguments) ? c.arguments : []) {
            var type = a && a.type !== undefined ? a.type : "text";
            if (!a || !PREF_KEY.test(a.key) || ARG_TYPES.indexOf(type) < 0 || args.some(b => b.key === a.key))
                return { error: "an argument needs a key of letters, digits and _, and a type of text or choice", id: name, name: title };
            var choices = readChoices(a.choices, 60, 30);
            if (type === "choice" && !choices.length)
                return { error: `the argument ${a.key} is a choice with no choices`, id: name, name: title };
            args.push({ key: a.key, type: type, placeholder: textOf(a.placeholder, 40).trim() || a.key, required: a.required === true, choices: choices });
        }
        if (!args.length || args.length > ARG_LIMIT)
            return { error: `the command ${word} takes one to ${ARG_LIMIT} arguments`, id: name, name: title };
        commands.push({ word: word, title: textOf(c.title).trim() || word, icon: statusIcon(c.icon), arguments: args });
    }
    for (var cw of commands)
        if (prefix.indexOf(cw.word) < 0)
            prefix.push(cw.word);
    if (!prefix.length && !global && !status.length)
        return { error: "plugin.json needs a prefix, global, status or a mix", id: name, name: title };
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
            api: raw.api,
            name: title,
            about: textOf(raw.about).trim(),
            icon: iconOf(raw.icon, folder),
            exec: exec,
            folder: folder,
            prefix: prefix,
            global: global,
            preferences: preferences,
            background: raw.background === true || status.length > 0,
            status: status,
            commands: commands
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

var NOTIFY_GAP = 3000;

function environment(plugin, values, secrets, dataRoot) {
    var env = {
        BANDITSHELL_PLUGIN_ID: plugin.id,
        BANDITSHELL_PLUGIN_DIR: plugin.folder,
        BANDITSHELL_API: String(plugin.api || API)
    };
    if (dataRoot)
        env.BANDITSHELL_PLUGIN_DATA = `${dataRoot}/${plugin.id}`;
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

function activateLine(seq, id, action, view, flag) {
    var out = { type: "activate", seq: seq, id: id, action: action || "" };
    if (view)
        out.view = view;
    if (flag)
        out[flag] = true;
    return JSON.stringify(out);
}

function coldId(prefix, id) {
    if (id.indexOf(prefix) !== 0)
        return "";
    var item = id.slice(prefix.length);
    return item && item.charAt(0) !== "!" ? item : "";
}

function submitLine(view, values) {
    return JSON.stringify({ type: "submit", view: view, values: values });
}

function completeLine(id) {
    return JSON.stringify({ type: "complete", id: id });
}

function statusIcon(raw) {
    var t = textOf(raw, 64).trim();
    return ICON_NAME.test(t) ? t : "";
}

function readStatus(raw, declared) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return { error: "status without an item" };
    var decl = (declared || []).find(d => d.id === raw.id);
    if (!decl)
        return { error: `a status for ${textOf(raw.id, 64) || "nothing"}, which plugin.json does not declare` };
    var actions = chordsOf((Array.isArray(raw.actions) ? raw.actions : []).map(readAction).filter(Boolean).slice(0, 4));
    var click = textOf(raw.click, 200);
    if (click !== "rows" && click !== "menu" && !actions.some(a => a.id === click))
        click = decl.place === "rail" ? "menu" : "rows";
    if (click === "menu" && decl.place === "island")
        click = "rows";
    var progress = raw.progress === undefined || raw.progress === null ? -1 : Number(raw.progress);
    return {
        item: {
            id: decl.id,
            place: decl.place,
            shown: raw.shown !== false,
            title: textOf(raw.title, 120).trim() || decl.title,
            text: textOf(raw.text, 200).trim(),
            icon: statusIcon(raw.icon) || decl.icon,
            tone: STATUS_TONES.indexOf(raw.tone) >= 0 ? raw.tone : "plain",
            lines: (Array.isArray(raw.lines) ? raw.lines : []).map(l => textOf(l, 120).trim()).filter(Boolean).slice(0, 8),
            actions: actions,
            click: click,
            progress: isFinite(progress) && progress >= 0 ? Math.min(1, progress) : -1,
            notes: actions.reduce((out, a) => out.concat(a.notes), [])
        }
    };
}

function coldLine(id) {
    return activateLine(0, id, "", "", "cold");
}

function statusLine(id, action) {
    return activateLine(0, id, action, "", "status");
}

function commandOf(plugin, text) {
    var typed = text.replace(/^\s+/, "");
    var lower = typed.toLowerCase();
    for (var command of plugin.commands || [])
        if (lower.indexOf(`${command.word} `) === 0)
            return { command: command, rest: typed.slice(command.word.length + 1) };
    return null;
}

function argumentsFrom(command, rest) {
    var out = [];
    var left = rest.replace(/^\s+/, "");
    command.arguments.forEach((arg, i) => {
        if (i === command.arguments.length - 1) {
            out.push(left.trim());
            return;
        }
        var cut = left.search(/\s/);
        out.push(cut < 0 ? left : left.slice(0, cut));
        left = cut < 0 ? "" : left.slice(cut).replace(/^\s+/, "");
    });
    return out;
}

function completionOf(arg, typed) {
    var t = typed.trim().toLowerCase();
    if (!t)
        return null;
    return arg.choices.find(c => c.title.toLowerCase().indexOf(t) === 0) || arg.choices.find(c => c.value.toLowerCase().indexOf(t) === 0) || null;
}

function argumentValues(command, texts) {
    var values = {};
    var missing = [];
    command.arguments.forEach((arg, i) => {
        var typed = (texts[i] || "").trim();
        var exact = arg.choices.find(c => c.title.toLowerCase() === typed.toLowerCase() || c.value.toLowerCase() === typed.toLowerCase());
        var value = exact ? exact.value : arg.type === "choice" ? "" : typed;
        values[arg.key] = value;
        if ((arg.required || (arg.type === "choice" && typed)) && !value)
            missing.push(arg.key);
    });
    return { values: values, missing: missing };
}

function commandLine(word, values) {
    return JSON.stringify({ type: "command", word: word, arguments: values });
}

function openLine() {
    return JSON.stringify({ type: "open" });
}

function closeLine() {
    return JSON.stringify({ type: "close" });
}

function cancelLine(seq) {
    return JSON.stringify({ type: "cancel", seq: seq });
}

var SHORTCUT_MODS = { ctrl: "CTRL", control: "CTRL", alt: "ALT", shift: "SHIFT" };

var SHORTCUT_KEYS = { enter: "RETURN", return: "RETURN", backspace: "BACKSPACE", delete: "DELETE", del: "DELETE", space: "SPACE", insert: "INSERT", comma: "COMMA", ",": "COMMA", period: "PERIOD", ".": "PERIOD", minus: "MINUS", "-": "MINUS", equal: "EQUAL", "=": "EQUAL", slash: "SLASH", "/": "SLASH", semicolon: "SEMICOLON", ";": "SEMICOLON", "[": "BRACKETLEFT", "]": "BRACKETRIGHT" };

var TAKEN_CHORDS = ["CTRL+K", "CTRL+RETURN", "CTRL+A", "CTRL+C", "CTRL+V", "CTRL+X", "CTRL+Z", "CTRL+Y", "CTRL+SHIFT+Z", "CTRL+BACKSPACE", "CTRL+DELETE", "CTRL+INSERT", "CTRL+SHIFT+V", "CTRL+U", "CTRL+SHIFT+RETURN"];

function chordKey(chord) {
    var parts = chord.split("+").map(p => p.trim()).filter(Boolean);
    var key = parts.pop();
    return ["CTRL", "ALT", "SHIFT"].filter(m => parts.indexOf(m) >= 0).concat([key]).join("+");
}

function readShortcut(raw) {
    var text = textOf(raw, 60).trim().toLowerCase();
    if (!text)
        return { chord: "" };
    var parts = text.split("+").map(p => p.trim());
    var key = parts.pop();
    var mods = [];
    for (var p of parts) {
        var mod = SHORTCUT_MODS[p];
        if (!mod || mods.indexOf(mod) >= 0)
            return { refusal: `refused the shortcut ${text}: modifiers are ctrl, alt and shift` };
        mods.push(mod);
    }
    var name = /^[a-z0-9]$/.test(key) ? key.toUpperCase() : /^f([1-9]|1[0-9]|2[0-4])$/.test(key) ? key.toUpperCase() : SHORTCUT_KEYS[key];
    if (!name)
        return { refusal: `refused the shortcut ${text}: ${key || "nothing"} is not a key it can use` };
    if (mods.indexOf("SHIFT") >= 0 && !/^[A-Z0-9]$|^F\d+$|^(RETURN|BACKSPACE|DELETE|SPACE|INSERT)$/.test(name))
        return { refusal: `refused the shortcut ${text}: shift changes what ${key} types, so the chord could never be pressed` };
    if (mods.indexOf("CTRL") < 0 && mods.indexOf("ALT") < 0)
        return { refusal: `refused the shortcut ${text}: it needs ctrl or alt, or it would type into the search` };
    var chord = chordKey(mods.concat([name]).join("+"));
    if (TAKEN_CHORDS.indexOf(chord) >= 0)
        return { refusal: `refused the shortcut ${text}: the launcher already uses it` };
    return { chord: chord };
}

function chordLabel(chord) {
    var names = { CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift", RETURN: "Enter", BACKSPACE: "Backspace", DELETE: "Delete", SPACE: "Space", INSERT: "Insert", COMMA: ",", PERIOD: ".", MINUS: "-", EQUAL: "=", SLASH: "/", SEMICOLON: ";", BRACKETLEFT: "[", BRACKETRIGHT: "]" };
    return chord ? chord.split("+").map(p => names[p] || p).join(" ") : "";
}

function readAction(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    var id = textOf(raw.id, 200);
    var title = textOf(raw.title).trim();
    if (!id || !title)
        return null;
    var shortcut = readShortcut(raw.shortcut);
    return Object.assign(readDoing(raw), { id: id, title: title, icon: textOf(raw.icon, 64), chord: shortcut.chord || "", notes: shortcut.refusal ? [shortcut.refusal] : [] });
}

function chordsOf(actions) {
    var seen = {};
    for (var a of actions) {
        if (!a.chord)
            continue;
        if (seen[a.chord]) {
            a.notes = a.notes.concat([`refused the shortcut ${chordLabel(a.chord)} on ${a.title}: ${seen[a.chord]} has it already`]);
            a.chord = "";
        } else
            seen[a.chord] = a.title;
    }
    return actions;
}

function actionOf(actions, chord) {
    return chord ? actions.find(a => a.chord === chord) || null : null;
}

function imageOf(raw, folder) {
    var t = textOf(raw, 4096).trim();
    if (/^https:\/\//i.test(t))
        return t;
    if (t.charAt(0) === "/")
        return fileUrl(t);
    if (folder && t && !SCHEME.test(t) && t.split("/").indexOf("..") < 0)
        return fileUrl(`${folder}/${t.replace(/^\.\//, "")}`);
    return "";
}

function qmlOf(raw, folder) {
    if (!given(raw))
        return { file: "" };
    var t = textOf(raw, 400).replace(/^\.\//, "");
    if (!folder || !QML_PATH.test(t) || t.split("/").indexOf("..") >= 0)
        return { file: "", note: `refused ${textOf(raw, 80)}: a QML file is a path inside the plugin's folder` };
    return { file: `${folder}/${t}` };
}

function propsOf(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return {};
    var text = JSON.stringify(raw);
    return text.length > PROPS_LIMIT ? {} : JSON.parse(text);
}

function factsOf(raw) {
    return (Array.isArray(raw) ? raw : []).filter(f => f && typeof f === "object").map(f => ({ label: textOf(f.label, 80).trim(), value: textOf(f.value, 500) })).filter(f => f.label && f.value).slice(0, 30);
}

function readPreview(raw, folder) {
    if (typeof raw === "string")
        return raw.trim() ? { text: textOf(raw, 20000) } : null;
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    if (given(raw.qml)) {
        var drawn = qmlOf(raw.qml, folder);
        return drawn.file ? { qml: drawn.file } : { note: drawn.note };
    }
    if (given(raw.image))
        return imageOf(raw.image, folder) ? { image: imageOf(raw.image, folder) } : null;
    if (given(raw.file)) {
        var file = textOf(raw.file, 4096);
        return file.charAt(0) === "/" ? { file: file } : null;
    }
    var facts = factsOf(raw.facts);
    if (facts.length)
        return { facts: facts, text: textOf(raw.text, 20000) };
    return given(raw.text) ? { text: textOf(raw.text, 20000) } : null;
}

function readItem(raw, folder) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    var id = textOf(raw.id, 200);
    var title = textOf(raw.title).trim();
    if (!id || !title)
        return null;
    var keywords = Array.isArray(raw.keywords) ? raw.keywords.filter(w => typeof w === "string").map(w => w.slice(0, 64)).slice(0, 32) : [];
    var actions = chordsOf((Array.isArray(raw.actions) ? raw.actions : []).map(readAction).filter(Boolean).slice(0, 12));
    var drawn = qmlOf(raw.qml, folder);
    var preview = readPreview(raw.preview, folder);
    var notes = [drawn.note, preview?.note].filter(Boolean).concat(actions.reduce((out, a) => out.concat(a.notes), []));
    return Object.assign(readDoing(raw), {
        id: id,
        title: title,
        subtitle: textOf(raw.subtitle).trim(),
        icon: iconOf(raw.icon, folder || ""),
        keywords: keywords,
        actions: actions,
        height: raw.height === "auto" ? 0 : Math.max(1, Math.min(TALLEST, Math.round(Number(raw.height) || 1))),
        text: textOf(raw.text, 2000).trim(),
        image: imageOf(raw.image, folder || ""),
        tags: (Array.isArray(raw.tags) ? raw.tags : []).map(t => textOf(t, 40).trim()).filter(Boolean).slice(0, 4),
        answer: raw.answer === true,
        pin: raw.pin === true,
        qml: drawn.file,
        preview: preview && !preview.note ? preview : null,
        props: propsOf(raw.props),
        notes: notes
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

function readChoices(raw, titleLimit, cap) {
    var out = [];
    for (var c of Array.isArray(raw) ? raw : []) {
        var value = textOf(c && typeof c === "object" ? c.value : c, 200);
        if (!value || out.some(o => o.value === value))
            continue;
        out.push({ value: value, title: (c && typeof c === "object" ? textOf(c.title, titleLimit).trim() : "") || textOf(value, titleLimit) });
        if (out.length >= cap)
            break;
    }
    return out;
}

function pickedOf(choices, raw) {
    var value = textOf(raw, 200);
    return choices.some(c => c.value === value) ? value : choices[0].value;
}

function readField(raw) {
    if (!raw || typeof raw !== "object" || !PREF_KEY.test(raw.key) || FIELD_TYPES.indexOf(raw.type) < 0)
        return null;
    var choices = raw.type === "choice" ? readChoices(raw.choices, 300, 20) : [];
    if (raw.type === "choice" && !choices.length)
        return null;
    var value = raw.type === "toggle" ? raw.value === true : raw.type === "choice" ? pickedOf(choices, raw.value) : textOf(raw.value, 4096);
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

function readDropdown(raw) {
    if (!raw || typeof raw !== "object" || Array.isArray(raw))
        return null;
    var choices = readChoices(raw.choices, 60, 12);
    if (!choices.length)
        return null;
    return {
        title: textOf(raw.title, 40).trim(),
        choices: choices,
        value: pickedOf(choices, raw.value)
    };
}

function dropdownLine(view, value) {
    return JSON.stringify({ type: "dropdown", view: view, value: value });
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
        actions: chordsOf((Array.isArray(raw.actions) ? raw.actions : []).map(readAction).filter(Boolean).slice(0, 8))
    };
    if (raw.kind === "detail") {
        view.text = textOf(raw.text, 20000);
        view.facts = factsOf(raw.facts);
    } else if (raw.kind === "list") {
        view.placeholder = textOf(raw.placeholder) || "Filter";
        view.items = readItems(raw.items, folder);
        view.dropdown = readDropdown(raw.dropdown);
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

function readMessage(line, folder, declared) {
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
    case "update":
        var item = readItem(raw.item, folder);
        return item ? { type: "update", item: item } : { error: "update without an item that has an id and a title" };
    case "status":
        var status = readStatus(raw.item, declared);
        return status.error ? { error: status.error } : { type: "status", item: status.item };
    case "choices":
        if (typeof raw.word !== "string" || !PREF_KEY.test(raw.key))
            return { error: "choices without a word and a key" };
        return { type: "choices", word: raw.word.toLowerCase(), key: raw.key, choices: readChoices(raw.choices, 60, 30) };
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

function rankOf(value) {
    return RANKS.indexOf(value) >= 0 ? value : "first";
}

function plainRows(items, typed, rank, place) {
    var lift = LIFT[rankOf(rank)];
    return items.map((item, i) => ({ item: item, i: i, score: item.pin ? Infinity : item.answer ? 4 : plainScore(item, typed, place) })).filter(m => m.score > 0).sort((a, b) => b.score - a.score || a.i - b.i).map(m => ({ item: m.item, score: m.score + lift }));
}

function kept(answer, asked) {
    return !!answer && !answer.late && answer.prefixed === asked.prefixed ? answer.items.filter(i => !i.pin && !i.answer) : [];
}

function updated(items, item) {
    var at = items.findIndex(i => i.id === item.id);
    return at < 0 ? null : items.slice(0, at).concat([item], items.slice(at + 1));
}

function notifyAllowed(last, now) {
    return !last || now - last >= NOTIFY_GAP;
}

function crashes(times, now) {
    var recent = times.filter(t => now - t < CRASH_WINDOW);
    return {
        recent: recent,
        off: recent.length >= CRASH_LIMIT,
        delay: recent.length ? Math.min(30000, 1000 * Math.pow(2, recent.length - 1)) : 0
    };
}
