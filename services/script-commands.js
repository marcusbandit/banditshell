.pragma library

var MODES = ["silent", "compact", "fullOutput", "inline", "list"];

var HEADER = /^\s*(?:#|\/\/|--|;)\s*@(raycast|banditshell)\.([A-Za-z0-9]+)\s+(.*?)\s*$/;

var ARGUMENT = /^argument([1-9])$/;

var ICON_NAME = /^[a-z0-9_]+$/;

var WEB = /^[a-z][a-z0-9+.-]*:\/\//i;

var LIST_LIMIT = 50;

var ALLOWED_LINK = /^(?:https?:\/\/|mailto:|file:\/\/\/)/i;

var SCHEME = /^([a-z][a-z0-9+.-]*):/i;

var GROUP_STOP = 'kill -TERM -- "-$1" 2>/dev/null || { kill -TERM "$1" 2>/dev/null; exit 0; }; sleep 1; kill -0 -- "-$1" 2>/dev/null && kill -KILL -- "-$1" 2>/dev/null; exit 0';

var ESCAPES = /\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07/g;

var SKIPPED = /\.(?:md|txt|json|png|jpe?g|svg|gif|webp|ico|log|bak|orig|swp)$|~$/i;

var IMAGE = /\.(?:png|jpe?g|svg|gif|webp|ico)$/i;

var MARK = "\x1e";

var LEADING_SPACE = /^\s+/;

var LISTING = /^(?:scripts|script commands|my scripts)$/i;

var QUOTED = /^(["'])(.*)\1$/;

var WORD = /"([^"]*)"|'([^']*)'|(\S+)/g;

function baseName(path) {
    var s = String(path || "");
    return s.slice(s.lastIndexOf("/") + 1);
}

function folderOf(path) {
    var s = String(path || "");
    var cut = s.lastIndexOf("/");
    return cut > 0 ? s.slice(0, cut) : "/";
}

function stem(fileName) {
    var name = String(fileName || "");
    var dot = name.lastIndexOf(".");
    return dot > 0 ? name.slice(0, dot) : name;
}

function titleFromFile(fileName) {
    var words = stem(fileName).replace(/[-_.]+/g, " ").replace(/\s+/g, " ").trim();
    return words ? words.charAt(0).toUpperCase() + words.slice(1) : String(fileName || "");
}

function readArgument(text) {
    var parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return null;
    }
    if (!parsed || typeof parsed !== "object")
        return null;
    var type = ["text", "password", "dropdown"].indexOf(parsed.type) >= 0 ? parsed.type : "text";
    var choices = Array.isArray(parsed.data) ? parsed.data.filter(d => d && d.value !== undefined).map(d => ({
                title: String(d.title ?? d.value),
                value: String(d.value)
            })) : [];
    return {
        type: type,
        placeholder: String(parsed.placeholder || (type === "dropdown" ? "choice" : "argument")),
        optional: !!parsed.optional,
        percentEncoded: !!parsed.percentEncoded,
        choices: choices
    };
}

function interpreterOf(firstLine) {
    var m = /^#!\s*(\S+)(?:\s+(.*))?$/.exec(String(firstLine || "").trim());
    if (!m)
        return null;
    return [m[1]].concat((m[2] || "").split(/\s+/).filter(Boolean));
}

