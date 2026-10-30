const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const SCRIPT = path.join(ROOT, "scripts/wallpaper-library.py");
const PYTHON = spawnSync("sh", ["-c", "command -v python3"], { encoding: "utf8" }).stdout.trim();
const src = fs.readFileSync(path.join(ROOT, "services/wallpaper-library.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Library = new Function(src + "\nreturn { read, kept, merged, shown };")();

function rig() {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "wallpaper-library-"));
    const bin = path.join(dir, "bin");
    const walls = path.join(dir, "walls");
    fs.mkdirSync(bin);
    fs.mkdirSync(walls);
    fs.writeFileSync(path.join(bin, "ffprobe"), '#!/bin/sh\nfor a; do f="$a"; done\necho "ffprobe $f" >>"$CALLS"\necho 1920,1080\n', { mode: 0o755 });
    fs.writeFileSync(path.join(bin, "ffmpeg"), '#!/bin/sh\nfor a; do out="$a"; done\necho "ffmpeg $out" >>"$CALLS"\n: >"$out"\n', { mode: 0o755 });
    const calls = path.join(dir, "calls");
    const bare = path.join(dir, "bare");
    fs.mkdirSync(bare);
    const run = ({ tools = true } = {}) => {
        fs.writeFileSync(calls, "");
        const out = spawnSync(PYTHON, ["-I", SCRIPT, path.join(dir, "cache.json"), path.join(dir, "posters"), walls, "png,svg,mp4", "mp4"], {
            encoding: "utf8",
            env: { PATH: tools ? `${bin}:/usr/bin:/bin` : bare, CALLS: calls }
        });
        assert.strictEqual(out.status, 0, out.stderr);
        const lines = out.stdout.trim().split("\n");
        return {
            lines,
            files: lines.filter(l => l.startsWith("file\t")).map(l => path.basename(l.split("\t")[1])),
            listed: lines.find(l => l.startsWith("listed\t")),
            probed: fs.readFileSync(calls, "utf8").split("\n").filter(Boolean).map(l => `${l.split(" ")[0]} ${path.basename(l.split(" ")[1])}`)
        };
    };
    return { dir, walls, run };
}

test.describe("wallpaper-library.py", () => {
    test.it("measures each wallpaper once and then answers from the cache", () => {
        const { dir, walls, run } = rig();
        fs.writeFileSync(path.join(walls, "a.png"), "a");
        fs.writeFileSync(path.join(walls, "b.mp4"), "b");
        fs.writeFileSync(path.join(walls, "c.svg"), "<svg><animate/></svg>");
        const first = run();
        assert.deepStrictEqual(first.files, ["a.png", "b.mp4", "c.svg"]);
        assert.strictEqual(first.listed, "listed\tchanged");
        assert.strictEqual(first.probed.filter(c => c.startsWith("ffprobe")).length, 3);
        assert.strictEqual(first.probed.filter(c => c.startsWith("ffmpeg")).length, 1);
        assert.ok(first.lines.includes(`frozen\t${walls}/c.svg\t1`));
        const again = run();
        assert.deepStrictEqual(again.probed, []);
        assert.strictEqual(again.listed, "listed\tsame");
        assert.deepStrictEqual(again.lines.filter(l => !l.startsWith("file")).sort(), first.lines.filter(l => !l.startsWith("file")).map(l => l.replace("listed\tchanged", "listed\tsame")).sort());
        fs.rmSync(dir, { recursive: true, force: true });
    });

    test.it("notices added, changed and removed files and never lists a deleted one", () => {
        const { dir, walls, run } = rig();
        fs.writeFileSync(path.join(walls, "a.png"), "a");
        fs.writeFileSync(path.join(walls, "b.mp4"), "b");
        run();
        fs.writeFileSync(path.join(walls, "new.png"), "n");
        const added = run();
        assert.deepStrictEqual(added.probed, ["ffprobe new.png"]);
        assert.strictEqual(added.listed, "listed\tchanged");
        fs.writeFileSync(path.join(walls, "b.mp4"), "b, re-encoded");
        const changed = run();
        assert.deepStrictEqual(changed.probed.map(c => c.split(" ")[0]).sort(), ["ffmpeg", "ffprobe"]);
        assert.ok(changed.probed.includes("ffprobe b.mp4"));
        fs.rmSync(path.join(walls, "a.png"));
        const removed = run();
        assert.deepStrictEqual(removed.files, ["b.mp4", "new.png"]);
        assert.strictEqual(removed.listed, "listed\tchanged");
        assert.ok(!removed.lines.some(l => l.includes("a.png")));
        assert.ok(!Object.keys(JSON.parse(fs.readFileSync(path.join(dir, "cache.json"), "utf8"))).some(k => k.endsWith("a.png")));
        fs.rmSync(dir, { recursive: true, force: true });
    });

    test.it("measures again once ffprobe and ffmpeg are installed, not before", () => {
        const { dir, walls, run } = rig();
        fs.writeFileSync(path.join(walls, "a.png"), "a");
        fs.writeFileSync(path.join(walls, "b.mp4"), "b");
        const without = run({ tools: false });
        assert.ok(without.lines.includes(`shape\t${walls}/a.png\t0\t0`));
        assert.ok(without.lines.includes(`poster\t${walls}/b.mp4\t`));
        const installed = run();
        assert.deepStrictEqual(installed.probed.map(c => c.split(" ")[0]).sort(), ["ffmpeg", "ffprobe", "ffprobe"]);
        assert.deepStrictEqual(run().probed, []);
        fs.rmSync(dir, { recursive: true, force: true });
    });

    test.it("lists a file reached twice once, by its first name, and survives a link loop", () => {
        const { dir, walls, run } = rig();
        fs.mkdirSync(path.join(walls, "sub"));
        fs.writeFileSync(path.join(walls, "sub", "z.png"), "z");
        fs.linkSync(path.join(walls, "sub", "z.png"), path.join(walls, "a.png"));
        fs.symlinkSync(walls, path.join(walls, "sub", "loop"));
        assert.deepStrictEqual(run().files, ["a.png"]);
        fs.rmSync(dir, { recursive: true, force: true });
    });
});

