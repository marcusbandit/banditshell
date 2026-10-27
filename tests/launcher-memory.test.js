const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/launcher-memory.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Memory = new Function(`${src}\nreturn { scoreOf, record };`)();

const DAY = 86400000;
const decay = (from, to) => Math.pow(0.5, Math.max(0, to - from) / DAY / 14);

function filled(count, start) {
    let usage = {};
    for (let i = 0; i < count; i++)
        usage = Memory.record(usage, `key${i}`, start + i * 1000, 400, decay);
    return usage;
}

test("a new key is kept once 400 are remembered", () => {
    const now = 1.8e12;
    const usage = Memory.record(filled(400, now - DAY), "newest", now, 400, decay);
    assert.ok(usage.newest, "the newest key was evicted on the way in");
    assert.strictEqual(Object.keys(usage).length, 400);
});

test("the faintest habit makes room, not the one just used", () => {
    const now = 1.8e12;
    const usage = Memory.record(filled(401, now - DAY), "key400", now, 400, decay);
    assert.ok(usage.key400);
    assert.strictEqual(usage.key0, undefined);
    assert.strictEqual(Object.keys(usage).length, 400);
});

test("a new key is kept even when every stored habit is stronger", () => {
    const now = 1.8e12;
    const usage = {};
    for (let i = 0; i < 400; i++)
        usage[`key${i}`] = { score: 5 + i / 1000, last: now };
    const next = Memory.record(usage, "newest", now, 400, decay);
    assert.ok(next.newest);
    assert.strictEqual(next.key0, undefined);
    assert.strictEqual(Object.keys(next).length, 400);
});

test("using a key again adds to its decayed score", () => {
    const usage = Memory.record({ a: { score: 2, last: 0 } }, "a", 14 * DAY, 400, decay);
    assert.deepStrictEqual(usage.a, { score: 2, last: 14 * DAY });
});

test("recording leaves the old map untouched", () => {
    const before = { a: { score: 1, last: 0 } };
    Memory.record(before, "b", 10, 400, decay);
    assert.deepStrictEqual(Object.keys(before), ["a"]);
});
