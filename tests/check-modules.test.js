const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const check = require("../scripts/check-modules.js");

function capture(argv) {
    const out = [];
    const err = [];
    const code = check.run(argv, (text, error) => (error ? err : out).push(text));
    return { code, out: out.join("\n"), err: err.join("\n") };
}

function makeRepo(files) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-modules-"));
    for (const [name, content] of Object.entries(files)) {
        const target = path.join(dir, name);
        fs.mkdirSync(path.dirname(target), { recursive: true });
        fs.writeFileSync(target, typeof content === "string" ? content : JSON.stringify(content));
    }
    return dir;
}

function manifest(name, layer, extra) {
    return {
        name,
        summary: `the ${name} package`,
        layer,
        owns: {},
        requires: { packages: [], optional: [] },
        provides: { singletons: [], ipc: [] },
        config: { namespace: [], reads: [] },
        ...extra
    };
}

function fixture(extra) {
    return {
        "packages/core.json": manifest("core", 0, {
            owns: { qml: ["config", "components", "services/qmldir"] },
            provides: { singletons: ["Appearance"], ipc: [] },
            config: { namespace: ["theme"], reads: [] }
        }),
        "components/Button.qml": "Item {}\n",
        "config/qmldir": "module qs.config\nsingleton Appearance 1.0 Appearance.qml\n",
        "config/Appearance.qml": "pragma Singleton\nSingleton {}\n",
        "services/qmldir": "module qs.services\nsingleton Alpha 1.0 Alpha.qml\nsingleton Beta 1.0 Beta.qml\n",
        "services/Alpha.qml": "pragma Singleton\nSingleton { property int count: 0 }\n",
        "services/Beta.qml": "pragma Singleton\nSingleton { property int count: 0 }\n",
        "modules/a/module.json": manifest("a", 1, {
            owns: { qml: ["modules/a"], services: ["Alpha"] },
            requires: { packages: ["core"], optional: [] },
            provides: { singletons: ["Alpha"], ipc: [] },
            config: { namespace: ["alpha"], reads: [] }
        }),
        "modules/a/Panel.qml": "import qs.config\nItem { property int n: Alpha.count + Appearance.size }\n",
        "modules/b/module.json": manifest("b", 1, {
            owns: { qml: ["modules/b"], services: ["Beta"] },
            requires: { packages: ["core"], optional: [] },
            provides: { singletons: ["Beta"], ipc: [] }
        }),
        "modules/b/Panel.qml": "import qs.config\nItem { property int n: Beta.count }\n",
        ...extra
    };
}

