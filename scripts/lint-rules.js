#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const BASELINE_FILE = "rules.baseline.json";
const SHOW_LIMIT = 40;
const MAX_FILE_BYTES = 2 * 1024 * 1024;
const NODE_ONLY_DIRS = ["tests/", "scripts/"];
const NODE_ONLY_FILES = ["services/cli-migration.js"];
const PALETTE_HOMES = ["config/", "installer/theme.js"];
const OWN_AT_RECEIVERS = ["Frames", "layout", "rounding"];
const QMLDIR_FIXED = ["config", "services", "components", "components/blob", "components/marks"];

const LOOPING_CLOCKS = [
    { file: "components/BatteryMeter.qml", scope: "infinite", reason: "the battery charge sweep and the low-charge throb" },
    { file: "components/ScrollingText.qml", scope: "infinite", reason: "the scrolling-text marquee" },
    { file: "modules/island/ActivityBubble.qml", scope: "infinite", reason: "the activity bubble spinner" },
    { file: "modules/island/ActivityRow.qml", scope: "infinite", reason: "the activity row spinner" },
    { file: "modules/media/Equalizer.qml", scope: "infinite", reason: "the equalizer" },
    { file: "modules/media/LyricLine.qml", scope: "infinite", reason: "the lyric line's sung-gap clock" },
    { file: "modules/media/MediaController.qml", scope: "infinite", reason: "the lyrics loading pulse" },
    { file: "modules/media/Scrubber.qml", scope: "infinite", reason: "the scrubber's wave phase" },
    { file: "modules/settings/MiniWorkspaces.qml", scope: "infinite", reason: "a demo clock of the settings scenes" },
    { file: "modules/settings/scenes/SceneClock.qml", scope: "infinite", reason: "the demo clock of the settings scenes" },
    { file: "modules/settings/scenes/DefaultsScene.qml", scope: "all", reason: "a demo clock of the settings scenes" },
    { file: "modules/settings/scenes/UsageScene.qml", scope: "all", reason: "a demo clock of the settings scenes" },
    { file: "modules/settings/widgets/ViaWidget.qml", scope: "infinite", reason: "the settings keyboard widget spinner" }
];

