const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/lock-hint.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Hint = new Function(src + "\nreturn { recordText, readRecord, onStart };")();

const SESSION = "/org/freedesktop/login1/session/_32";
const told = (text, session = SESSION) => Hint.readRecord(text, session);

test.describe("locked hint at start", () => {
    test.it("clears a hint left true after the shell unlocked", () => {
        assert.strictEqual(Hint.onStart(true, told(Hint.recordText(SESSION, false)), false), "clear");
    });

    test.it("relocks when the shell died holding the lock", () => {
        assert.strictEqual(Hint.onStart(true, told(Hint.recordText(SESSION, true)), false), "relock");
    });

    test.it("relocks for a hint the shell has no record of", () => {
        assert.strictEqual(Hint.onStart(true, told(""), false), "relock");
        assert.strictEqual(Hint.onStart(true, told("{not json"), false), "relock");
        assert.strictEqual(Hint.onStart(true, told(Hint.recordText(SESSION, false), "/org/freedesktop/login1/session/_33"), false), "relock");
    });

    test.it("trusts only a record for a known session", () => {
        assert.strictEqual(told(Hint.recordText("", false), ""), null);
        assert.strictEqual(told(Hint.recordText("", true)), null);
        assert.strictEqual(told('{"session":"' + SESSION + '","told":"false"}'), null);
    });

    test.it("leaves an unlocked session and a lock already up alone", () => {
        assert.strictEqual(Hint.onStart(false, told(Hint.recordText(SESSION, true)), false), "leave");
        assert.strictEqual(Hint.onStart(undefined, null, false), "leave");
        assert.strictEqual(Hint.onStart(true, false, true), "leave");
    });
});
