const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/lock-face.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Face = new Function(src + "\nreturn { settle, pause, tries, mayLook, waitLeft, wanted, choose };")();

const sealedAt = 100000;

function state(changes) {
    return Object.assign({
        ready: true,
        active: true,
        opening: false,
        sleeping: false,
        looking: false,
        sealedAt: sealedAt,
        endedAt: 0,
        misses: 0,
        now: sealedAt + Face.settle + 1,
        asked: false
    }, changes);
}

test.describe("when the lock looks for a face", () => {
    test.it("looks once the lock has settled and someone moves", () => {
        assert.strictEqual(Face.mayLook(state({})), true);
    });

    test.it("never looks at the person who just locked it", () => {
        assert.strictEqual(Face.mayLook(state({ sealedAt: 0 })), false);
        assert.strictEqual(Face.mayLook(state({ now: sealedAt + Face.settle - 1 })), false);
        assert.strictEqual(Face.mayLook(state({ sealedAt: 0, asked: true })), false);
    });

    test.it("looks right away when the tab is pressed", () => {
        assert.strictEqual(Face.mayLook(state({ now: sealedAt + 10, asked: true })), true);
        assert.strictEqual(Face.mayLook(state({ misses: Face.tries, asked: true })), true);
    });

    test.it("stops looking on its own after a few misses in a row", () => {
        assert.strictEqual(Face.mayLook(state({ misses: Face.tries - 1 })), true);
        assert.strictEqual(Face.mayLook(state({ misses: Face.tries })), false);
    });

    test.it("waits a moment between looks", () => {
        const endedAt = sealedAt + 5000;
        assert.strictEqual(Face.mayLook(state({ endedAt, now: endedAt + Face.pause - 1 })), false);
        assert.strictEqual(Face.mayLook(state({ endedAt, now: endedAt + Face.pause })), true);
    });

    test.it("never looks without howdy, while unlocking, asleep or already looking", () => {
        for (const change of [{ ready: false }, { active: false }, { opening: true }, { sleeping: true }, { looking: true }]) {
            assert.strictEqual(Face.mayLook(state(change)), false, JSON.stringify(change));
            assert.strictEqual(Face.mayLook(state(Object.assign({ asked: true }, change))), false, JSON.stringify(change));
        }
    });
});

test.describe("how much of a lockout is left", () => {
    test.it("is the share of the wait still to go", () => {
        assert.strictEqual(Face.waitLeft(20000, 10000, 15000), 0.5);
        assert.strictEqual(Face.waitLeft(20000, 10000, 10000), 1);
    });

    test.it("is nothing once the wait is over or never started", () => {
        assert.strictEqual(Face.waitLeft(20000, 10000, 20000), 0);
        assert.strictEqual(Face.waitLeft(0, 0, 5000), 0);
        assert.strictEqual(Face.waitLeft(20000, 0, 5000), 0);
    });

    test.it("never reads more than a full ring when the clock goes backwards", () => {
        assert.strictEqual(Face.waitLeft(20000, 5000, 0), 1);
    });
});

test.describe("which face modules the lock asks", () => {
    const order = ["gaze", "howdy"];

    test.it("asks every installed one, Gaze first, on auto", () => {
        assert.deepStrictEqual(Face.choose("auto", ["howdy", "gaze"], order), ["gaze", "howdy"]);
        assert.deepStrictEqual(Face.choose("auto", ["howdy"], order), ["howdy"]);
        assert.deepStrictEqual(Face.choose("auto", [], order), []);
    });

    test.it("asks only the one named, and nothing when it is missing", () => {
        assert.deepStrictEqual(Face.choose("howdy", ["gaze", "howdy"], order), ["howdy"]);
        assert.deepStrictEqual(Face.choose("gaze", ["howdy"], order), []);
        assert.deepStrictEqual(Face.choose("off", ["gaze", "howdy"], order), []);
    });

    test.it("reads an older on or off setting as auto or off", () => {
        assert.strictEqual(Face.wanted(true), "auto");
        assert.strictEqual(Face.wanted(false), "off");
        assert.strictEqual(Face.wanted("gaze"), "gaze");
        assert.strictEqual(Face.wanted("nonsense"), "auto");
        assert.strictEqual(Face.wanted(undefined), "auto");
    });
});
