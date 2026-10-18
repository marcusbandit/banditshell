const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notify.js"), "utf8");
const Notify = new Function(src + "\nreturn { CATEGORY_PREFIX, categoryFor, kindOf, commandFor };")();

test("a kind becomes a category and back", () => {
    assert.strictEqual(Notify.categoryFor("battery"), "x-banditshell.battery");
    assert.strictEqual(Notify.kindOf("x-banditshell.battery"), "battery");
});

test("a category from another sender has no kind", () => {
    assert.strictEqual(Notify.kindOf("email.arrived"), "");
    assert.strictEqual(Notify.kindOf(""), "");
    assert.strictEqual(Notify.kindOf(undefined), "");
});

test("a post becomes the notify-send command the services used to build", () => {
    assert.deepStrictEqual(Notify.commandFor({ urgency: "critical", summary: "Battery low, 12%", body: "Find a charger.", kind: "battery" }), ["notify-send", "-a", "banditshell", "-u", "critical", "-c", "x-banditshell.battery", "Battery low, 12%", "Find a charger."]);
});

test("a post without urgency is normal and without a body is empty", () => {
    assert.deepStrictEqual(Notify.commandFor({ summary: "Done", kind: "alarm" }), ["notify-send", "-a", "banditshell", "-u", "normal", "-c", "x-banditshell.alarm", "Done", ""]);
});
