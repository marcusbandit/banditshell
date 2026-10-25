const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/dictation-events.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Events = new Function(src + "\nreturn { read, outcome };")();
const [older, listening, cancelled, chrome, streamed] = fs.readFileSync(path.join(ROOT, "tests/fixtures/gvoice/events.jsonl"), "utf8").trim().split("\n");

test.describe("dictation events", () => {
    test.it("offers no cancel to a daemon that does not say it can", () => {
        const e = Events.read(older);
        assert.strictEqual(e.phase, "idle");
        assert.strictEqual(e.lang, "en-DK");
        assert.strictEqual(e.canCancel, false);
        assert.strictEqual(e.cancelled, false);
    });

    test.it("offers cancel while a newer daemon listens", () => {
        const e = Events.read(listening);
        assert.strictEqual(e.phase, "listening");
        assert.strictEqual(e.level, 0.4123);
        assert.strictEqual(e.canCancel, true);
        assert.strictEqual(e.cancelled, false);
    });

    test.it("hears a cancel only as the idle that ends it", () => {
        assert.strictEqual(Events.read(cancelled).cancelled, true);
        assert.strictEqual(Events.read('{"phase": "listening", "cancelled": true}').cancelled, false);
    });

    test.it("says Nothing typed only when the daemon says nothing was", () => {
        assert.strictEqual(Events.outcome(Events.read(cancelled).typed), "Nothing typed");
        assert.strictEqual(Events.outcome(Events.read(streamed).typed), "Rest discarded");
        assert.strictEqual(Events.outcome(Events.read('{"phase": "idle", "cancelled": true}').typed), "Discarded");
    });

    test.it("withdraws cancel when the daemon says it cannot", () => {
        assert.strictEqual(Events.read(chrome).canCancel, false);
    });

    test.it("ignores lines that are not an event", () => {
        assert.strictEqual(Events.read("not json"), null);
        assert.strictEqual(Events.read("[1, 2]"), null);
        assert.strictEqual(Events.read("null"), null);
        assert.strictEqual(Events.read('{"level": "loud"}').level, null);
    });
});
