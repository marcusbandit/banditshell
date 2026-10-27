const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const RECORD = path.join(ROOT, "scripts/clip-record.sh");
const CORE = ["jq", "timeout", "mkdir", "head", "tr", "stat", "cat", "sha256sum", "cut", "file", "sed", "mv", "rm"];

function record(offer) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "clip-record-"));
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin);
    for (const tool of CORE)
        fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(bin, tool));
    fs.writeFileSync(path.join(dir, "types"), offer.types.join("\n") + "\n");
    fs.writeFileSync(path.join(dir, "body"), offer.body ?? "");
    const log = path.join(dir, "asked");
    fs.writeFileSync(path.join(bin, "wl-paste"), `#!/bin/sh\necho "$*" >> "${log}"\ncase "$1" in --list-types) exec cat "${dir}/types" ;; esac\nexec cat "${dir}/body"\n`);
    fs.writeFileSync(path.join(bin, "python3"), `#!/bin/sh\necho python3 >> "${log}"\ncat\n`);
    fs.chmodSync(path.join(bin, "wl-paste"), 0o755);
    fs.chmodSync(path.join(bin, "python3"), 0o755);
    const env = { PATH: bin, BANDITSHELL_CLIP_STORE: path.join(dir, "store"), BANDITSHELL_CLIP_MAXTEXT: `${offer.maxText ?? 1048576}` };
    if (offer.state)
        env.CLIPBOARD_STATE = offer.state;
    const out = spawnSync("/bin/bash", [RECORD], { env, encoding: "utf8", maxBuffer: 16 * 1048576 });
    const asked = fs.existsSync(log) ? fs.readFileSync(log, "utf8").trim().split("\n") : [];
    fs.rmSync(dir, { recursive: true, force: true });
    assert.strictEqual(out.status, 0, out.stderr);
    const lines = out.stdout.split("\n").filter(Boolean);
    assert.strictEqual(lines.length, 1, out.stderr);
    return { event: JSON.parse(lines[0]), asked };
}

test.describe("clip-record.sh", () => {
    test.it("records a 200 KiB text copy whole", () => {
        const body = "a".repeat(200 * 1024);
        const { event } = record({ types: ["text/plain;charset=utf-8"], body });
        assert.strictEqual(event.state, "data");
        assert.strictEqual(event.text.length, body.length);
    });

    test.it("keeps a copy the source marks as a password out of the history", () => {
        const { event, asked } = record({ types: ["text/plain;charset=utf-8", "x-kde-passwordManagerHint"], body: "fake-secret-not-real" });
        assert.strictEqual(event.state, "sensitive");
        assert.strictEqual(event.text, undefined);
        assert.deepStrictEqual(asked, ["--list-types"]);
    });

    test.it("never reads the copy when wl-paste already says it is sensitive", () => {
        const { event, asked } = record({ state: "sensitive", types: ["text/plain"], body: "fake-secret-not-real" });
        assert.strictEqual(event.state, "sensitive");
        assert.strictEqual(event.text, undefined);
        assert.deepStrictEqual(asked, []);
    });

    test.it("drops a web page over the cap before converting it to text", () => {
        const body = `<!DOCTYPE html><p>${"x".repeat(5000)}</p>`;
        const { event, asked } = record({ types: ["text/plain"], body, maxText: 1000 });
        assert.strictEqual(event.dropped, true);
        assert.strictEqual(asked.includes("python3"), false);
    });

    test.it("records a file list too long to pass as one argument", () => {
        const names = Array.from({ length: 2000 }, (_, i) => `/nowhere/${"long-folder-name/".repeat(4)}file-${i}.txt`);
        const { event } = record({ types: ["text/uri-list"], body: names.map(n => `file://${n}`).join("\r\n") });
        assert.strictEqual(event.paths.length, 2000);
        assert.strictEqual(event.paths[1999], names[1999]);
        assert.strictEqual(event.mimes.length, 2000);
    });
});
