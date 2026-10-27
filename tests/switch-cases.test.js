const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { scanSource } = require("../scripts/lint-rules.js");

const ROOT = path.resolve(__dirname, "..");
const SKIPPED = new Set([".git", ".scratch", "node_modules", "tests", "site"]);

function sources(dir) {
    const found = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (SKIPPED.has(entry.name))
            continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory())
            found.push(...sources(full));
        else if (/\.(?:qml|js)$/.test(entry.name))
            found.push(full);
    }
    return found.sort();
}

function repeatedCases(text) {
    const { code, plain } = scanSource(text);
    const repeated = [];
    const opening = /\bswitch\s*\([^{]*\)\s*\{/g;
    let found;
    while ((found = opening.exec(code))) {
        const seen = new Set();
        let depth = 0;
        for (let i = opening.lastIndex; i < code.length && depth >= 0; i++) {
            if (code[i] === "{")
                depth++;
            else if (code[i] === "}")
                depth--;
            else if (depth === 0 && /^case\s/.test(code.slice(i, i + 5)) && !/\w/.test(code[i - 1])) {
                const label = plain.slice(i + 5, code.indexOf(":", i)).trim();
                if (seen.has(label))
                    repeated.push(label);
                seen.add(label);
            }
        }
    }
    return repeated;
}

test("no switch lists the same case twice, so the second branch can run", () => {
    const repeats = sources(ROOT).flatMap(file => repeatedCases(fs.readFileSync(file, "utf8")).map(label => `${path.relative(ROOT, file)}: case ${label}`));
    assert.deepStrictEqual(repeats, []);
});

test("a repeated case is found, and a nested switch is not counted", () => {
    assert.deepStrictEqual(repeatedCases('switch (k) { case "a": x(); break; case "b": { switch (j) { case "a": y(); } } case "a": z(); }'), ['"a"']);
});

test("labels with a colon, and braces in strings and comments, are read whole", () => {
    assert.deepStrictEqual(repeatedCases('switch (k) { case "row:a": x("{"); break; // }\n case "row:b": y(); }'), []);
    assert.deepStrictEqual(repeatedCases('switch (k) { case "row:a": x("}"); break; case "row:a": y(); }'), ['"row:a"']);
});
