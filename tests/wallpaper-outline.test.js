const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const OUTLINE = path.join(ROOT, "scripts/wallpaper-outline.py");
const TRANSITION = path.join(ROOT, "scripts/wallpaper-transition.py");
const TUNER = path.join(ROOT, "scripts/outline-tuner.py");

function withCv(python) {
    return spawnSync(python, ["-I", "-c", "import cv2, numpy, PIL"]).status === 0;
}

const SYSTEM = "python3";
const VENV = path.join(process.env.XDG_DATA_HOME || path.join(os.homedir(), ".local", "share"), "banditshell", "cutout", "venv", "bin", "python");
const CV = [SYSTEM, VENV].find(p => (p === SYSTEM || fs.existsSync(p)) && withCv(p)) || null;
const needsCv = { skip: !CV && "needs numpy, opencv and pillow" };

function home(fn) {
    const base = fs.mkdtempSync(path.join(os.tmpdir(), "wallpaper-outline-"));
    const env = {
        PATH: process.env.PATH,
        HOME: base,
        XDG_CACHE_HOME: path.join(base, "cache"),
        XDG_CONFIG_HOME: path.join(base, "config"),
        XDG_DATA_HOME: path.join(base, "data")
    };
    try {
        return fn(env, base);
    } finally {
        fs.rmSync(base, { recursive: true, force: true });
    }
}

function py(env, file, body, python = SYSTEM) {
    const load = `import importlib.util as u, json\ns = u.spec_from_file_location("m", ${JSON.stringify(file)}); m = u.module_from_spec(s); s.loader.exec_module(m)\n${body}`;
    const run = spawnSync(python, ["-I", "-c", load], { env, encoding: "utf8", timeout: 60000 });
    assert.strictEqual(run.status, 0, run.stderr);
    return JSON.parse(run.stdout.trim().split("\n").pop());
}

const outline = (env, expr) => py(env, OUTLINE, `print(json.dumps(${expr}))`);

test.describe("preprocessing settings", () => {
    test.it("fills in defaults that change nothing", () => {
        home(env => {
            const prep = outline(env, `m.clean_prep(None)`);
            assert.deepStrictEqual(prep, { clip: 0, tile: 8, brightness: 0, gamma: 1, sharpen: 0, radius: 2, edges: 0, aspect: "squash" });
            assert.strictEqual(outline(env, `m.is_identity(None)`), true);
            assert.strictEqual(outline(env, `m.prep_tag({})`), "");
        });
    });

    test.it("clamps numbers, drops junk and unknown fits", () => {
        home(env => {
            const prep = outline(env, `m.clean_prep({"clip": 99, "gamma": "2", "tile": 3.6, "edges": True, "aspect": "zoom", "brightness": float("nan")})`);
            assert.strictEqual(prep.clip, 8);
            assert.strictEqual(prep.gamma, 1);
            assert.strictEqual(prep.tile, 4);
            assert.strictEqual(prep.edges, 0);
            assert.strictEqual(prep.aspect, "squash");
            assert.strictEqual(prep.brightness, 0);
        });
    });

    test.it("names a model mask by the settings that reach the model, and only those", () => {
        home(env => {
            const [a, b, c, d] = outline(env, `[m.prep_tag({"clip": 3}), m.prep_tag({"clip": 3, "radius": 5}), m.prep_tag({"clip": 3, "tile": 4}), m.prep_tag({"aspect": "tiles"})]`);
            assert.match(a, /^[0-9a-f]{10}$/);
            assert.strictEqual(a, b);
            assert.notStrictEqual(a, c);
            assert.ok(d && d !== a);
        });
    });

    test.it("covers a wide picture with overlapping squares that end flush", () => {
        home(env => {
            assert.deepStrictEqual(outline(env, `m.tile_starts(1280, 360)`), [0, 230, 460, 690, 920]);
            assert.deepStrictEqual(outline(env, `m.tile_starts(300, 360)`), [0]);
        });
    });
});

