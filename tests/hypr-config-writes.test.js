const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/hyprland-lua.js"), "utf8");
const Lua = new Function(src
    + "\nreturn { writeStep, trialScript, discardScript, shortName, pathOf, composeEntry, scanLua, spliceLines };")();

const HYPR = "/home/u/.config/hypr";
const FILE = "hl.bind(\"SUPER + A\", x)\nhl.bind(\"SUPER + B\", y)\n";

function commit(extra) {
    return Object.assign({
        file: "lua/binds.lua",
        path: `${HYPR}/lua/binds.lua`,
        startLine: 2,
        endLine: 2,
        replacement: ["hl.bind(\"SUPER + C\", z)"],
        previous: "",
        next: "",
        complaint: ""
    }, extra);
}

function read(c, disk, cached) {
    return Lua.writeStep(c, { type: "read", disk, cached });
}

function verified(c, purpose, ok, report, broken) {
    return Lua.writeStep(c, { type: "verified", purpose, ok, report, broken: !!broken, hyprDir: HYPR });
}

test.describe("reading the file before the write", () => {
    test.it("aborts when the file changed on disk since the scan", () => {
        const r = read(commit(), FILE + "-- edited elsewhere\n", FILE);
        assert.deepStrictEqual(r.action, { type: "abandon", why: "lua/binds.lua changed on disk since the scan" });
        assert.strictEqual(r.commit.next, "");
    });

    test.it("aborts when the file vanished but the scan had text", () => {
        assert.strictEqual(read(commit(), null, FILE).action.type, "abandon");
    });

    test.it("treats a missing file and a never-scanned file as the same empty text", () => {
        const r = read(commit({ startLine: 1, endLine: 1 }), null, undefined);
        assert.strictEqual(r.action.type, "verify");
        assert.strictEqual(r.commit.previous, "");
    });

    test.it("splices the replacement in, remembers the old text, and asks for a baseline check", () => {
        const r = read(commit(), FILE, FILE);
        assert.deepStrictEqual(r.action, { type: "verify", purpose: "baseline" });
        assert.strictEqual(r.commit.previous, FILE);
        assert.strictEqual(r.commit.next, "hl.bind(\"SUPER + A\", x)\nhl.bind(\"SUPER + C\", z)\n");
    });

    test.it("aborts when the lines are outside the file and writes nothing", () => {
        const r = read(commit({ startLine: 9, endLine: 9 }), FILE, FILE);
        assert.deepStrictEqual(r.action, { type: "abandon", why: "lines 9-9 are outside lua/binds.lua" });
        assert.strictEqual(r.commit.next, "");
    });

    test.it("leaves the commit it was given untouched", () => {
        const c = commit();
        read(c, FILE, FILE);
        assert.strictEqual(c.next, "");
        assert.strictEqual(c.previous, "");
    });
});

test.describe("the baseline check", () => {
    test.it("refuses to edit a config that already fails, naming the reason", () => {
        const r = verified(commit(), "baseline", false, "binds.lua:3: oops");
        assert.strictEqual(r.action.type, "abandon");
        assert.ok(r.action.why.startsWith("your Hyprland config fails Hyprland's own check as it is"));
        assert.ok(r.action.why.endsWith("binds.lua:3: oops"));
    });

    test.it("passes a broken checker's own report through unwrapped", () => {
        const r = verified(commit(), "baseline", false, "Hyprland --verify-config did not start", true);
        assert.deepStrictEqual(r.action, { type: "abandon", why: "Hyprland --verify-config did not start" });
    });

    test.it("tries a copy first for a file inside the Hyprland folder", () => {
        assert.strictEqual(verified(commit(), "baseline", true, "").action.type, "makeTrial");
    });

    test.it("writes directly for a file sourced from outside the folder, even one in a sibling folder with the same prefix", () => {
        const outside = commit({ path: "/home/u/.local/share/omarchy/default/hypr/bindings.conf" });
        assert.strictEqual(verified(outside, "baseline", true, "").action.type, "writeReal");
        const sibling = commit({ path: "/home/u/.config/hypr-extra/binds.lua" });
        assert.strictEqual(verified(sibling, "baseline", true, "").action.type, "writeReal");
    });
});