function evaluate(files) {
    const dir = makeRepo(files);
    try {
        return check.evaluate(check.scan(dir));
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

test.describe("stripping code", () => {
    test.it("blanks comments and strings but keeps every line where it was", () => {
        const src = 'a // Hypr\nb /* Hypr\nHypr */ c "Hypr" \'Hypr\'\nd';
        const bare = check.stripCode(src, false);
        assert.strictEqual(bare.split("\n").length, src.split("\n").length);
        assert.ok(!bare.includes("Hypr"));
        assert.ok(bare.includes("a") && bare.includes("b") && bare.includes("c") && bare.includes("d"));
    });

    test.it("keeps string contents when asked, still dropping comments", () => {
        const kept = check.stripCode('x("ns.key") // Config.get("gone.key")', true);
        assert.ok(kept.includes('"ns.key"'));
        assert.ok(!kept.includes("gone.key"));
    });

    test.it("reads the expressions inside a template literal as code", () => {
        const bare = check.stripCode("const t = `label ${Hypr.name} and ${a ? `${Idle.awake}` : \"Lock\"} text Power`;", false);
        assert.ok(bare.includes("Hypr.name"));
        assert.ok(bare.includes("Idle.awake"));
        assert.ok(!bare.includes("Lock"));
        assert.ok(!bare.includes("Power"));
    });

    test.it("ends an unfinished string at the line, so one stray quote loses one line", () => {
        const bare = check.stripCode("a = /\"/;\nHypr.x\n", false);
        assert.ok(bare.includes("Hypr.x"));
    });
});

test.describe("reading imports", () => {
    test.it("finds shell modules, folders and scripts with their lines", () => {
        const src = 'import QtQuick\nimport qs.modules.menu.content\nimport "../controls"\nimport "search.js" as Search\n.import "../x.js" as X\n';
        assert.deepStrictEqual(check.parseImports(src), [
            { kind: "qs", target: "modules.menu.content", line: 2 },
            { kind: "relative", target: "../controls", line: 3 },
            { kind: "relative", target: "search.js", line: 4 },
            { kind: "relative", target: "../x.js", line: 5 }
        ]);
    });

    test.it("lists singletons from a qmldir and nothing else", () => {
        const text = "module qs.services\nsingleton Hypr 1.0 Hypr.qml\nNotice 1.0 Notice.qml\nsingleton Lock 1.0 Lock.qml\n";
        assert.deepStrictEqual(check.parseQmldir(text), [{ name: "Hypr", file: "Hypr.qml" }, { name: "Lock", file: "Lock.qml" }]);
    });
});

test.describe("finding singleton use", () => {
    const names = ["Hypr", "Idle", "Lock"];
    const uses = src => check.findSingletonUses(check.stripCode(src, false), names).map(u => `${u.name}:${u.line}`);

    test.it("counts a bare name and skips member access, longer words and types", () => {
        assert.deepStrictEqual(uses("a: Hypr.x\nb: root.Idle.y\nc: HyprLand\nLock {\n}\nd: Lock.lock()"), ["Hypr:1", "Lock:6"]);
    });

    test.it("ignores comments and strings", () => {
        assert.deepStrictEqual(uses('// Hypr\nx: "Idle"\ny: Idle.awake'), ["Idle:3"]);
    });

    test.it("sees a name inside a template expression", () => {
        assert.deepStrictEqual(uses("x: `${Hypr.name}`"), ["Hypr:1"]);
    });

    test.it("finds writes to a property and not comparisons", () => {
        const writes = src => check.findForeignWrites(check.stripCode(src, false), names).map(w => `${w.name}.${w.property}`);
        assert.deepStrictEqual(writes("Idle.awake = true\nIdle.mode += 1\nif (Idle.awake == 1) x()\nIdle.a <= 3\nf(() => Idle.b)"), ["Idle.awake", "Idle.mode"]);
    });
});

test.describe("finding config reads", () => {
    const keys = src => check.findConfigReads(check.stripCode(src, true)).map(r => r.key);

    test.it("reads the dotted path after Config.values", () => {
        assert.deepStrictEqual(keys("x: Config.values.launcher.devOps.ports && Config.values.theme"), ["launcher.devOps.ports", "theme"]);
    });

    test.it("reads Config.get, Config.set and catalogue cfg strings", () => {
        assert.deepStrictEqual(keys('Config.get("files.zoom")\nConfig.set("clipboard.record", true)\n{ cfg: "island.downloads" }'), ["files.zoom", "clipboard.record", "island.downloads"]);
    });

    test.it("follows a property that aliases Config.values", () => {
        assert.deepStrictEqual(keys("readonly property var config: Config.values\nx: root.config.files.zoom\ny: config.theme"), ["files.zoom", "theme"]);
    });

    test.it("matches a key to the longest namespace and lets reads cover prefixes", () => {
        const spaces = [{ namespace: "launcher", pkg: "launcher" }, { namespace: "launcher.devOps", pkg: "launcher-devops" }];
        assert.strictEqual(check.namespaceOwner("launcher.devOps.ports", spaces).pkg, "launcher-devops");
        assert.strictEqual(check.namespaceOwner("launcher.aliases", spaces).pkg, "launcher");
        assert.strictEqual(check.namespaceOwner("launcherX.y", spaces), null);
        assert.ok(check.readsCover(["control"], "control.pullSlack"));
        assert.ok(!check.readsCover(["control"], "controls.x"));
    });
});

test.describe("finding ipc targets", () => {
    test.it("takes a handler's own target line and not a data field", () => {
        const src = 'IpcHandler {\n    target: "menu"\n}\nconst o = { target: "empty", y: 1 }\nConnections {\n    target: foo\n}\n';
        assert.deepStrictEqual(check.findIpcTargets(src).map(t => t.name), ["menu"]);
    });
});

test.describe("cycles and manifests", () => {
    test.it("finds the groups that depend on each other and ignores a plain chain", () => {
        const graph = { a: ["b"], b: ["c"], c: ["a"], d: ["a"], e: [] };
        const groups = check.findCycles(Object.keys(graph), n => graph[n]);
        assert.deepStrictEqual(groups, [["a", "b", "c"]]);
    });

    test.it("explains what is wrong with a manifest", () => {
        const problems = [];
        check.validateManifest({ name: "Bad Name", layer: "x", owns: { qml: "no" }, extra: 1 }, "packages/bad.json", problems);
        const text = problems.join("\n");
        assert.match(text, /unknown field extra/);
        assert.match(text, /lowercase name/);
        assert.match(text, /integer layer/);
        assert.match(text, /owns\.qml to be a list/);
        assert.match(text, /needs a requires object/);
    });
});

test.describe("checking a small repo", () => {
    test.it("passes when each package sticks to what it requires", () => {
        assert.deepStrictEqual(evaluate(fixture()).violations, []);
    });

    test.it("flags a file nobody owns and a file two packages own", () => {
        const found = evaluate(fixture({
            "modules/stray/Thing.qml": "Item {}\n",
            "modules/b/module.json": manifest("b", 1, {
                owns: { qml: ["modules/b", "modules/a/Panel.qml"], services: ["Beta"] },
                requires: { packages: ["core"], optional: [] },
                provides: { singletons: ["Beta"], ipc: [] }
            })
        })).violations;
        assert.ok(found.includes("R1 modules/stray/Thing.qml is owned by no package"));
        assert.ok(!found.some(v => v.startsWith("R1 modules/a/Panel.qml")));
    });

    test.it("flags a double claim on the very same path", () => {
        const found = evaluate(fixture({
            "modules/b/module.json": manifest("b", 1, {
                owns: { qml: ["modules/b", "modules/a"], services: ["Beta"] },
                requires: { packages: ["core"], optional: [] },
                provides: { singletons: ["Beta"], ipc: [] }
            })
        })).violations;
        assert.ok(found.includes("R1 modules/a/Panel.qml is owned by a and b"));
    });

    test.it("flags a singleton or an import taken from a package that is not required", () => {
        const found = evaluate(fixture({
            "modules/b/Panel.qml": 'import qs.config\nimport "../a"\nItem { property int n: Alpha.count }\n'
        })).violations;
        assert.ok(found.includes("R3 modules/b/Panel.qml uses Alpha of a without requiring it"));
        assert.ok(found.includes("R2 modules/b/Panel.qml imports a without requiring it"));
    });

    test.it("flags a private singleton even when the package is required", () => {
        const found = evaluate(fixture({
            "modules/a/module.json": manifest("a", 1, {
                owns: { qml: ["modules/a"], services: ["Alpha"] },
                requires: { packages: ["core"], optional: [] },
                provides: { singletons: [], ipc: [] }
            }),
            "modules/b/module.json": manifest("b", 2, {
                owns: { qml: ["modules/b"], services: ["Beta"] },
                requires: { packages: ["core", "a"], optional: [] },
                provides: { singletons: ["Beta"], ipc: [] }
            }),
            "modules/b/Panel.qml": "import qs.config\nItem { property int n: Alpha.count }\n"
        })).violations;
        assert.ok(found.includes("R3 modules/b/Panel.qml uses Alpha, private to a"));
    });

    test.it("flags config read from another package's namespace unless it is listed", () => {
        const read = 'import qs.config\nItem { property int n: Config.values.alpha.size + Config.values.theme.size }\n';
        const found = evaluate(fixture({ "modules/b/Panel.qml": read })).violations;
        assert.ok(found.includes("R5 modules/b/Panel.qml reads alpha of a"));
        assert.ok(found.includes("R5 modules/b/Panel.qml reads theme of core"));
        const listed = evaluate(fixture({
            "modules/b/Panel.qml": read,
            "modules/b/module.json": manifest("b", 1, {
                owns: { qml: ["modules/b"], services: ["Beta"] },
                requires: { packages: ["core"], optional: [] },
                provides: { singletons: ["Beta"], ipc: [] },
                config: { namespace: [], reads: ["alpha", "theme"] }
            })
        })).violations;
        assert.ok(!listed.some(v => v.startsWith("R5")));
    });

    test.it("flags a dependency cycle and a layer that does not climb", () => {
        const found = evaluate(fixture({
            "modules/a/module.json": manifest("a", 1, {
                owns: { qml: ["modules/a"], services: ["Alpha"] },
                requires: { packages: ["core", "b"], optional: [] },
                provides: { singletons: ["Alpha"], ipc: [] },
                config: { namespace: ["alpha"], reads: [] }
            }),
            "modules/b/module.json": manifest("b", 1, {
                owns: { qml: ["modules/b"], services: ["Beta"] },
                requires: { packages: ["core", "a"], optional: [] },
                provides: { singletons: ["Beta"], ipc: [] }
            })
        })).violations;
        assert.ok(found.includes("R8 requires form a cycle: a, b"));
        assert.ok(found.includes("R8 a (layer 1) requires b (layer 1)"));
    });

    test.it("flags an ipc target no package declares, or one in the wrong package", () => {
        const handler = name => `import Quickshell.Io\nIpcHandler {\n    target: "${name}"\n}\n`;
        const found = evaluate(fixture({
            "modules/a/Ipc.qml": handler("alpha"),
            "modules/b/Ipc.qml": handler("beta"),
            "modules/a/module.json": manifest("a", 1, {
                owns: { qml: ["modules/a"], services: ["Alpha"] },
                requires: { packages: ["core"], optional: [] },
                provides: { singletons: ["Alpha"], ipc: ["alpha", "beta", "gone"] },
                config: { namespace: ["alpha"], reads: [] }
            })
        })).violations;
        assert.ok(found.includes("R6 target beta lives in modules/b/Ipc.qml (b) but a declares it"));
        assert.ok(found.includes("R6 a declares the target gone, which no file defines"));
        assert.ok(!found.some(v => v.includes("target alpha")));
    });

    test.it("keeps a component away from services, modules and Config", () => {
        const found = evaluate(fixture({
            "components/Dial.qml": "import qs.services\nimport qs.config\nItem { property int n: Config.values.control.x + Compositor.size }\n"
        })).violations;
        assert.ok(found.includes("R9 components/Dial.qml imports qs.services"));
        assert.ok(found.includes("R9 components/Dial.qml uses Config"));
        assert.ok(found.includes("R9 components/Dial.qml uses Compositor"));
    });

    test.it("keeps the host window from importing a feature module", () => {
        const found = evaluate(fixture({
            "packages/host.json": manifest("host", 1, {
                owns: { qml: ["modules/ShellWindow.qml"] },
                requires: { packages: ["core", "a"], optional: [] }
            }),
            "modules/ShellWindow.qml": "import qs.modules.a\nItem {}\n"
        })).violations;
        assert.ok(found.includes("R11 modules/ShellWindow.qml imports modules/a"));
    });

    test.it("holds a baseline: known violations pass, new ones fail, fixed ones are reported", () => {
        const dir = makeRepo(fixture({
            "modules/b/Panel.qml": "import qs.config\nItem { property int n: Alpha.count }\n"
        }));
        try {
            assert.strictEqual(capture(["--root", dir]).code, 1);
            assert.strictEqual(capture(["--root", dir, "--write-baseline"]).code, 0);
            const passing = capture(["--root", dir]);
            assert.strictEqual(passing.code, 0);
            assert.match(passing.out, /no new violations/);
            fs.writeFileSync(path.join(dir, "modules/b/Panel.qml"), "import qs.config\nItem { property int n: Alpha.count + Alpha.count }\n");
            assert.strictEqual(capture(["--root", dir]).code, 0);
            fs.writeFileSync(path.join(dir, "modules/a/Other.qml"), "import qs.config\nItem { property int n: Beta.count }\n");
            const failing = capture(["--root", dir]);
            assert.strictEqual(failing.code, 1);
            assert.match(failing.err, /R3 modules\/a\/Other\.qml uses Beta of b without requiring it/);
            fs.unlinkSync(path.join(dir, "modules/a/Other.qml"));
            fs.writeFileSync(path.join(dir, "modules/b/Panel.qml"), "import qs.config\nItem { property int n: Beta.count }\n");
            const fixed = capture(["--root", dir]);
            assert.strictEqual(fixed.code, 0);
            assert.match(fixed.out, /1 baseline entries are fixed/);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });

    test.it("prints the matrix and an explanation of one package", () => {
        const dir = makeRepo(fixture());
        try {
            const matrix = capture(["--root", dir, "--matrix"]);
            assert.strictEqual(matrix.code, 0);
            assert.match(matrix.out, /core/);
            const explain = capture(["--root", dir, "--explain", "a"]);
            assert.strictEqual(explain.code, 0);
            assert.match(explain.out, /needs core \(declared\)/);
            assert.match(explain.out, /modules\/a\/Panel\.qml:2/);
            assert.strictEqual(capture(["--root", dir, "--explain", "nothing"]).code, 2);
        } finally {
            fs.rmSync(dir, { recursive: true, force: true });
        }
    });
});

test.describe("the repository", () => {
    test.it("has no module boundary violation beyond modules.baseline.json", () => {
        const result = capture(["--root", ROOT]);
        assert.strictEqual(result.code, 0, `${result.err}\n${result.out}`);
    });

    test.it("keeps services free of imports from modules", () => {
        const offenders = [];
        const walk = dir => {
            for (const entry of fs.readdirSync(path.join(ROOT, dir), { withFileTypes: true })) {
                const child = `${dir}/${entry.name}`;
                if (entry.isDirectory())
                    walk(child);
                else if (/\.(qml|js)$/.test(entry.name) && /^\s*\.?import\s+"[^"]*modules\//m.test(fs.readFileSync(path.join(ROOT, child), "utf8")))
                    offenders.push(child);
            }
        };
        walk("services");
        assert.deepStrictEqual(offenders, []);
    });

    test.it("owns every file, keeps components pure and keeps manifests valid, with nothing baselined", () => {
        const { violations } = check.evaluate(check.scan(ROOT));
        assert.deepStrictEqual(violations.filter(v => /^R(1|8|9|12) /.test(v)), []);
    });

    test.it("lists every package once and draws the matrix and explanations", () => {
        const listed = capture(["--root", ROOT, "--list"]).out.split("\n");
        assert.strictEqual(new Set(listed).size, listed.length);
        assert.ok(listed.includes("core") && listed.includes("launcher") && listed.includes("host"));
        assert.match(capture(["--root", ROOT, "--matrix"]).out, /rows depend on columns/);
        assert.match(capture(["--root", ROOT, "--explain", "lock"]).out, /needs media/);
    });
});