function parseScript(path, head, executable) {
    var file = baseName(path);
    var lines = String(head || "").split("\n");
    var fields = {};
    var own = {};
    var args = [];
    for (var i = 0; i < lines.length; i++) {
        var m = HEADER.exec(lines[i]);
        if (!m)
            continue;
        var key = m[2];
        var arg = ARGUMENT.exec(key);
        if (arg) {
            var parsed = readArgument(m[3]);
            if (parsed)
                args[Number(arg[1]) - 1] = parsed;
        } else if (m[1] === "banditshell") {
            if (own[key] === undefined)
                own[key] = m[3];
        } else if (fields[key] === undefined) {
            fields[key] = m[3];
        }
    }
    fields = Object.assign(fields, own);
    var interpreter = interpreterOf(lines[0]);
    var raycast = Object.keys(fields).length > 0 || args.length > 0;
    if (!executable && !interpreter && !raycast)
        return null;
    var icon = String(fields.icon || "");
    var iconFile = icon && (IMAGE.test(icon) || icon.indexOf("/") >= 0) ? (icon.charAt(0) === "/" || /^[a-z]+:\/\//i.test(icon) ? icon : `${folderOf(path)}/${icon}`) : "";
    return {
        path: path,
        file: file,
        word: stem(file).replace(/[-_.]+/g, " ").toLowerCase(),
        title: String(fields.title || titleFromFile(file)),
        mode: MODES.indexOf(fields.mode) >= 0 ? fields.mode : "compact",
        icon: iconFile ? "" : icon,
        iconFile: iconFile,
        packageName: String(fields.packageName || ""),
        description: String(fields.description || ""),
        arguments: args.filter(Boolean).slice(0, 3),
        selects: String(fields.onSelect || "").toLowerCase() === "run",
        executable: !!executable,
        interpreter: interpreter
    };
}

function readScan(text) {
    var out = [];
    var chunks = String(text || "").split(MARK);
    for (var i = 0; i < chunks.length; i++) {
        var chunk = chunks[i];
        var cut = chunk.indexOf("\n");
        if (cut < 0)
            continue;
        var top = chunk.slice(0, cut);
        var tab = top.indexOf("\t");
        if (tab < 0)
            continue;
        var path = top.slice(tab + 1);
        if (!path || SKIPPED.test(path))
            continue;
        var script = parseScript(path, chunk.slice(cut + 1), top.slice(0, tab) === "1");
        if (script)
            out.push(script);
    }
    return out.sort((a, b) => a.title.toLowerCase() < b.title.toLowerCase() ? -1 : a.title.toLowerCase() > b.title.toLowerCase() ? 1 : 0);
}

function splitWords(text) {
    var out = [];
    var m;
    WORD.lastIndex = 0;
    while ((m = WORD.exec(text)) !== null)
        out.push(m[1] !== undefined ? m[1] : m[2] !== undefined ? m[2] : m[3]);
    return out;
}

function argumentsFrom(rest, count) {
    var text = String(rest || "").trim();
    if (count <= 0 || !text)
        return [];
    if (count === 1)
        return [QUOTED.test(text) ? text.slice(1, -1) : text];
    var words = splitWords(text);
    if (words.length <= count)
        return words;
    return words.slice(0, count - 1).concat([words.slice(count - 1).join(" ")]);
}

function askFor(script, text) {
    var typed = String(text || "").replace(LEADING_SPACE, "");
    var lower = typed.toLowerCase();
    var heads = [script.title.toLowerCase(), script.word].filter((h, i, all) => h && all.indexOf(h) === i);
    for (var i = 0; i < heads.length; i++) {
        var head = heads[i];
        if (lower === head)
            return {
                exact: true,
                values: []
            };
        var lists = script.mode === "list";
        if ((script.arguments.length || lists) && lower.indexOf(head + " ") === 0)
            return {
                exact: true,
                values: argumentsFrom(typed.slice(head.length + 1), lists ? Math.max(1, script.arguments.length) : script.arguments.length)
            };
    }
    return null;
}

function ambientScore(place) {
    return place >= 2 ? 0.25 + place * 0.05 : 0;
}

function listAsk(text) {
    return LISTING.test(String(text || "").trim());
}

function missing(script, values) {
    return script.arguments.filter((a, i) => !a.optional && !(values[i] ?? "")).map(a => a.placeholder);
}

function baseCommand(script) {
    if (script.executable)
        return [script.path];
    if (script.interpreter)
        return script.interpreter.concat([script.path]);
    return ["sh", script.path];
}

function commandFor(script, values) {
    var count = script.mode === "list" ? Math.max(script.arguments.length, values.length) : script.arguments.length;
    var args = [];
    for (var i = 0; i < count; i++) {
        var v = String(values[i] ?? "");
        args.push(script.arguments[i]?.percentEncoded ? encodeURIComponent(v) : v);
    }
    while (args.length && !args[args.length - 1] && (script.arguments[args.length - 1]?.optional ?? true))
        args.pop();
    return baseCommand(script).concat(args);
}

function selectCommand(script, arg) {
    return baseCommand(script).concat(["--select", String(arg ?? "")]);
}

function firstLine(text) {
    var lines = outputLines(text, 400);
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line)
            return line.length > 200 ? `${line.slice(0, 200)}…` : line;
    }
    return "";
}

function textOf(value) {
    if (value === undefined || value === null)
        return "";
    if (Array.isArray(value))
        return value.map(textOf).filter(Boolean).join(" ");
    return typeof value === "object" ? "" : String(value);
}

function expandHome(path, home) {
    var p = String(path || "");
    return home && (p === "~" || p.indexOf("~/") === 0) ? `${home}${p.slice(1)}` : p;
}