test.describe("the override file", () => {
    test.it("is keyed by file name under the config folder", () => {
        home(env => {
            const folder = outline(env, `m.overrides_dir(${JSON.stringify(env)})`);
            assert.strictEqual(folder, path.join(env.XDG_CONFIG_HOME, "banditshell", "wallpaper-outlines"));
            const paths = outline(env, `m.override_paths("/o", "/walls/32x9/leaf one.jpg")`);
            assert.deepStrictEqual(paths, { json: "/o/leaf one.jpg.json", mask: "/o/leaf one.jpg.mask.png", edits: "/o/leaf one.jpg.edits.png" });
        });
    });

    test.it("round trips, and a new save gives a new cache tag", () => {
        home((env, base) => {
            const folder = path.join(base, "o");
            const got = py(env, OUTLINE, `
f = ${JSON.stringify(folder)}
before = m.override_tag(f, "/w/a.jpg")
m.write_override(f, "/w/a.jpg", {"prep": {"clip": 2}, "threshold": 0.3, "seed": [0.25, 2], "line": "white"})
first, digest = m.read_override(f, "/w/a.jpg")
m.write_override(f, "/w/a.jpg", {"threshold": 0.3}, b"png-bytes", b"edits")
second, digest2 = m.read_override(f, "/w/a.jpg")
m.clear_override(f, "/w/a.jpg")
print(json.dumps([before, first, digest, second, digest2, m.override_tag(f, "/w/a.jpg"), sorted(__import__("os").listdir(f))]))`);
            const [before, first, digest, second, digest2, after, left] = got;
            assert.strictEqual(before, "");
            assert.strictEqual(first.prep.clip, 2);
            assert.strictEqual(first.threshold, 0.3);
            assert.deepStrictEqual(first.seed, [0.25, 1]);
            assert.strictEqual(first.line, "white");
            assert.strictEqual(first.edited, false);
            assert.strictEqual(second.edited, true);
            assert.match(second.mask_sha, /^[0-9a-f]{12}$/);
            assert.notStrictEqual(digest, digest2);
            assert.strictEqual(after, "");
            assert.deepStrictEqual(left, []);
        });
    });

    test.it("ignores a broken or foreign file", () => {
        home((env, base) => {
            const folder = path.join(base, "o");
            fs.mkdirSync(folder);
            fs.writeFileSync(path.join(folder, "a.jpg.json"), "{not json");
            fs.writeFileSync(path.join(folder, "b.jpg.json"), "[1, 2]");
            assert.deepStrictEqual(outline(env, `[m.read_override(${JSON.stringify(folder)}, "a.jpg"), m.read_override(${JSON.stringify(folder)}, "b.jpg")]`), [[null, ""], [null, ""]]);
        });
    });

    test.it("trusts a hand mask only when it carries its hash", () => {
        home(env => {
            assert.strictEqual(outline(env, `m.clean_override({"edited": True})["edited"]`), false);
            assert.strictEqual(outline(env, `m.clean_override({"edited": True, "mask_sha": "abc"})["edited"]`), true);
        });
    });

    test.it("draws the line in the accent, the brightest colour or white", () => {
        home(env => {
            assert.deepStrictEqual(outline(env, `[m.line_colour(("#aa0000", "#222222"), c) for c in ("ember", "ink", "white", "bogus")]`), ["#aa0000", "#222222", "#ffffff", "#aa0000"]);
            assert.deepStrictEqual(outline(env, `[m.line_colour(None, "ember"), m.line_colour(None, "white")]`), [null, "#ffffff"]);
        });
    });
});

test.describe("the tuner", () => {
    test.it("reads the wallpaper folder from config.json, with ~ expanded", () => {
        home((env, base) => {
            fs.mkdirSync(path.join(env.XDG_CONFIG_HOME, "banditshell"), { recursive: true });
            fs.writeFileSync(path.join(env.XDG_CONFIG_HOME, "banditshell", "config.json"), JSON.stringify({ wallpaper: { dir: "~/walls" } }));
            assert.strictEqual(py(env, TUNER, `print(json.dumps(m.wallpaper_dir(${JSON.stringify(env)})))`), path.join(base, "walls"));
        });
    });

    test.it("falls back to Pictures/Wallpapers", () => {
        home((env, base) => {
            assert.strictEqual(py(env, TUNER, `print(json.dumps(m.wallpaper_dir(${JSON.stringify(env)})))`), path.join(base, "Pictures", "Wallpapers"));
        });
    });

    test.it("lists stills below the folder and skips hidden ones", () => {
        home((env, base) => {
            const walls = path.join(base, "walls");
            for (const f of ["b.jpg", "sub/A.png", "sub/clip.mp4", ".hidden/c.jpg", "notes.txt"]) {
                fs.mkdirSync(path.dirname(path.join(walls, f)), { recursive: true });
                fs.writeFileSync(path.join(walls, f), "");
            }
            assert.deepStrictEqual(py(env, TUNER, `print(json.dumps(m.list_stills(${JSON.stringify(walls)})))`), ["b.jpg", "sub/A.png"]);
        });
    });

    test.it("names the machine by its tailnet name, else its host name", () => {
        home(env => {
            const got = py(env, TUNER, `
import types, socket
ok = lambda *a, **k: types.SimpleNamespace(returncode=0, stdout='{"Self": {"DNSName": "box.example.ts.net."}}')
def gone(*a, **k): raise FileNotFoundError()
print(json.dumps([m.public_host(ok), m.public_host(gone) == socket.gethostname()]))`);
            assert.deepStrictEqual(got, ["box.example.ts.net", true]);
        });
    });

    test.it("puts the starting file in the query, escaped", () => {
        home(env => {
            assert.strictEqual(py(env, TUNER, `print(json.dumps(m.tuner_url("box", 8123, "32x9/a b&c.jpg")))`), "http://box:8123/?file=32x9%2Fa+b%26c.jpg");
            assert.strictEqual(py(env, TUNER, `print(json.dumps(m.tuner_url("box", 8123)))`), "http://box:8123/");
        });
    });
});

