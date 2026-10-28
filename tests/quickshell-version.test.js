const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const SCRIPT = path.resolve(__dirname, "../scripts/quickshell-version.sh");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "quickshell-version-"));
test.after(() => fs.rmSync(TMP, { recursive: true, force: true }));
let counter = 0;

function check(said) {
    const bin = path.join(TMP, `bin-${counter++}`);
    fs.mkdirSync(bin);
    for (const tool of ["bash", "sed", "head"])
        fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(bin, tool));
    if (said !== null)
        fs.writeFileSync(path.join(bin, "qs"), `#!${path.join(bin, "bash")}\nprintf '%s\\n' '${said}'\n`, { mode: 0o755 });
    const run = spawnSync(path.join(bin, "bash"), [SCRIPT], { env: { PATH: bin }, encoding: "utf8" });
    return { code: run.status, out: run.stdout.trim() };
}

test("the version this shell is built on passes, as does anything newer", () => {
    assert.deepStrictEqual(check("Quickshell 0.3.2 (revision 2b4501a2, distributed by AUR (package: quickshell-git))"), { code: 0, out: "quickshell 0.3.2" });
    assert.strictEqual(check("Quickshell 0.10.0").code, 0);
    assert.strictEqual(check("quickshell 1.0").code, 0);
});

test("an older version says which it is and what it needs", () => {
    const fedora = check("Quickshell 0.2.1 (revision unknown)");
    assert.strictEqual(fedora.code, 1);
    assert.match(fedora.out, /^quickshell 0\.2\.1 is older than 0\.3\.2/);
    assert.strictEqual(check("Quickshell 0.3.0").code, 1);
});

test("a missing quickshell and one that does not say its version are told apart", () => {
    assert.strictEqual(check(null).code, 2);
    assert.deepStrictEqual(check("something else"), { code: 3, out: "quickshell did not say its version" });
});