test.describe("library lines", () => {
    test.it("reads every kind of line and refuses broken ones", () => {
        assert.deepStrictEqual(Library.read("begin\t/w"), { kind: "begin", path: "/w" });
        assert.deepStrictEqual(Library.read("file\t/w/a b.png"), { kind: "file", path: "/w/a b.png" });
        assert.deepStrictEqual(Library.read("listed\tsame"), { kind: "listed", changed: false });
        assert.deepStrictEqual(Library.read("shape\t/w/a.png\t1920\t1080"), { kind: "shape", path: "/w/a.png", width: 1920, height: 1080 });
        assert.deepStrictEqual(Library.read("shape\t/w/a.png\t0\t0"), { kind: "shape", path: "/w/a.png", width: 0, height: 0 });
        assert.deepStrictEqual(Library.read("poster\t/w/b.mp4\t"), { kind: "poster", path: "/w/b.mp4", poster: "" });
        assert.deepStrictEqual(Library.read("frozen\t/w/c.svg\t1"), { kind: "frozen", path: "/w/c.svg", frozen: true });
        for (const junk of ["", "file", "shape\t/w/a.png\t1920", "what\tever", undefined])
            assert.strictEqual(Library.read(junk), null, String(junk));
    });

    test.it("drops entries for files that are gone and keeps the same map when none are", () => {
        const map = { "/a": 1, "/b": 2 };
        assert.strictEqual(Library.kept(map, ["/a", "/b", "/c"]), map);
        assert.deepStrictEqual(Library.kept(map, ["/b"]), { "/b": 2 });
    });

    test.it("merges updates, deleting on null, without touching the original", () => {
        const map = { "/a": 1, "/b": 2 };
        assert.strictEqual(Library.merged(map, {}), map);
        assert.deepStrictEqual(Library.merged(map, { "/a": null, "/c": 3 }), { "/b": 2, "/c": 3 });
        assert.deepStrictEqual(map, { "/a": 1, "/b": 2 });
    });
});

test("the shown wallpaper waits for the first read, falls back while config.json is unreadable, then follows the file", () => {
    const base = { want: "/w/sea.png", missing: "", verified: "", available: ["/w/sea.png"], fallback: "/s/moonrise.png" };
    assert.strictEqual(Library.shown({ ...base, ready: false, unreadable: false }), "");
    assert.strictEqual(Library.shown({ ...base, ready: false, unreadable: true }), "/s/moonrise.png");
    assert.strictEqual(Library.shown({ ...base, ready: true, unreadable: false }), "/w/sea.png");
    assert.strictEqual(Library.shown({ ...base, ready: true, unreadable: true }), "/w/sea.png");
    assert.strictEqual(Library.shown({ ...base, ready: true, unreadable: false, missing: "/w/sea.png" }), "/s/moonrise.png");
    assert.strictEqual(Library.shown({ ...base, ready: true, unreadable: false, want: "/w/new.png" }), "");
});