test.describe("images", () => {
    test.it("leaves the picture alone with default settings", needsCv, () => {
        home(env => {
            const got = py(env, OUTLINE, `
import numpy as np
a = (np.arange(48 * 32 * 3) % 251).astype(np.uint8).reshape(32, 48, 3)
b = m.preprocess(a, {"clip": 2, "edges": 0.5})
print(json.dumps([m.preprocess(a, {"aspect": "tiles"}) is a, b.shape == a.shape, b.dtype == np.uint8, bool((b != a).any())]))`, CV);
            assert.deepStrictEqual(got, [true, true, true, true]);
        });
    });

    test.it("brightens a dark picture with gamma and brightness", needsCv, () => {
        home(env => {
            const got = py(env, OUTLINE, `
import numpy as np
a = np.full((8, 8, 3), 40, np.uint8)
print(json.dumps([int(m.preprocess(a, {"gamma": 2})[0, 0, 0]), int(m.preprocess(a, {"brightness": 0.2})[0, 0, 0])]))`, CV);
            assert.ok(got[0] > 90 && got[1] > 85, JSON.stringify(got));
        });
    });

    test.it("hands the model a square and puts the mask back where the picture was", needsCv, () => {
        home(env => {
            const got = py(env, OUTLINE, `
import numpy as np
a = np.zeros((20, 80, 3), np.uint8)
seen = []
def run(x):
    seen.append(x.shape[:2])
    return np.full(x.shape[:2], 200, np.uint8)
pad = m.cut(a, "pad", run)
tiles = m.cut(a, "tiles", run)
print(json.dumps([seen, pad.shape, tiles.shape, int(pad.min()), int(tiles.min())]))`, CV);
            const [seen, pad, tiles, padMin, tilesMin] = got;
            assert.deepStrictEqual(seen[0], [80, 80]);
            assert.ok(seen.slice(1).every(s => s[0] === 20 && s[1] === 20));
            assert.strictEqual(seen.length, 1 + 5);
            assert.deepStrictEqual(pad, [20, 80]);
            assert.deepStrictEqual(tiles, [20, 80]);
            assert.strictEqual(padMin, 200);
            assert.strictEqual(tilesMin, 200);
        });
    });

    test.it("fills outward from the seed, through the subject before across a gap", needsCv, () => {
        home(env => {
            const got = py(env, TRANSITION, `
import numpy as np
O = m.Outline
b = np.zeros((40, 160), np.uint8)
b[8:32, 8:60] = 1
b[8:32, 100:150] = 1
o = O.seed_order(b, (0.1, 0.5), m.arrival)
print(json.dumps([float(o[20, 12]), float(o[20, 55]), float(o[20, 120]), float(o[0, 0]), float(o.max())]))`, CV);
            const [near, far, across, outside, top] = got;
            assert.ok(near < far && far < across, JSON.stringify(got));
            assert.strictEqual(outside, 0);
            assert.ok(top <= 1);
        });
    });

    test.it("builds the outline from a hand mask, grows it from the seed and picks the chosen line colour", needsCv, () => {
        home((env, base) => {
            const got = py(env, TRANSITION, `
import os
import numpy as np
from PIL import Image
img = os.path.join(${JSON.stringify(base)}, "a.png")
Image.fromarray(np.full((90, 320, 3), 60, np.uint8)).save(img)
hand = np.zeros((90, 320), np.uint8)
hand[20:70, 40:200] = 255
buf = __import__("io").BytesIO()
Image.fromarray(hand, "L").save(buf, "PNG")
m.Outline.write_override(m.overrides(), img, {"seed": [0.6, 0.5], "line": "white"}, buf.getvalue())
field, line = m.outline(img)
g = np.asarray(Image.open(field))[..., 1]
meta = json.load(open(m.outline_base(img) + ".json"))
import contextlib, io
out = io.StringIO()
with contextlib.redirect_stdout(out):
    m.pick(img, 320, 90, "t1")
print(json.dumps([int(g[45, 190]), int(g[45, 45]), meta["override"] != "", meta["ok"], out.getvalue().strip().split("\\t")]))`, CV);
            const [atSeed, farEnd, tagged, ok, answer] = got;
            assert.ok(atSeed < farEnd, JSON.stringify(got));
            assert.strictEqual(tagged, true);
            assert.strictEqual(ok, true);
            assert.strictEqual(answer.length, 5);
            assert.strictEqual(answer[1], "outline");
            assert.strictEqual(answer[4], "#ffffff");
        });
    });
});