const SPRING_EASINGS = /\bEasing\.(?:In|Out|InOut|OutIn)?(?:Back|Elastic|Bounce)\b/g;
const ANIMATION_NODE = /(?<![\w.])(Behavior|(?:Number|Color|Property|Spring|Smoothed|Sequential|Parallel|Rotation)Animation|\w+Animator|\w+Animation(?=\s+on\s))\s*(?:on\s+[\w.]+\s*)?\{/g;
const ENGINE_GAPS = [
    ["matchAll", /\.matchAll\s*\(/],
    ["flat", /\.flat\s*\(/],
    ["flatMap", /\.flatMap\s*\(/],
    ["Object.fromEntries", /\bObject\.fromEntries\b/],
    ["replaceAll", /\.replaceAll\s*\(/],
    ["at", /\.at\s*\(/],
    ["structuredClone", /\bstructuredClone\b/]
];
const HEX_COLOUR = /#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{3,4})(?![\w])/g;
const COLOUR_CALL = /(?<![\w.])Qt\.(rgba|hsla|hsva|tint|lighter|darker)\s*\(/g;
const OBJECT_MEMBERS = ["objectName", "objectNameChanged", "destroyed", "deleteLater", "toString", "data", "dataChanged"];
const REGEX_BEFORE = new Set("(,=:[!&|?{};+-*%<>~^".split(""));
const REGEX_AFTER_WORD = new Set(["return", "typeof", "case", "do", "else", "in", "of", "new", "delete", "void", "throw", "yield"]);

function blank(text) {
    return text.replace(/[^\n]/g, " ");
}

function lineIndex(text) {
    const starts = [0];
    for (let i = 0; i < text.length; i++)
        if (text[i] === "\n")
            starts.push(i + 1);
    return offset => {
        let low = 0;
        let high = starts.length - 1;
        while (low < high) {
            const mid = (low + high + 1) >> 1;
            if (starts[mid] <= offset)
                low = mid;
            else
                high = mid - 1;
        }
        return low + 1;
    };
}

function scanSource(source) {
    const code = [];
    const plain = [];
    const commentOffsets = [];
    const regexes = [];
    const braces = [];
    const at = lineIndex(source);
    let prevChar = "";
    let prevWord = "";
    let i = 0;

    const emit = (shown, kept, significant) => {
        code.push(shown);
        plain.push(kept);
        if (significant !== undefined) {
            prevChar = significant;
            prevWord = "";
        }
    };

    const templateText = () => {
        while (i < source.length) {
            const ch = source[i];
            if (ch === "\\") {
                emit(blank(source.slice(i, i + 2)), source.slice(i, i + 2));
                i += 2;
            } else if (ch === "`") {
                emit("`", "`", "`");
                i++;
                return;
            } else if (ch === "$" && source[i + 1] === "{") {
                emit("${", "${", "{");
                i += 2;
                braces.push("template");
                return;
            } else {
                emit(blank(ch), ch);
                i++;
            }
        }
    };

    const regexLiteral = () => {
        let j = i + 1;
        let inClass = false;
        while (j < source.length && source[j] !== "\n") {
            if (source[j] === "\\") {
                j += 2;
                continue;
            }
            if (source[j] === "[")
                inClass = true;
            else if (source[j] === "]")
                inClass = false;
            else if (source[j] === "/" && !inClass)
                break;
            j++;
        }
        let k = j + 1;
        while (k < source.length && /[a-z]/.test(source[k]))
            k++;
        const body = source.slice(i + 1, j);
        regexes.push({ body, flags: source.slice(j + 1, k), line: at(i) });
        emit(`/${blank(body)}${source.slice(j, k)}`, source.slice(i, k), "/");
        i = k;
    };

    while (i < source.length) {
        const ch = source[i];
        const next = source[i + 1];
        if (ch === "/" && (next === "/" || next === "*")) {
            const end = next === "/" ? source.indexOf("\n", i) : source.indexOf("*/", i + 2);
            const stop = end < 0 ? source.length : next === "/" ? end : end + 2;
            const text = source.slice(i, stop);
            commentOffsets.push(i);
            emit(blank(text), blank(text));
            i = stop;
        } else if (ch === "\"" || ch === "'") {
            let j = i + 1;
            while (j < source.length && source[j] !== ch && source[j] !== "\n")
                j += source[j] === "\\" ? 2 : 1;
            const closed = source[j] === ch;
            const stop = closed ? j + 1 : j;
            emit(ch + blank(source.slice(i + 1, j)) + (closed ? ch : ""), source.slice(i, stop), ch);
            i = stop;
        } else if (ch === "`") {
            emit("`", "`", "`");
            i++;
            templateText();
        } else if (ch === "{") {
            braces.push("block");
            emit(ch, ch, ch);
            i++;
        } else if (ch === "}") {
            emit(ch, ch, ch);
            i++;
            if (braces.pop() === "template")
                templateText();
        } else if (ch === "/") {
            if (prevChar === "" || REGEX_BEFORE.has(prevChar) || REGEX_AFTER_WORD.has(prevWord)) {
                regexLiteral();
            } else {
                emit(ch, ch, ch);
                i++;
            }
        } else if (/[\w$]/.test(ch)) {
            let j = i + 1;
            while (j < source.length && /[\w$]/.test(source[j]))
                j++;
            const word = source.slice(i, j);
            emit(word, word, word[word.length - 1]);
            prevWord = /^\d/.test(word) ? "" : word;
            i = j;
        } else {
            emit(ch, ch, /\s/.test(ch) ? undefined : ch);
            i++;
        }
    }
    return { code: code.join(""), plain: plain.join(""), commentLines: commentOffsets.map(at), regexes };
}

function matchingBrace(code, open) {
    let depth = 0;
    for (let i = open; i < code.length; i++) {
        if (code[i] === "{")
            depth++;
        else if (code[i] === "}" && --depth === 0)
            return i;
    }
    return -1;
}

function objectBlocks(code, typePattern, at) {
    const pattern = new RegExp(`(?<![\\w.])(${typePattern})\\s*(?:on\\s+[\\w.]+\\s*)?\\{`, "g");
    const blocks = [];
    let m;
    while ((m = pattern.exec(code)) !== null) {
        const open = m.index + m[0].length - 1;
        const close = matchingBrace(code, open);
        if (close < 0)
            continue;
        blocks.push({ type: m[1], start: m.index, open, close, line: at(m.index) });
    }
    return blocks;
}

function ownLevel(code, block) {
    const out = [];
    let depth = 0;
    for (let i = block.open; i <= block.close; i++) {
        const ch = code[i];
        if (ch === "{") {
            depth++;
            out.push(" ");
        } else if (ch === "}") {
            depth--;
            out.push(" ");
        } else {
            out.push(depth === 1 || ch === "\n" ? ch : " ");
        }
    }
    return out.join("");
}

function readValue(code, from) {
    let depth = 0;
    let value = "";
    for (let i = from; i < code.length && value.length < 600; i++) {
        const ch = code[i];
        if ("([{".includes(ch)) {
            depth++;
        } else if (")]}".includes(ch)) {
            if (depth === 0)
                break;
            depth--;
        } else if (ch === ";" && depth === 0) {
            break;
        } else if (ch === "\n" && depth === 0) {
            const trimmed = value.trimEnd();
            if (trimmed && !/[+\-*/?:,&|=<>]$/.test(trimmed))
                break;
        }
        value += ch;
    }
    return value.trim();
}

function ruleL1(ctx) {
    return ctx.scanned.commentLines.map(line => ({ line, detail: "comment" }));
}

function ruleL2(ctx) {
    const { code, at } = ctx.scanned;
    const found = [];
    const radius = /(?:^|[;{])[ \t]*(?:radius|topLeftRadius|topRightRadius|bottomLeftRadius|bottomRightRadius)[ \t]*:/gm;
    for (const block of objectBlocks(code, "Rectangle", at)) {
        const own = ownLevel(code, block);
        radius.lastIndex = 0;
        let m;
        while ((m = radius.exec(own)) !== null)
            found.push({ line: at(block.open + m.index + m[0].search(/\S/)), detail: "Rectangle with a radius" });
    }
    return found;
}

function loopsForever(code, block) {
    return /\bloops\s*:\s*Animation\.Infinite\b/.test(code.slice(block.open, block.close + 1));
}

function allowanceFor(file) {
    return LOOPING_CLOCKS.find(entry => entry.file === file) || null;
}

function ruleL3(ctx) {
    const { code, at } = ctx.scanned;
    const nodes = [];
    ANIMATION_NODE.lastIndex = 0;
    let m;
    while ((m = ANIMATION_NODE.exec(code)) !== null) {
        const open = m.index + m[0].length - 1;
        const close = matchingBrace(code, open);
        if (close >= 0)
            nodes.push({ type: m[1], open, close, line: at(m.index) });
    }
    const allowance = allowanceFor(ctx.file);
    const found = [];
    for (const node of nodes) {
        if (allowance) {
            if (allowance.scope === "all")
                continue;
            const looping = nodes.some(other => other.open <= node.open && other.close >= node.close && loopsForever(code, other));
            if (looping)
                continue;
        }
        found.push({ line: node.line, detail: node.type });
    }
    return found;
}

function ruleL4(ctx) {
    const { code, at } = ctx.scanned;
    const found = [];
    SPRING_EASINGS.lastIndex = 0;
    let m;
    while ((m = SPRING_EASINGS.exec(code)) !== null)
        found.push({ line: at(m.index), detail: m[0] });
    return found;
}

function isFontSizeLiteral(value) {
    const expression = value.includes("?") ? value.slice(value.indexOf("?") + 1) : value;
    if (/^[\s\d.+\-*/()]+$/.test(expression))
        return true;
    const literal = "(?<![\\w.$])\\d+(?:\\.\\d+)?(?![\\w])";
    return new RegExp(`[*/+\\-]\\s*${literal}|${literal}\\s*[*/+\\-]`).test(expression);
}

function ruleL5(ctx) {
    const { code, at } = ctx.scanned;
    const found = [];
    const seen = new Set();
    const add = (line, detail) => {
        if (!seen.has(line)) {
            seen.add(line);
            found.push({ line, detail });
        }
    };
    const assignments = [
        /(?:^|[;{])[ \t]*(?:[\w.]*\.)?(?:pixelSize|pointSize)[ \t]*(?::|=(?!=))/gm,
        /(?<![\w$])[\w$.]*font\.(?:pixelSize|pointSize)[ \t]*=(?!=)/g
    ];
    let m;
    for (const assignment of assignments) {
        while ((m = assignment.exec(code)) !== null) {
            const value = readValue(code, m.index + m[0].length);
            if (isFontSizeLiteral(value))
                add(at(m.index + m[0].search(/\S/)), `font size from a literal: ${value.replace(/\s+/g, " ")}`);
        }
    }
    return found;
}

function ruleL6(ctx) {
    const { code, plain, at } = ctx.scanned;
    const found = [];
    let m;
    HEX_COLOUR.lastIndex = 0;
    while ((m = HEX_COLOUR.exec(plain)) !== null)
        if (code[m.index] !== "#")
            found.push({ line: at(m.index), detail: `hex colour ${m[0]}` });
    COLOUR_CALL.lastIndex = 0;
    while ((m = COLOUR_CALL.exec(code)) !== null)
        found.push({ line: at(m.index), detail: `Qt.${m[1]}` });
    return found;
}

function ruleL7(ctx) {
    const { code, at } = ctx.scanned;
    const found = [];
    const colour = /(?:^|[;{])[ \t]*color[ \t]*:/gm;
    for (const block of objectBlocks(code, "StyledText|Text", at)) {
        const own = ownLevel(code, block);
        colour.lastIndex = 0;
        let m;
        while ((m = colour.exec(own)) !== null) {
            const value = readValue(code, block.open + m.index + m[0].length);
            if (/\btextGhost\b/.test(value))
                found.push({ line: at(block.open + m.index + m[0].search(/\S/)), detail: `${block.type} coloured textGhost` });
        }
    }
    return found;
}

function ruleL8(ctx) {
    const found = [];
    ctx.text.split("\n").forEach((line, index) => {
        const dash = /[\u2013\u2014]/.exec(line);
        if (dash)
            found.push({ line: index + 1, detail: dash[0] === "\u2014" ? "em dash" : "en dash" });
    });
    return found;
}

function ruleL9(ctx) {
    const { code, plain, regexes, at } = ctx.scanned;
    const found = [];
    for (const [name, pattern] of ENGINE_GAPS) {
        const global = new RegExp(pattern.source, "g");
        let m;
        while ((m = global.exec(code)) !== null) {
            const receiver = /([\w$]+)\s*$/.exec(code.slice(Math.max(0, m.index - 40), m.index));
            if (name === "at" && receiver && OWN_AT_RECEIVERS.includes(receiver[1]))
                continue;
            found.push({ line: at(m.index), detail: name });
        }
    }
    const lookbehind = /\(\?<[=!]/g;
    let m;
    while ((m = lookbehind.exec(plain)) !== null)
        found.push({ line: at(m.index), detail: "regex lookbehind" });
    return found.concat(regexes.filter(r => /\(\?<[=!]/.test(r.body) && !found.some(f => f.line === r.line && f.detail === "regex lookbehind")).map(r => ({ line: r.line, detail: "regex lookbehind" })));
}

function isQmlOrJs(file) {
    return file.endsWith(".qml") || file.endsWith(".js");
}

function isShellCode(file) {
    return isQmlOrJs(file) && !NODE_ONLY_DIRS.some(dir => file.startsWith(dir)) && !NODE_ONLY_FILES.includes(file);
}

const RULES = [
    { id: "L1", reason: "No comments in code. None. Clear names instead.", appliesTo: isQmlOrJs, check: ruleL1 },
    { id: "L2", reason: "Every rounded shape is components/SquircleRect.qml, never Rectangle.radius.", appliesTo: f => f.endsWith(".qml"), check: ruleL2 },
    { id: "L3", reason: "Anything that moves goes through components/Follow.qml; a Behavior or an Animation node is a bug unless it is a looping clock (DESIGN 2.3).", appliesTo: f => f.endsWith(".qml"), check: ruleL3 },
    { id: "L4", reason: "Spring and bounce are not in this shell (DESIGN 2.3).", appliesTo: isQmlOrJs, check: ruleL4 },
    { id: "L5", reason: "Font sizes only from Appearance: small, normal, large, and display for the island clock.", appliesTo: f => f.endsWith(".qml"), check: ruleL5 },
    { id: "L6", reason: "Colours only from Appearance.colour.* tokens; literals and Qt.rgba live in config/.", appliesTo: f => isShellCode(f) && !PALETTE_HOMES.some(dir => f.startsWith(dir)), check: ruleL6 },
    { id: "L7", reason: "textGhost is for decorative rules, never the colour of text.", appliesTo: f => f.endsWith(".qml"), check: ruleL7 },
    { id: "L8", reason: "No em dashes or en dashes anywhere; use a comma, colon, semicolon or hyphen.", appliesTo: () => true, check: ruleL8, wantsText: true },
    { id: "L9", reason: "Quickshell's JS engine lacks matchAll, flat, flatMap, Object.fromEntries, at, structuredClone and regex lookbehind, and replaceAll is risky.", appliesTo: isShellCode, check: ruleL9 },
    { id: "L10", reason: "Every QML folder carries a qmldir that matches scripts/qmldirs.sh; run it after adding, moving or renaming a file.", appliesTo: () => false, check: null, whole: true },
    { id: "L11", reason: "Name.member on a singleton must name a member that singleton declares; a renamed or moved member reads as undefined at runtime.", appliesTo: () => false, check: null, whole: true }
];

function ruleById(id) {
    return RULES.find(rule => rule.id === id) || null;
}

function walk(root, relative, out) {
    let entries;
    try {
        entries = fs.readdirSync(path.join(root, relative), { withFileTypes: true });
    } catch {
        return;
    }
    for (const entry of entries) {
        if (entry.name.startsWith(".") || entry.name === "node_modules")
            continue;
        const child = relative ? `${relative}/${entry.name}` : entry.name;
        if (entry.isDirectory())
            walk(root, child, out);
        else if (entry.isFile())
            out.push(child);
    }
}

function listFiles(root) {
    if (fs.existsSync(path.join(root, ".git"))) {
        try {
            const raw = execFileSync("git", ["ls-files", "-z"], { cwd: root, encoding: "utf8", maxBuffer: 64 * 1024 * 1024 });
            return raw.split("\0").filter(file => file && fs.existsSync(path.join(root, file))).sort();
        } catch {
        }
    }
    const files = [];
    walk(root, "", files);
    return files.sort();
}

function readTextFile(root, file) {
    const full = path.join(root, file);
    let stat;
    try {
        stat = fs.statSync(full);
    } catch {
        return null;
    }
    if (!stat.isFile() || stat.size > MAX_FILE_BYTES)
        return null;
    const buffer = fs.readFileSync(full);
    return buffer.includes(0) ? null : buffer.toString("utf8");
}

function qmldirDirectories(root) {
    const dirs = QMLDIR_FIXED.slice();
    const subdirectories = relative => {
        try {
            return fs.readdirSync(path.join(root, relative), { withFileTypes: true })
                .filter(entry => entry.isDirectory() && !entry.name.startsWith("."))
                .map(entry => `${relative}/${entry.name}`)
                .sort();
        } catch {
            return [];
        }
    };
    dirs.push("modules");
    const children = subdirectories("modules");
    dirs.push(...children);
    for (const child of children)
        dirs.push(...subdirectories(child));
    dirs.push("previews");
    return dirs;
}

function expectedQmldir(root, dir) {
    let names;
    try {
        names = fs.readdirSync(path.join(root, dir), { withFileTypes: true })
            .filter(entry => entry.isFile() && entry.name.endsWith(".qml"))
            .map(entry => `${dir}/${entry.name}`)
            .sort()
            .map(full => full.slice(dir.length + 1));
    } catch {
        return null;
    }
    if (!names.length)
        return null;
    const lines = [`module qs.${dir.split("/").join(".")}`];
    for (const name of names) {
        const base = name.slice(0, -".qml".length);
        const first = fs.readFileSync(path.join(root, dir, name), "utf8").split("\n")[0];
        lines.push(first === "pragma Singleton" ? `singleton ${base} 1.0 ${name}` : `${base} 1.0 ${name}`);
    }
    return `${lines.join("\n")}\n`;
}

function checkQmldirs(root) {
    const found = [];
    for (const dir of qmldirDirectories(root)) {
        const expected = expectedQmldir(root, dir);
        if (expected === null)
            continue;
        const file = `${dir}/qmldir`;
        let actual = null;
        try {
            actual = fs.readFileSync(path.join(root, file), "utf8");
        } catch {
        }
        if (actual === null) {
            found.push({ rule: "L10", file, line: 1, detail: "qmldir is missing" });
        } else if (actual !== expected) {
            const want = expected.split("\n");
            const have = actual.split("\n");
            let line = 1;
            while (line <= want.length && want[line - 1] === have[line - 1])
                line++;
            found.push({ rule: "L10", file, line, detail: "qmldir does not match scripts/qmldirs.sh" });
        }
    }
    return found;
}

function escapePattern(text) {
    return text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function directoryOf(file) {
    const cut = file.lastIndexOf("/");
    return cut < 0 ? "" : file.slice(0, cut);
}

function joinPath(base, relative) {
    const parts = base ? base.split("/") : [];
    for (const part of relative.split("/")) {
        if (part === "..")
            parts.pop();
        else if (part !== "." && part !== "")
            parts.push(part);
    }
    return parts.join("/");
}

function declaredMembers(text) {
    const scanned = scanSource(text);
    const code = scanned.code;
    const members = new Set(OBJECT_MEMBERS);
    const root = /(?<![\w.])[A-Z][\w.]*\s*\{/.exec(code);
    if (!root)
        return members;
    const open = root.index + root[0].length - 1;
    const close = matchingBrace(code, open);
    if (close < 0)
        return members;
    const own = ownLevel(code, { open, close });
    const add = name => {
        members.add(name);
    };
    const properties = /\bproperty\s+[\w.]+(?:<[^>]*>)?\s+(\w+)/g;
    const functions = /\bfunction\s+(\w+)\s*\(/g;
    const signals = /\bsignal\s+(\w+)/g;
    let m;
    while ((m = properties.exec(own)) !== null) {
        add(m[1]);
        add(`${m[1]}Changed`);
    }
    while ((m = functions.exec(own)) !== null)
        add(m[1]);
    while ((m = signals.exec(own)) !== null)
        add(m[1]);
    const enums = /\benum\s+(\w+)\s*\{([^}]*)\}/g;
    const body = code.slice(open, close + 1);
    while ((m = enums.exec(body)) !== null) {
        add(m[1]);
        for (const value of m[2].match(/\b[A-Za-z_]\w*/g) || [])
            add(value);
    }
    return members;
}

function buildSingletonIndex(sources) {
    const modules = new Map();
    const directories = new Map();
    for (const [file, text] of sources) {
        if (path.posix.basename(file) !== "qmldir")
            continue;
        const dir = directoryOf(file);
        const moduleLine = /^module\s+(\S+)/m.exec(text);
        const singletons = new Map();
        for (const line of text.split("\n")) {
            const m = /^singleton\s+(\w+)\s+\S+\s+(\S+)/.exec(line.trim());
            if (!m)
                continue;
            const target = joinPath(dir, m[2]);
            const source = sources.get(target);
            singletons.set(m[1], { file: target, members: source === undefined ? null : declaredMembers(source) });
        }
        directories.set(dir, singletons);
        if (moduleLine)
            modules.set(moduleLine[1], singletons);
    }
    return { modules, directories };
}

function importScope(file, plain, index) {
    const visible = new Map();
    const qualified = new Map();
    const own = index.directories.get(directoryOf(file));
    if (own)
        for (const [name, singleton] of own)
            visible.set(name, singleton);
    const importPattern = /^[ \t]*import[ \t]+(?:"([^"]+)"|([\w.]+)(?:[ \t]+[\d.]+)?)(?:[ \t]+as[ \t]+(\w+))?/gm;
    let m;
    while ((m = importPattern.exec(plain)) !== null) {
        const [, relative, moduleName, alias] = m;
        if (relative && relative.endsWith(".js"))
            continue;
        const singletons = relative ? index.directories.get(joinPath(directoryOf(file), relative)) : index.modules.get(moduleName);
        if (!singletons)
            continue;
        if (alias) {
            qualified.set(alias, singletons);
        } else {
            for (const [name, singleton] of singletons)
                visible.set(name, singleton);
        }
    }
    return { visible, qualified };
}

function shadowsName(code, plain, name) {
    const id = escapePattern(name);
    const declarations = [
        `\\bid\\s*:\\s*${id}\\b`,
        `\\b(?:const|let|var|function|class|signal|enum)\\s+${id}\\b`,
        `\\bproperty\\s+[\\w.]+(?:<[^>]*>)?\\s+${id}\\b`,
        `\\b${id}\\s*=>`,
        `\\([^()]*\\b${id}\\b[^()]*\\)\\s*=>`,
        `\\bfunction\\s*\\w*\\s*\\([^()]*\\b${id}\\b`
    ];
    if (new RegExp(declarations.join("|")).test(code))
        return true;
    return new RegExp(`^[ \\t]*import[ \\t]+"[^"]+"[ \\t]+as[ \\t]+${id}\\b`, "m").test(plain);
}

function memberHits(text, scope) {
    const scanned = scanSource(text);
    const at = lineIndex(text);
    const found = [];
    const check = (singletonName, singleton, member, offset, label) => {
        if (singleton.members === null || singleton.members.has(member))
            return;
        found.push({ line: at(offset), detail: `${label}.${member} is not a member of the ${singletonName} singleton (${singleton.file})` });
    };
    const names = [...scope.visible.keys()].filter(name => !shadowsName(scanned.code, scanned.plain, name));
    if (names.length) {
        const bare = new RegExp(`(?<![\\w$.])(${names.map(escapePattern).join("|")})\\s*\\.\\s*([A-Za-z_]\\w*)`, "g");
        let m;
        while ((m = bare.exec(scanned.code)) !== null)
            check(m[1], scope.visible.get(m[1]), m[2], m.index, m[1]);
    }
    for (const [alias, singletons] of scope.qualified) {
        if (shadowsName(scanned.code, scanned.plain, alias))
            continue;
        const qualifiedPattern = new RegExp(`(?<![\\w$.])${escapePattern(alias)}\\s*\\.\\s*(\\w+)\\s*\\.\\s*([A-Za-z_]\\w*)`, "g");
        let m;
        while ((m = qualifiedPattern.exec(scanned.code)) !== null) {
            const singleton = singletons.get(m[1]);
            if (singleton)
                check(m[1], singleton, m[2], m.index, `${alias}.${m[1]}`);
        }
    }
    return found.sort((a, b) => a.line - b.line);
}

function checkMembers(sources) {
    const index = buildSingletonIndex(sources);
    const importers = new Map();
    const scopes = new Map();
    const consumers = [...sources.keys()].filter(isShellCode).sort();
    for (const file of consumers) {
        const text = sources.get(file);
        if (!file.endsWith(".qml"))
            continue;
        const plain = scanSource(text).plain;
        scopes.set(file, importScope(file, plain, index));
        const scriptImport = /^[ \t]*import[ \t]+"([^"]+\.js)"/gm;
        let m;
        while ((m = scriptImport.exec(plain)) !== null) {
            const target = joinPath(directoryOf(file), m[1]);
            if (!importers.has(target))
                importers.set(target, []);
            importers.get(target).push(file);
        }
    }
    const found = [];
    for (const file of consumers) {
        let scope = scopes.get(file);
        if (!scope) {
            const users = importers.get(file) || [];
            const text = sources.get(file);
            if (/^\s*\.pragma\s+library/m.test(text) || !users.length)
                continue;
            scope = { visible: new Map(), qualified: new Map() };
            for (const user of users) {
                const used = scopes.get(user);
                for (const [name, singleton] of used.visible)
                    scope.visible.set(name, singleton);
                for (const [alias, singletons] of used.qualified)
                    scope.qualified.set(alias, singletons);
            }
        }
        for (const hit of memberHits(sources.get(file), scope))
            found.push({ rule: "L11", file, line: hit.line, detail: hit.detail });
    }
    return found;
}

function readMemberSources(root, files) {
    const sources = new Map();
    for (const file of files) {
        if (path.posix.basename(file) !== "qmldir" && !(isShellCode(file)))
            continue;
        const text = readTextFile(root, file);
        if (text !== null)
            sources.set(file, text);
    }
    return sources;
}

function checkSingletonMembers(root, files) {
    return checkMembers(readMemberSources(root, files));
}

function lint(root, onlyRule) {
    const files = listFiles(root);
    const findings = [];
    const active = RULES.filter(rule => !onlyRule || rule.id === onlyRule);
    for (const file of files) {
        const applicable = active.filter(rule => rule.check && rule.appliesTo(file));
        if (!applicable.length)
            continue;
        const text = readTextFile(root, file);
        if (text === null)
            continue;
        const ctx = { file, text };
        if (isQmlOrJs(file)) {
            const scanned = scanSource(text);
            scanned.at = lineIndex(text);
            ctx.scanned = scanned;
        }
        for (const rule of applicable) {
            if (!ctx.scanned && !rule.wantsText)
                continue;
            for (const hit of rule.check(ctx))
                findings.push({ rule: rule.id, file, line: hit.line, detail: hit.detail });
        }
    }
    if (active.some(rule => rule.id === "L10"))
        findings.push(...checkQmldirs(root));
    if (active.some(rule => rule.id === "L11"))
        findings.push(...checkSingletonMembers(root, files));
    findings.sort((a, b) => a.file < b.file ? -1 : a.file > b.file ? 1 : a.line - b.line || (a.rule < b.rule ? -1 : 1));
    return { files: files.length, findings };
}

function lintSource(file, text, ruleId) {
    const rule = ruleById(ruleId);
    const ctx = { file, text };
    if (isQmlOrJs(file)) {
        ctx.scanned = scanSource(text);
        ctx.scanned.at = lineIndex(text);
    }
    if (!rule || !rule.check || !rule.appliesTo(file) || (!ctx.scanned && !rule.wantsText))
        return [];
    return rule.check(ctx);
}

function tally(findings) {
    const counts = {};
    for (const finding of findings) {
        counts[finding.rule] = counts[finding.rule] || {};
        counts[finding.rule][finding.file] = (counts[finding.rule][finding.file] || 0) + 1;
    }
    return counts;
}

function ruleOrder(a, b) {
    return Number(a.slice(1)) - Number(b.slice(1));
}

function readBaseline(root) {
    const file = path.join(root, BASELINE_FILE);
    if (!fs.existsSync(file))
        return {};
    const parsed = JSON.parse(fs.readFileSync(file, "utf8"));
    return parsed.violations && typeof parsed.violations === "object" ? parsed.violations : {};
}

function writeBaseline(root, counts, onlyRule) {
    const merged = onlyRule ? { ...readBaseline(root), [onlyRule]: counts[onlyRule] || {} } : counts;
    const body = {};
    for (const id of Object.keys(merged).sort(ruleOrder)) {
        const files = Object.keys(merged[id]).sort();
        if (files.length)
            body[id] = Object.fromEntries(files.map(file => [file, merged[id][file]]));
    }
    fs.writeFileSync(path.join(root, BASELINE_FILE), `${JSON.stringify({ violations: body }, null, 2)}\n`);
}

function compare(counts, baseline, onlyRule) {
    const added = [];
    const fixed = [];
    const ids = new Set([...Object.keys(counts), ...Object.keys(baseline)]);
    for (const id of [...ids].sort(ruleOrder)) {
        if (onlyRule && id !== onlyRule)
            continue;
        const now = counts[id] || {};
        const before = baseline[id] || {};
        for (const file of new Set([...Object.keys(now), ...Object.keys(before)])) {
            const have = now[file] || 0;
            const known = before[file] || 0;
            if (have > known)
                added.push({ rule: id, file, have, known });
            else if (have < known)
                fixed.push({ rule: id, file, have, known });
        }
    }
    return { added, fixed };
}

function usage() {
    return [
        "usage: lint-rules.js [--root <dir>] [--rule <id>] [--all | --write-baseline | --list]",
        "",
        "  (none)             check the house rules against rules.baseline.json",
        "  --rule <id>        only this rule, L1 to L11",
        "  --all              print every violation with file and line, known or not",
        "  --write-baseline   record today's counts as the new baseline",
        "  --list             rule ids with their reasons"
    ].join("\n");
}

function parseArguments(argv) {
    const options = { root: path.resolve(__dirname, ".."), mode: "check", rule: null };
    for (let i = 0; i < argv.length; i++) {
        const arg = argv[i];
        if (arg === "--root") {
            options.root = path.resolve(argv[++i] || "");
        } else if (arg === "--rule") {
            options.rule = (argv[++i] || "").toUpperCase();
            if (!ruleById(options.rule))
                return { error: `no rule ${argv[i] || "(none given)"}; rules are ${RULES.map(r => r.id).join(", ")}` };
        } else if (arg === "--all") {
            options.mode = "all";
        } else if (arg === "--write-baseline") {
            options.mode = "baseline";
        } else if (arg === "--list") {
            options.mode = "list";
        } else if (arg === "-h" || arg === "--help") {
            options.mode = "help";
        } else {
            return { error: `unknown option ${arg}` };
        }
    }
    return options;
}

function formatFinding(finding) {
    return `${finding.file}:${finding.line}: ${finding.rule} ${finding.detail}`;
}

function run(argv, write) {
    const options = parseArguments(argv);
    if (options.error) {
        write(`lint-rules.js: ${options.error}\n${usage()}`, true);
        return 2;
    }
    if (options.mode === "help") {
        write(usage());
        return 0;
    }
    if (options.mode === "list") {
        for (const rule of RULES)
            write(`${rule.id}  ${rule.reason}`);
        return 0;
    }
    const { files, findings } = lint(options.root, options.rule);
    const counts = tally(findings);
    if (options.mode === "baseline") {
        writeBaseline(options.root, counts, options.rule);
        write(`wrote ${BASELINE_FILE} with ${findings.length} violations${options.rule ? ` for ${options.rule}` : ""}`);
        return 0;
    }
    if (options.mode === "all") {
        for (const finding of findings)
            write(formatFinding(finding));
        write(`${findings.length} violations in ${files} files`);
        return 0;
    }
    const baseline = readBaseline(options.root);
    const { added, fixed } = compare(counts, baseline, options.rule);
    const shown = RULES.filter(rule => !options.rule || rule.id === options.rule);
    write(`lint: ${files} files, ${findings.length} violations known`);
    for (const rule of shown) {
        const total = Object.values(counts[rule.id] || {}).reduce((sum, n) => sum + n, 0);
        write(`  ${rule.id.padEnd(3)} ${String(total).padStart(5)}  ${rule.reason}`);
    }
    if (fixed.length)
        write(`${fixed.length} baseline entries are fixed; run lint-rules.js --write-baseline to drop them`);
    if (!added.length) {
        write("no new violations");
        return 0;
    }
    const addedKeys = new Set(added.map(entry => `${entry.rule} ${entry.file}`));
    const lines = findings.filter(finding => addedKeys.has(`${finding.rule} ${finding.file}`));
    write(`${added.length} files with new violations:`, true);
    for (const finding of lines.slice(0, SHOW_LIMIT))
        write(`  ${formatFinding(finding)}`, true);
    if (lines.length > SHOW_LIMIT)
        write(`  and ${lines.length - SHOW_LIMIT} more`, true);
    for (const id of [...new Set(added.map(entry => entry.rule))])
        write(`${id}: ${ruleById(id).reason}`, true);
    return 1;
}

module.exports = {
    RULES, LOOPING_CLOCKS, scanSource, lintSource, lint, tally, compare, expectedQmldir, qmldirDirectories, checkMembers, run
};

if (require.main === module) {
    const write = (text, error) => (error ? process.stderr : process.stdout).write(`${text}\n`);
    process.exit(run(process.argv.slice(2), write));
}