test.describe("the trial copy", () => {
    test.it("writes nothing when Hyprland rejects the trial copy", () => {
        const r = verified(read(commit(), FILE, FILE).commit, "trial", false, "binds.lua:2: unexpected symbol");
        assert.deepStrictEqual(r.action, { type: "abandon", why: "binds.lua:2: unexpected symbol" });
    });

    test.it("writes the real file only after the trial copy passes", () => {
        assert.strictEqual(verified(commit(), "trial", true, "").action.type, "writeReal");
    });

    test.it("verifies the copy it was handed, and falls back to a direct write with a note when none was made", () => {
        const made = Lua.writeStep(commit(), { type: "trialMade", directory: "/tmp/banditshell-verify.abc" });
        assert.deepStrictEqual(made.action, { type: "verifyTrial", directory: "/tmp/banditshell-verify.abc" });
        const none = Lua.writeStep(commit(), { type: "trialMade", directory: "" });
        assert.strictEqual(none.action.type, "writeReal");
        assert.ok(none.action.note);
    });
});

test.describe("verifying after the real write", () => {
    const written = () => read(commit(), FILE, FILE).commit;

    test.it("reloads Hyprland when the written file passes", () => {
        assert.strictEqual(verified(written(), "verifying", true, "").action.type, "reload");
    });

    test.it("keeps the report as the complaint and re-reads the file before undoing anything", () => {
        const r = verified(written(), "verifying", false, "binds.lua:2: bad");
        assert.deepStrictEqual(r.action, { type: "recheck", report: "binds.lua:2: bad" });
        assert.strictEqual(r.commit.complaint, "binds.lua:2: bad");
        assert.strictEqual(verified(written(), "verifying", false, "").commit.complaint, "Hyprland did not accept it");
    });

    test.it("puts the previous text back when the file on disk is still the edit", () => {
        const failed = verified(written(), "verifying", false, "bad").commit;
        const r = Lua.writeStep(failed, { type: "rechecked", disk: failed.next });
        assert.deepStrictEqual(r.action, { type: "revert", text: FILE });
    });

    test.it("leaves the file alone when someone changed it after the write", () => {
        const failed = verified(written(), "verifying", false, "bad").commit;
        const r = Lua.writeStep(failed, { type: "rechecked", disk: failed.next + "-- theirs\n" });
        assert.deepStrictEqual(r.action, { type: "finish", ok: false, said: "bad · lua/binds.lua was changed meanwhile, so it was left as it is" });
    });

    test.it("leaves the file alone when it is gone", () => {
        const failed = verified(written(), "verifying", false, "bad").commit;
        assert.strictEqual(Lua.writeStep(failed, { type: "rechecked", disk: null }).action.type, "finish");
    });
});

test.describe("shortName and pathOf", () => {
    const names = [
        ["files inside the folder", `${HYPR}/hyprland.lua`, "hyprland.lua"],
        ["files under lua/", `${HYPR}/lua/binds.lua`, "lua/binds.lua"],
        ["nested folders under lua/", `${HYPR}/lua/ui/theme.lua`, "lua/ui/theme.lua"],
        ["files sourced from outside the folder", "/home/u/.local/share/omarchy/default/hypr/bindings.conf", "/home/u/.local/share/omarchy/default/hypr/bindings.conf"],
        ["a sibling folder sharing the prefix", "/home/u/.config/hypr-extra/a.lua", "/home/u/.config/hypr-extra/a.lua"],
        ["names with spaces and quotes", `${HYPR}/lua/my "odd" it's.lua`, "lua/my \"odd\" it's.lua"]
    ];
    for (const [what, full, short] of names)
        test.it(`round-trips ${what}`, () => {
            assert.strictEqual(Lua.shortName(full, HYPR), short);
            assert.strictEqual(Lua.pathOf(short, HYPR), full);
        });
});

