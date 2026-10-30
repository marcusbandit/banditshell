const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { cleanup, stubs, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

function withLoginctl(code) {
    const stub = stubs();
    fs.writeFileSync(path.join(stub.dir, "loginctl"), `#!/bin/sh\necho "loginctl $*" >>"$STUB_LOG"\nexit ${code}\n`, { mode: 0o755 });
    return stub;
}

test("lock asks logind first and leaves the shell alone when logind locks", () => {
    const run = cli(["lock"], { stub: withLoginctl(0), env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(run.code, 0);
    assert.deepStrictEqual(run.calls, ["loginctl lock-session"]);
    assert.ok(!run.out.includes("ipc shell lock"), run.out);
});

test("lock falls back to the shell's own lock without logind", () => {
    const run = cli(["lock"], { stub: withLoginctl(1), env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(run.code, 0);
    assert.deepStrictEqual(run.calls, ["loginctl lock-session"]);
    assert.ok(run.out.includes("ipc shell lock"), run.out);
});

test("lock takes no arguments", () => {
    const run = cli(["lock", "now"], { stub: withLoginctl(0), env: { BANDITSHELL_DRY: "1" } });
    assert.notStrictEqual(run.code, 0);
    assert.deepStrictEqual(run.calls, []);
});
