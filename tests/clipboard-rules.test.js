const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clipboard-rules.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Rules = new Function(src + "\nreturn { excluded, withoutStale };")();

const DAY = 86400000;
const NOW = Date.UTC(2026, 10, 12);

test("an app on the list is matched whatever its case", () => {
    assert.ok(Rules.excluded("KeePassXC", "keepassxc, 1password"));
});

test("a short name matches the last part of a dotted window class", () => {
    assert.ok(Rules.excluded("org.keepassxc.KeePassXC", "keepassxc"));
});

test("a name that only shares a few letters does not match", () => {
    assert.ok(!Rules.excluded("notkeepassxc", "keepassxc"));
    assert.ok(!Rules.excluded("kitty", "keepassxc"));
});

test("an unknown source app is never excluded", () => {
    assert.ok(!Rules.excluded("", "keepassxc"));
    assert.ok(!Rules.excluded("kitty", ""));
});

test("entries older than the span go, pinned ones stay", () => {
    const entries = [
        { recorded: NOW - 2 * DAY },
        { recorded: NOW - 10 * DAY },
        { recorded: NOW - 10 * DAY, pinned: true }
    ];
    const kept = Rules.withoutStale(entries, NOW, 7);
    assert.strictEqual(kept.length, 2);
    assert.ok(kept.every(e => e.pinned || e.recorded === NOW - 2 * DAY));
});

test("a span of zero keeps everything", () => {
    const entries = [{ recorded: 1 }];
    assert.strictEqual(Rules.withoutStale(entries, NOW, 0), entries);
});

test("an entry with no copy time is never taken for an old one", () => {
    const now = Date.UTC(2026, 10, 12);
    assert.deepStrictEqual(Rules.withoutStale([{ id: "a", recorded: 0, pinned: false }], now, 30).map(e => e.id), ["a"]);
});

