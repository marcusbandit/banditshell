const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const Scope = new Function(fs.readFileSync(path.join(__dirname, "../services/app-scope.js"), "utf8") + "\nreturn { prefixFor, escapeId, unitName, command };")();

const BASE = ["systemd-run", "--user", "--scope", "--quiet", "--collect"];

test("the probe answer picks the systemd-run prefix", () => {
    assert.deepStrictEqual(Scope.prefixFor("literal\n"), [...BASE, "--expand-environment=no"]);
    assert.deepStrictEqual(Scope.prefixFor("expanding"), BASE);
    assert.deepStrictEqual(Scope.prefixFor(""), []);
    assert.deepStrictEqual(Scope.prefixFor(undefined), []);
});

test("app ids are escaped the way systemd unit names need", () => {
    assert.strictEqual(Scope.escapeId("org.example.Viewer"), "org.example.Viewer");
    assert.strictEqual(Scope.escapeId("example-editor.desktop"), "example\\x2deditor");
    assert.strictEqual(Scope.escapeId(".hidden"), "\\x2ehidden");
    assert.strictEqual(Scope.escapeId("café app"), "caf\\xc3\\xa9\\x20app");
    assert.strictEqual(Scope.escapeId(""), "app");
});

test("a long app id is cut without leaving half an escape", () => {
    const cut = Scope.escapeId("a".repeat(178) + "-b");
    assert.strictEqual(cut, "a".repeat(178));
    assert.ok(Scope.escapeId("x".repeat(400)).length <= 180);
});

test("a launch runs in its own app scope when systemd-run works", () => {
    const prefix = Scope.prefixFor("literal");
    assert.strictEqual(Scope.unitName("example-editor", "18c2_3"), "app-banditshell-example\\x2deditor-18c2_3.scope");
    assert.deepStrictEqual(Scope.command(prefix, "example-editor", "18c2_3", ["editor", "--new-window"]), [...prefix, "--unit=app-banditshell-example\\x2deditor-18c2_3.scope", "--", "editor", "--new-window"]);
});

test("without systemd-run the command runs unchanged", () => {
    assert.deepStrictEqual(Scope.command([], "example", "1", ["editor"]), ["editor"]);
    assert.deepStrictEqual(Scope.command(BASE, "example", "1", []), []);
});
