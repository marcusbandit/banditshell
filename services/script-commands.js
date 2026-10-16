.pragma library

var MODES = ["silent", "compact", "fullOutput", "inline"];

var HEADER = /^\s*(?:#|\/\/|--|;)\s*@raycast\.([A-Za-z0-9]+)\s+(.*?)\s*$/;

var ESCAPES = /\x1b\[[0-9;?]*[A-Za-z]|\x1b\][^\x07]*\x07/g;

var SKIPPED = /\.(?:md|txt|json|png|jpe?g|svg|gif|webp|ico|log|bak|orig|swp)$|~$/i;

var IMAGE = /\.(?:png|jpe?g|svg|gif|webp|ico)$/i;

var MARK = "\x1e";

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
    var args = [];
    for (var i = 0; i < lines.length; i++) {
        var m = HEADER.exec(lines[i]);
        if (!m)
            continue;
        var key = m[1];
        var arg = /^argument([1-9])$/.exec(key);
        if (arg) {
            var parsed = readArgument(m[2]);
            if (parsed)
                args[Number(arg[1]) - 1] = parsed;
        } else if (fields[key] === undefined) {
            fields[key] = m[2];
        }
    }
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
    var typed = String(text || "").replace(/^\s+/, "");
    var lower = typed.toLowerCase();
    var heads = [script.title.toLowerCase(), script.word].filter((h, i, all) => h && all.indexOf(h) === i);
    for (var i = 0; i < heads.length; i++) {
        var head = heads[i];
        if (lower === head)
            return {
                exact: true,
                values: []
            };
        if (script.arguments.length && lower.indexOf(head + " ") === 0)
            return {
                exact: true,
                values: argumentsFrom(typed.slice(head.length + 1), script.arguments.length)
            };
    }
    return null;
}

function listAsk(text) {
    return LISTING.test(String(text || "").trim());
}

function missing(script, values) {
    return script.arguments.filter((a, i) => !a.optional && !(values[i] ?? "")).map(a => a.placeholder);
}

function commandFor(script, values) {
    var args = script.arguments.map((a, i) => {
        var v = String(values[i] ?? "");
        return a.percentEncoded ? encodeURIComponent(v) : v;
    });
    while (args.length && !args[args.length - 1] && script.arguments[args.length - 1].optional)
        args.pop();
    if (script.executable)
        return [script.path].concat(args);
    if (script.interpreter)
        return script.interpreter.concat([script.path], args);
    return ["sh", script.path].concat(args);
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

var EXAMPLE = `#!/bin/sh

# @raycast.schemaVersion 1
# @raycast.title Hello
# @raycast.mode compact
# @raycast.icon 👋
# @raycast.packageName Examples
# @raycast.argument1 { "type": "text", "placeholder": "name", "optional": true }

echo "Hello, \${1:-world}. It is $(date +%H:%M)."
`;
