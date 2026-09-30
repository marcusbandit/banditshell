const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/whatsnew.js"), "utf8");
const WhatsNew = new Function(src
    + "\nreturn { parse, accumulated, severityOf, TYPES };")();

const log = [
    { id: "third", date: "2026-09-03", changes: [{ type: "bugs", severity: "minor", text: "Fixed the thing." }] },
    { id: "skipped", date: "2026-09-02", changes: [{ type: "ui", severity: "minor", text: "Moved the other thing." }] },
    { id: "first", date: "2026-09-01", changes: [{ type: "features", severity: "major", text: "Added the thing; run the migration." }] }
];

test("the shipped log parses and is well formed", () => {
    const file = fs.readFileSync(path.join(ROOT, "docs/whats-new.json"), "utf8");
    const parsed = WhatsNew.parse(file);
    assert.ok(parsed.length > 0, "the shipped log must not parse empty");
    const ids = parsed.map(e => e.id);
    assert.strictEqual(new Set(ids).size, ids.length, "ids are not unique");
    for (const e of parsed) {
        assert.strictEqual(typeof e.id, "string");
        for (const c of e.changes) {
            assert.strictEqual(typeof c.text, "string");
            assert.ok(c.text.length > 0);
            assert.strictEqual(typeof c.type, "string");
            assert.ok(["major", "minor"].includes(c.severity));
        }
    }
});

test("garbage parses as an empty log, not a throw", () => {
    assert.deepStrictEqual(WhatsNew.parse(""), []);
    assert.deepStrictEqual(WhatsNew.parse("not json at all"), []);
    assert.deepStrictEqual(WhatsNew.parse('{"no": "entries here"}'), []);
    assert.deepStrictEqual(WhatsNew.parse("null"), []);
    assert.deepStrictEqual(WhatsNew.parse(undefined), []);
});

test("a bare array is accepted beside the entries wrapper", () => {
    assert.deepStrictEqual(WhatsNew.parse(JSON.stringify(log)), WhatsNew.parse(JSON.stringify({ entries: log })));
});

test("malformed entries are dropped, not repaired", () => {
    const parsed = WhatsNew.parse(JSON.stringify([
        "a string is not an entry",
        { date: "2026-09-01", changes: [] },
        { id: "  ", changes: [] },
        { id: "kept", changes: [{ text: "   " }, { type: "bugs", text: "kept with its text" }] }
    ]));
    assert.strictEqual(parsed.length, 1);
    assert.strictEqual(parsed[0].id, "kept");
    assert.strictEqual(parsed[0].changes.length, 1);
    assert.strictEqual(parsed[0].changes[0].text, "kept with its text");
});

test("an entry without readable changes survives as a marker waypoint", () => {
    const parsed = WhatsNew.parse(JSON.stringify([{ id: "silent" }, { id: "after", changes: [{ type: "bugs", text: "Fixed." }] }]));
    assert.strictEqual(parsed.length, 2);
    assert.deepStrictEqual(parsed[0].changes, []);
});

test("an unknown severity reads Minor and an unknown type is kept", () => {
    const parsed = WhatsNew.parse(JSON.stringify([{ id: "e", changes: [
        { type: "something-new", severity: "catastrophic", text: "Said plainly." }
    ]}]));
    assert.strictEqual(parsed[0].changes[0].type, "something-new");
    assert.strictEqual(parsed[0].changes[0].severity, "minor");
});

test("an empty marker accumulates everything", () => {
    assert.deepStrictEqual(WhatsNew.accumulated(log, ""), log);
    assert.deepStrictEqual(WhatsNew.accumulated(log, null), log);
});

test("the marker stops the walk, and everything newer accumulates", () => {
    const pending = WhatsNew.accumulated(log, "skipped");
    assert.deepStrictEqual(pending.map(e => e.id), ["third"]);
    assert.deepStrictEqual(WhatsNew.accumulated(log, "first").map(e => e.id), ["third", "skipped"]);
});

test("a marker naming the newest entry accumulates nothing", () => {
    assert.deepStrictEqual(WhatsNew.accumulated(log, "third"), []);
});

test("a marker the log no longer contains shows everything", () => {

    assert.deepStrictEqual(WhatsNew.accumulated(log, "trimmed-away"), log);
});

test("several skipped pushes accumulate together, newest first", () => {
    const pending = WhatsNew.accumulated(log, "first");
    assert.deepStrictEqual(pending.map(e => e.id), ["third", "skipped"]);
});

test("examples never surface and never stop the walk", () => {
    const withExample = [{ id: "example", date: "", example: true, changes: [{ type: "ui", text: "Shape only." }] }, ...log];
    assert.deepStrictEqual(WhatsNew.accumulated(withExample, ""), log);
    assert.deepStrictEqual(WhatsNew.accumulated(withExample, "skipped").map(e => e.id), ["third"]);
});

test("entries with nothing to show are skipped but do not eat the marker", () => {

    const silent = [{ id: "silent", date: "2026-09-04", changes: [] }, ...log];
    assert.deepStrictEqual(WhatsNew.accumulated(silent, ""), log);
    assert.deepStrictEqual(WhatsNew.accumulated(silent, "silent").map(e => e.id), ["third", "skipped", "first"]);
});

test("an empty log accumulates nothing", () => {
    assert.deepStrictEqual(WhatsNew.accumulated([], ""), []);
    assert.deepStrictEqual(WhatsNew.accumulated(WhatsNew.parse("{}"), ""), []);
});

test("an entry is Major when any change in it is", () => {
    assert.strictEqual(WhatsNew.severityOf(log[0]), "minor");
    assert.strictEqual(WhatsNew.severityOf(log[2]), "major");
    assert.strictEqual(WhatsNew.severityOf({ id: "e", changes: [] }), "minor");
    assert.strictEqual(WhatsNew.severityOf(undefined), "minor");
});
