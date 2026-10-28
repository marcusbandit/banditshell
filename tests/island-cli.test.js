const test = require("node:test");
const assert = require("node:assert");
const { cleanup, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const dry = (...args) => {
    const run = cli(args, { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(run.code, 0, `${args.join(" ")}: ${run.err}`);
    return run.out.trim().split("\n").map(line => line.trimEnd());
};

test("island end hands the outcome and an optional final text to the shell", () => {
    assert.deepStrictEqual(dry("island", "end", "build"), ["ipc activity end build done"]);
    assert.deepStrictEqual(dry("island", "end", "build", "failed"), ["ipc activity end build failed"]);
    assert.deepStrictEqual(dry("island", "end", "build", "--text", "Built"), ["ipc activity endSaying build done Built"]);
    assert.deepStrictEqual(dry("island", "end", "build", "cancelled", "--text", "Stopped by hand"), ["ipc activity endSaying build cancelled Stopped by hand"]);
});

test("island end refuses an unknown flag and a --text with no words", () => {
    for (const args of [["island", "end", "build", "--colour", "red"], ["island", "end", "build", "--text"], ["island", "end"]]) {
        const run = cli(args, { env: { BANDITSHELL_DRY: "1" } });
        assert.strictEqual(run.code, 2, args.join(" "));
    }
});
