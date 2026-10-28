const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/clipboard-sweep.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Sweep = new Function(src + "\nreturn { command, wanted };")();

function blobsWith(names) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "clipboard-sweep-"));
    for (const n of names)
        fs.writeFileSync(path.join(dir, n), n);
    return dir;
}

function run(command) {
    const [bin, ...args] = command;
    const done = spawnSync(bin, args, { encoding: "utf8" });
    assert.strictEqual(done.status, 0, done.stderr);
}

test.describe("clipboard sweep", () => {
    test.it("sweeps nothing while the history file could not be read", () => {
        const dir = blobsWith(["a.png", "b.png"]);
        try {
            assert.strictEqual(Sweep.command(dir, `${dir}.json`, [], false), null);
            assert.strictEqual(Sweep.command(dir, `${dir}.json`, [{ file: `${dir}/a.png` }], false), null);
            assert.deepStrictEqual(fs.readdirSync(dir).sort(), ["a.png", "b.png"]);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });

    test.it("deletes only the pictures no entry points at", () => {
        const dir = blobsWith(["kept.png", "gone.png", "pinned shot 1.png", "imported-old.jpg"]);
        try {
            const entries = [
                { text: "hello" },
                { file: `${dir}/kept.png` },
                { file: `${dir}/pinned shot 1.png`, pinned: true }
            ];
            run(Sweep.command(dir, `${dir}.json`, entries, true));
            assert.deepStrictEqual(fs.readdirSync(dir).sort(), ["kept.png", "pinned shot 1.png"]);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });

    test.it("never deletes a picture that was there when the history was found damaged", () => {
        const dir = blobsWith(["kept.png", "cut off.png", "after.png", "after kept.png"]);
        const backup = `${dir}.json.damaged-20261028-140509`;
        try {
            const then = new Date(Date.now() - 60000);
            for (const n of ["kept.png", "cut off.png"])
                fs.utimesSync(path.join(dir, n), then, then);
            fs.writeFileSync(backup, '{"entries":[{"file":"/s/cut o');
            const at = new Date(Date.now() - 30000);
            fs.utimesSync(backup, at, at);
            run(Sweep.command(dir, `${dir}.json`, [{ file: `${dir}/kept.png` }, { file: `${dir}/after kept.png` }], true));
            assert.deepStrictEqual(fs.readdirSync(dir).sort(), ["after kept.png", "cut off.png", "kept.png"]);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
            fs.rmSync(backup, { force: true });
        }
    });

    test.it("looks for damaged copies beside the history file it is given", () => {
        const dir = blobsWith(["old.png"]);
        const history = `${dir}-history.json`;
        try {
            const then = new Date(Date.now() - 60000);
            fs.utimesSync(path.join(dir, "old.png"), then, then);
            fs.writeFileSync(`${history}.damaged-20261028-140509`, "{");
            run(Sweep.command(dir, history, [], true));
            assert.deepStrictEqual(fs.readdirSync(dir), ["old.png"]);
            assert.strictEqual(Sweep.command(dir, "", [], true), null);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
            fs.rmSync(`${history}.damaged-20261028-140509`, { force: true });
        }
    });

    test.it("leaves a missing blobs folder alone", () => {
        const dir = path.join(os.tmpdir(), `clipboard-sweep-missing-${process.pid}`);
        run(Sweep.command(dir, `${dir}.json`, [], true));
        assert.strictEqual(fs.existsSync(dir), false);
    });

    test.it("names each kept picture by its file name", () => {
        assert.deepStrictEqual(Sweep.wanted([{ file: "/x/a.png" }, { text: "t" }, null, { file: "b.png" }]), ["a.png", "b.png"]);
    });
});