function iconOf(icon, folder, home) {
    var raw = icon && typeof icon === "object" ? icon.type === "fileicon" || icon.type === "filetype" ? "" : textOf(icon.path) : textOf(icon);
    var t = raw.trim();
    if (!t)
        return {};
    if (WEB.test(t))
        return {};
    if (t.indexOf("/") >= 0 || IMAGE.test(t))
        return {
            file: t.charAt(0) === "/" ? t : t.indexOf("~/") === 0 ? expandHome(t, home) : `${folder}/${t}`
        };
    if (ICON_NAME.test(t))
        return {
            name: t
        };
    return t.length <= 8 ? {
        glyph: t
    } : {};
}

function readItem(raw, folder, home) {
    if (!raw || typeof raw !== "object")
        return null;
    var title = textOf(raw.title).trim();
    if (!title)
        return null;
    var text = raw.text && typeof raw.text === "object" ? raw.text : {};
    var type = textOf(raw.type).toLowerCase();
    var arg = textOf(raw.arg);
    var file = type.indexOf("file") === 0 && !!arg;
    var icon = iconOf(raw.icon, folder, home);
    var url = textOf(raw.url || raw.quicklookurl).trim();
    var path = file ? expandHome(arg, home) : arg;
    return {
        uid: textOf(raw.uid),
        title: title,
        subtitle: textOf(raw.subtitle).trim(),
        arg: path,
        url: url,
        linkRefusal: linkRefusal(url),
        fileRefusal: file ? fileRefusal(path) : "",
        copy: textOf(raw.copy !== undefined ? raw.copy : text.copy),
        file: file,
        valid: raw.valid !== false,
        autocomplete: textOf(raw.autocomplete),
        icon: icon.name || "",
        glyph: icon.glyph || "",
        iconFile: icon.file || ""
    };
}

function readItems(text, folder, home, limit) {
    var parsed;
    try {
        parsed = JSON.parse(String(text || "").trim());
    } catch (e) {
        return null;
    }
    var list = Array.isArray(parsed) ? parsed : parsed && Array.isArray(parsed.items) ? parsed.items : null;
    if (!list)
        return null;
    var out = [];
    for (var i = 0; i < list.length && out.length < (limit || LIST_LIMIT); i++) {
        var item = readItem(list[i], folder, home);
        if (item)
            out.push(item);
    }
    return out;
}

function readList(code, out, err, folder, home, limit) {
    if (code !== 0)
        return {
            items: [],
            error: firstLine(err) || firstLine(out) || `exit ${code}`,
            code: code
        };
    var items = readItems(out, folder, home, limit);
    if (items === null)
        return {
            items: [],
            error: firstLine(err) || "printed no items",
            code: code
        };
    return {
        items: items,
        error: "",
        code: code
    };
}

function linkRefusal(link) {
    var t = String(link || "");
    if (!t)
        return "";
    if (t.charAt(0) === "-")
        return "refused a link starting with -";
    if (ALLOWED_LINK.test(t))
        return "";
    var m = SCHEME.exec(t);
    return m ? `refused a ${m[1].toLowerCase()}: link` : "refused a link with no scheme";
}

function fileRefusal(path) {
    var t = String(path || "");
    if (t.charAt(0) === "-")
        return "refused a file starting with -";
    return t.charAt(0) === "/" ? "" : "refused a file path that is not absolute";
}

function refusalOf(item) {
    return item.linkRefusal || item.fileRefusal || "";
}

function itemAction(item, selects) {
    if (!item.valid)
        return item.autocomplete ? "complete" : "";
    if (selects)
        return "run";
    if (item.url && !item.linkRefusal)
        return "url";
    if (item.copy)
        return "copy";
    if (item.url)
        return "refused";
    if (item.file)
        return item.fileRefusal ? "refused" : "file";
    return WEB.test(item.arg) && !linkRefusal(item.arg) ? "url" : "copy";
}

function groupCommand(command, grouped) {
    return grouped ? ["setsid"].concat(command) : command;
}

function stopGroupCommand(pid) {
    var id = Math.round(Number(pid));
    return id > 1 ? ["sh", "-c", GROUP_STOP, "sh", String(id)] : null;
}

function outputLines(text, limit) {
    return String(text || "").replace(ESCAPES, "").split("\n").map(l => l.replace(/\s+$/, "")).filter(l => l.trim()).slice(-(limit || 40));
}

function lastLine(text) {
    var lines = outputLines(text, 1);
    return lines.length ? lines[0].trim() : "";
}

function runKey(script, values) {
    return [script.path].concat(values || []).join("\x1f");
}
