const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "config/configuration.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Configuration = new Function(src + "\nreturn { saveDecision, echoes, unsavedAfterRead, readText, readFailed, reapply };")();

test.describe("deciding whether config.json may be written", () => {
    const decide = Configuration.saveDecision;

    test.it("drops a change made before the first read", () => {
        assert.strictEqual(decide(false, false), "drop");
        assert.strictEqual(decide(false, true), "drop");
    });

    test.it("holds a change while the file is unreadable, so the broken file is never overwritten", () => {
        assert.strictEqual(decide(true, true), "hold");
    });

    test.it("writes once the file has been read and parsed", () => {
        assert.strictEqual(decide(true, false), "write");
    });

    test.it("writes again when a broken file is fixed, and holds again when it breaks", () => {
        const state = { loaded: false, unreadable: false };
        const seen = [];
        const step = got => {
            Object.assign(state, { loaded: got.loaded, unreadable: got.unreadable });
            seen.push(decide(state.loaded, state.unreadable));
        };
        seen.push(decide(state.loaded, state.unreadable));
        step(Configuration.readText("{ \"theme\": \"slate\", }", { values: {} }, {}, false, [], {}));
        step(Configuration.readText("{}", { values: {} }, {}, false, [], {}));
        step(Configuration.readText("{", { values: {} }, {}, false, [], {}));
        step(Configuration.readFailed(false));
        step(Configuration.readFailed(true));
        assert.deepStrictEqual(seen, ["drop", "hold", "write", "hold", "hold", "write"]);
    });
});

test.describe("recognising the shell's own write coming back", () => {
    test.it("ignores a read that matches the last write", () => {
        assert.strictEqual(Configuration.echoes(true, false, "{\n}\n", "{\n}\n"), true);
    });

    test.it("reads a file that differs from the last write", () => {
        assert.strictEqual(Configuration.echoes(true, false, "{ }", "{\n}\n"), false);
    });

    test.it("reads an emptied file when the shell has not written yet this session", () => {
        assert.strictEqual(Configuration.echoes(true, false, "", ""), false);
    });

    test.it("reads a file that matches the last write while the file was unreadable", () => {
        assert.strictEqual(Configuration.echoes(true, true, "{\n}\n", "{\n}\n"), false);
        assert.strictEqual(Configuration.echoes(false, false, "{\n}\n", "{\n}\n"), false);
    });
});

test.describe("edits held while the file was unreadable", () => {
    const held = [["theme", "dusk"]];

    test.it("are forgotten when the fixed file is read with no save pending", () => {
        assert.deepStrictEqual(Configuration.unsavedAfterRead(false, false, held), []);
    });

    test.it("are kept when the fixed file arrives inside a pending save, so they are reapplied", () => {
        assert.deepStrictEqual(Configuration.unsavedAfterRead(false, true, held), held);
    });

    test.it("are kept while the file is still unreadable", () => {
        assert.deepStrictEqual(Configuration.unsavedAfterRead(true, false, held), held);
    });

    test.it("no longer override a hand fix on a later read", () => {
        const literals = {};
        const afterFix = Configuration.unsavedAfterRead(false, false, held);
        const next = { theme: "slate" };
        assert.deepStrictEqual(Configuration.reapply(next, afterFix, literals), next);
    });
});