test.describe("an appended monitor entry", () => {
    const TABLE = [
        "local hosts = {",
        "    box = {",
        "        outputs = {",
        "            { output = \"DP-1\", mode = \"1920x1080@60\", position = \"0x0\", scale = 1 },",
        "        },",
        "    },",
        "}",
        ""
    ].join("\n");

    function added(output) {
        const line = Lua.composeEntry(null, { output, mode: "1920x1080@60", position: "0x0", scale: 1 });
        const scanned = Lua.scanLua(TABLE);
        const table = scanned.outputTables[0];
        const edited = Lua.spliceLines(TABLE, table.endLine, table.endLine, [`            ${line},`, "        },"]);
        return Lua.scanLua(edited).monitors.filter(m => m.output !== "DP-1");
    }

    test.it("reads back a name with spaces unchanged", () => {
        assert.strictEqual(added("Dell Inc. U2720Q ABC123")[0].output, "Dell Inc. U2720Q ABC123");
    });

    test.it("keeps double quotes, single quotes and backslashes inside the string", () => {
        const name = "Odd \"one\" it's back\\slash";
        const found = added(name);
        assert.strictEqual(found.length, 1);
        assert.strictEqual(found[0].output, name);
    });

    test.it("cannot be broken out of by a name that closes the string and starts a statement", () => {
        const found = added("x\", scale = 99 } os.execute(\"y");
        assert.strictEqual(found.length, 1);
        assert.strictEqual(found[0].scale, 1);
    });
});

test.describe("the trial copy script", () => {
    function run(hypr, name, text) {
        const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-trial-test-"));
        const r = spawnSync("sh", ["-c", Lua.trialScript(), "sh", hypr, name, text], { env: Object.assign({}, process.env, { TMPDIR: tmp }), encoding: "utf8" });
        return { tmp, out: r.stdout, status: r.status };
    }

    function folder(base) {
        const hypr = path.join(base, "my hypr 'x' \"y\"");
        fs.mkdirSync(path.join(hypr, "lua"), { recursive: true });
        fs.writeFileSync(path.join(hypr, "hyprland.lua"), "require(\"lua.binds\")\n");
        fs.writeFileSync(path.join(hypr, "lua/binds.lua"), "original\n");
        fs.writeFileSync(path.join(hypr, "lua/notes.txt"), "not config\n");
        return hypr;
    }

    test.it("copies only config files and puts the edited text in the named one, whatever the names contain", () => {
        const base = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-trial-src-"));
        const hypr = folder(base);
        fs.writeFileSync(path.join(hypr, "lua/it's \"b\" $x.lua"), "old\n");
        const text = "hl.bind(\"A\", hl.dsp.exec_cmd(\"echo $(id) `id` 'q'\"))\n";
        const r = run(hypr, "lua/it's \"b\" $x.lua", text);
        try {
            assert.strictEqual(r.status, 0);
            assert.ok(r.out.startsWith(r.tmp + "/banditshell-verify."));
            assert.strictEqual(fs.readFileSync(path.join(r.out, "lua/it's \"b\" $x.lua"), "utf8"), text);
            assert.strictEqual(fs.readFileSync(path.join(r.out, "lua/binds.lua"), "utf8"), "original\n");
            assert.ok(!fs.existsSync(path.join(r.out, "lua/notes.txt")));
            assert.strictEqual(fs.readFileSync(path.join(hypr, "lua/binds.lua"), "utf8"), "original\n");
        } finally {
            fs.rmSync(base, { recursive: true, force: true });
            fs.rmSync(r.tmp, { recursive: true, force: true });
        }
    });

    test.it("leaves nothing behind and prints nothing when the edited file cannot be placed", () => {
        const base = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-trial-src-"));
        const hypr = folder(base);
        const r = run(hypr, "missing-dir/new.lua", "x");
        try {
            assert.notStrictEqual(r.status, 0);
            assert.strictEqual(r.out, "");
            assert.deepStrictEqual(fs.readdirSync(r.tmp), []);
        } finally {
            fs.rmSync(base, { recursive: true, force: true });
            fs.rmSync(r.tmp, { recursive: true, force: true });
        }
    });

    test.it("discards only directories it made itself", () => {
        const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-trial-test-"));
        try {
            const mine = path.join(tmp, "banditshell-verify.abc");
            const other = path.join(tmp, "important");
            fs.mkdirSync(mine);
            fs.mkdirSync(other);
            for (const dir of [mine, other])
                spawnSync("sh", ["-c", Lua.discardScript(), "sh", dir]);
            assert.ok(!fs.existsSync(mine));
            assert.ok(fs.existsSync(other));
        } finally {
            fs.rmSync(tmp, { recursive: true, force: true });
        }
    });
});
