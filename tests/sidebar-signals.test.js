const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const sidebar = fs.readFileSync(path.join(ROOT, "modules/sidebar/Sidebar.qml"), "utf8");
const shell = fs.readFileSync(path.join(ROOT, "modules/ShellWindow.qml"), "utf8");

function block(text, start) {
    const open = text.indexOf("{", start);
    let depth = 0;
    for (let i = open; i < text.length; i++) {
        if (text[i] === "{")
            depth++;
        else if (text[i] === "}" && --depth === 0)
            return text.slice(open, i + 1);
    }
    return "";
}

function listeners() {
    const parts = [];
    const own = /^\s*Sidebar \{\s*\n\s*id: sidebar$/m.exec(shell);
    if (own)
        parts.push(block(shell, own.index));
    for (const m of shell.matchAll(/Connections \{\s*\n\s*target: sidebar(\.\w+)?\s*\n/g))
        parts.push(block(shell, m.index));
    return parts.join("\n");
}

test.describe("sidebar signals", () => {
    test.it("every signal the sidebar sends has a handler in the shell window", () => {
        const signals = [...sidebar.matchAll(/^\s{4}signal (\w+)/gm)].map(m => m[1]);
        assert.ok(signals.includes("clockRequested"));
        const handled = listeners();
        const missing = signals.filter(name => {
            const handler = "on" + name[0].toUpperCase() + name.slice(1);
            return !new RegExp(`(function ${handler}\\(|${handler}:)`).test(handled);
        });
        assert.deepStrictEqual(missing, []);
    });
});
