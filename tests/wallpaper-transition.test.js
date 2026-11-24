const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Transition = new Function(read("services/wallpaper-transition.js") + "\nreturn { readPick };")();

const SCRIPT = path.join(ROOT, "scripts/wallpaper-transition.py");
const PYTHON = spawnSync("python3", ["-c", "import sys; print(sys.executable)"], { encoding: "utf8" }).stdout.trim();
const PIC = "/pictures/sea.jpg";
const line = (...bits) => bits.join("\t") + "\n";

test.describe("readPick", () => {
    test.it("reads a contagion answer with its colours", () => {
        assert.deepStrictEqual(Transition.readPick(line(PIC, "contagion", "/c/map-3.png", "/c/map-3-smooth.png", "#58b1e4", "#2f9ddd"), PIC), {
            kind: "contagion",
            field: "/c/map-3.png",
            line: "/c/map-3-smooth.png",
            ember: "#58b1e4",
            ink: "#2f9ddd"
        });
    });

    test.it("reads an outline answer", () => {
        assert.strictEqual(Transition.readPick(line(PIC, "outline", "/c/a-field.png", "/c/a-line.png", "#f3d278", "#f3d278"), PIC).kind, "outline");
    });

    test.it("leaves the colours empty when the picture gave none", () => {
        const found = Transition.readPick(line("-", "contagion", "/c/m.png", "/c/s.png", "-", "-"), "-");
        assert.strictEqual(found.ember, "");
        assert.strictEqual(found.ink, "");
    });

    test.it("ignores an answer about another wallpaper", () => {
        assert.strictEqual(Transition.readPick(line("/pictures/old.jpg", "contagion", "/c/m.png", "/c/s.png", "-", "-"), PIC), null);
    });

    test.it("ignores an answer cut short", () => {
        assert.strictEqual(Transition.readPick(`${PIC}\tcontagion\t/c/m.png`, PIC), null);
        assert.strictEqual(Transition.readPick("", PIC), null);
    });

    test.it("keeps tabs and spaces in a path apart", () => {
        const odd = "/pictures/my sea.jpg";
        assert.strictEqual(Transition.readPick(line(odd, "contagion", "/c/m.png", "/c/s.png", "-", "-"), odd).field, "/c/m.png");
    });

    test.it("fails an answer of a kind it does not know", () => {
        assert.deepStrictEqual(Transition.readPick(line(PIC, "sparkle", "/c/m.png", "/c/s.png", "-", "-"), PIC), { failed: true });
    });
});

function home(fn) {
    const base = fs.mkdtempSync(path.join(os.tmpdir(), "wallpaper-transition-"));
    const env = {
        PATH: path.join(base, "bin"),
        HOME: base,
        XDG_CACHE_HOME: path.join(base, "cache"),
        XDG_DATA_HOME: path.join(base, "data")
    };
    fs.mkdirSync(env.PATH);
    try {
        return fn(env, base);
    } finally {
        fs.rmSync(base, { recursive: true, force: true });
    }
}

function script(env, args) {
    const run = spawnSync(PYTHON, ["-I", SCRIPT, ...args], { env, encoding: "utf8", timeout: 20000 });
    assert.strictEqual(run.error, undefined);
    return run;
}

function inside(env, expr) {
    const load = `import importlib.util as u; s = u.spec_from_file_location("w", ${JSON.stringify(SCRIPT)}); m = u.module_from_spec(s); s.loader.exec_module(m); import json; print(json.dumps(${expr}))`;
    const run = spawnSync(PYTHON, ["-I", "-c", load], { env, encoding: "utf8" });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout);
}

const hasNumpy = spawnSync("python3", ["-I", "-c", "import numpy, PIL"]).status === 0;

test.describe("the map maker", () => {
    test.it("says the cut-out is missing in a fresh data folder", () => {
        home(env => assert.strictEqual(script(env, ["status"]).stdout.trim(), "missing"));
    });

    test.it("answers none with the ticket when no maps exist for the screen yet", () => {
        home(env => {
            const run = script(env, ["pick", "-", "64", "36", "t7"]);
            assert.strictEqual(run.status, 0, run.stderr);
            assert.deepStrictEqual(Transition.readPick(run.stdout, "t7"), { failed: true });
        });
    });

    test.it("installs with uv into its own Python when uv is there", () => {
        home(env => {
            const steps = inside(env, `m.install_steps("/usr/bin/uv", False)`);
            assert.deepStrictEqual(steps[0].slice(0, 5), ["/usr/bin/uv", "venv", "-q", "--python", "3.12"]);
            assert.strictEqual(steps[1][1], "pip");
            assert.ok(steps[1].includes("rembg"));
            assert.match(steps[2][2], /new_session\('birefnet-general-lite'\)/);
        });
    });

    test.it("falls back to venv and pip without uv, and skips a venv that exists", () => {
        home(env => {
            const steps = inside(env, `m.install_steps(None, True)`);
            assert.strictEqual(steps.length, 2);
            assert.deepStrictEqual(steps[0].slice(1, 5), ["-m", "pip", "install", "-q"]);
        });
    });

    test.it("runs the cut-out in a scope capped at 8 GB with no swap", () => {
        home(env => {
            fs.writeFileSync(path.join(env.PATH, "systemd-run"), "#!/bin/sh\n", { mode: 0o755 });
            const cmd = inside(env, `m.capped_command(["/pictures/a.jpg", "/pictures/b.jpg"])`);
            assert.deepStrictEqual(cmd.slice(1, 8), ["--user", "--scope", "-q", "-p", "MemoryMax=8G", "-p", "MemorySwapMax=0"]);
            assert.deepStrictEqual(cmd.slice(-3), ["outline", "/pictures/a.jpg", "/pictures/b.jpg"]);
        });
    });

    test.it("runs the cut-out uncapped where systemd-run is missing", () => {
        home(env => assert.strictEqual(inside(env, `m.capped_command(["/pictures/a.jpg"])[2]`), "outline"));
    });

    test.it("fills a pool, then picks a whole pair from it", { skip: !hasNumpy && "needs numpy and pillow" }, () => {
        home(env => {
            env.PATH = process.env.PATH;
            assert.strictEqual(script(env, ["warm", "64x36"]).status, 0);
            const found = Transition.readPick(script(env, ["pick", "-", "64", "36", "t8"]).stdout, "t8");
            assert.strictEqual(found.kind, "contagion");
            assert.ok(fs.existsSync(found.field) && fs.existsSync(found.line));
            assert.match(found.line, /-smooth\.png$/);
        });
    });
});
