#!/usr/bin/env node
"use strict";

const fs = require("node:fs");

const ERROR_CLASSES = [
    { name: "TypeError", pattern: /TypeError/ },
    { name: "ReferenceError", pattern: /ReferenceError/ },
    { name: "is not defined", pattern: /is not defined/ },
    { name: "Cannot read property", pattern: /Cannot read propert/ },
    { name: "Failed to load", pattern: /Failed to load/ },
    { name: "Unable to assign", pattern: /Unable to assign/ },
    { name: "binding loop", pattern: /Binding loop detected/i }
];

const KNOWN_ENVIRONMENT = [
    /HYPRLAND_INSTANCE_SIGNATURE/i,
    /hyprland.*(signature|socket|not running|not found)/i,
    /pipewire/i,
    /ext[-_]idle[-_]notify/i,
    /(wallpaper|Pictures\/).*(no such file|does not exist|cannot open|could not open|not found|failed to load|failed to open)/i,
    /(no such file|does not exist|cannot open|could not open|failed to load|failed to open).*(wallpaper|Pictures\/)/i
];

const ANSI = /\x1b\[[0-9;]*m/g;

function stripAnsi(line) {
    return String(line).replace(ANSI, "");
}

function isKnownEnvironment(line) {
    return KNOWN_ENVIRONMENT.some(pattern => pattern.test(line));
}

function classifyLine(line) {
    const text = stripAnsi(line);
    if (isKnownEnvironment(text))
        return [];
    return ERROR_CLASSES.filter(entry => entry.pattern.test(text)).map(entry => entry.name);
}

function scanLog(text) {
    const found = {};
    for (const entry of ERROR_CLASSES)
        found[entry.name] = new Map();
    for (const raw of String(text).split("\n")) {
        const line = stripAnsi(raw).trim();
        if (!line)
            continue;
        for (const name of classifyLine(line))
            found[name].set(line, (found[name].get(line) || 0) + 1);
    }
    return ERROR_CLASSES.map(entry => {
        const lines = found[entry.name];
        let count = 0;
        for (const hits of lines.values())
            count += hits;
        return { name: entry.name, count, distinct: [...lines.keys()] };
    });
}

function statusCalls(targets) {
    const calls = [];
    for (const target of Object.keys(targets).sort()) {
        const functions = Array.isArray(targets[target]) ? targets[target] : [];
        if (functions.some(signature => /^status\(\s*\)/.test(signature)))
            calls.push(target);
    }
    return calls;
}

function main(argv) {
    const [mode, file] = argv;
    if (!mode || !file) {
        process.stderr.write("usage: boot-check.js calls <ipc-targets.json> | scan <shell.log> | errors <shell.log>\n");
        return 2;
    }
    let content;
    try {
        content = fs.readFileSync(file, "utf8");
    } catch (error) {
        process.stderr.write("boot-check.js: cannot read " + file + "\n");
        return 2;
    }
    if (mode === "calls") {
        for (const target of statusCalls(JSON.parse(content)))
            process.stdout.write(target + "\n");
        return 0;
    }
    const results = scanLog(content);
    if (mode === "scan") {
        for (const result of results)
            process.stdout.write([result.count === 0 ? "PASS" : "FAIL", result.name, result.count, result.distinct[0] || ""].join("\t") + "\n");
        return 0;
    }
    if (mode === "errors") {
        for (const result of results)
            for (const line of result.distinct)
                process.stdout.write(result.name + ": " + line + "\n");
        return 0;
    }
    process.stderr.write("boot-check.js: no mode " + mode + "\n");
    return 2;
}

if (require.main === module)
    process.exit(main(process.argv.slice(2)));

module.exports = { ERROR_CLASSES, classifyLine, scanLog, statusCalls, stripAnsi };
