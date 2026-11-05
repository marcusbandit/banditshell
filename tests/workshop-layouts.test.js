const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const SH = "/bin/sh";

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Saved = lib("services/workshop-layouts.js", ["nameTaken", "isRename", "renamedInUse", "placed", "without", "removeCommand", "writeCommand", "outcome"]);
const Model = lib("services/layout-model.js", ["normalise", "stage"]);
const Lua = lib("services/layout-lua.js", ["generate", "loader", "failedNames"]);

const LUA = ["lua", "lua5.4"].find(bin => spawnSync(bin, ["-v"]).status === 0);

function withSandbox(body) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "workshop-layouts-"));
    try {
        const folder = path.join(dir, "layouts");
        fs.mkdirSync(folder);
        body(dir, folder);
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

function fill(folder, names) {
    for (const name of names)
        fs.writeFileSync(path.join(folder, `${name}.lua`), name);
}

function run(command, env) {
    return spawnSync(SH, command.slice(1), { encoding: "utf8", env: env || process.env });
}

function binWith(dir, names) {
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin);
    for (const name of names) {
        const found = (process.env.PATH || "").split(path.delimiter).map(where => path.join(where, name)).find(file => fs.existsSync(file));
        fs.symlinkSync(found, path.join(bin, name));
    }
    return bin;
}

function stubHyprctl(dir, body) {
    const bin = binWith(dir, ["mkdir", "mv"]);
    fs.writeFileSync(path.join(bin, "hyprctl"), `#!/bin/sh\n${body}\n`, { mode: 0o755 });
    return bin;
}

function layoutsNamed(...names) {
    return names.map(name => Model.normalise({ name }));
}

test.describe("layout names on disk", () => {
    test.it("turns spaces, slashes, dots and accents into dashes", () => {
        assert.strictEqual(Model.normalise({ name: "stage/drawn.v2" }).name, "stage-drawn-v2");
        assert.strictEqual(Model.normalise({ name: "café 2" }).name, "caf-2");
        assert.strictEqual(Model.normalise({ name: "Night Mode_Wide" }).name, "night-mode_wide");
    });

    test.it("drops leading digits and symbols so a name starts with a letter", () => {
        assert.strictEqual(Model.normalise({ name: "123abc" }).name, "abc");
        assert.strictEqual(Model.normalise({ name: "--  -x" }).name, "x");
    });

    test.it("gives an empty name or a name with no letters the default name", () => {
        assert.strictEqual(Model.normalise({ name: "" }).name, "drawn");
        assert.strictEqual(Model.normalise({ name: ".." }).name, "drawn");
        assert.strictEqual(Model.normalise({ name: "日本語" }).name, "drawn");
    });

    test.it("writes a layout named like a path inside its own folder", () => withSandbox((dir, folder) => {
        const name = Model.normalise({ name: "../../escape" }).name;
        assert.doesNotMatch(name, /[./]/);
        const written = run(Saved.writeCommand(folder, [{ name, text: "x" }], ""));
        assert.strictEqual(written.status, 0, written.stderr);
        assert.deepStrictEqual(fs.readdirSync(folder), ["escape.lua"]);
        assert.deepStrictEqual(fs.readdirSync(dir), ["layouts"]);
    }));
});

test.describe("layout name clashes", () => {
    test.it("treats a new name that cleans to a saved name as taken", () => {
        const draft = Model.normalise({ name: "my layout!" });
        assert.strictEqual(Saved.nameTaken(layoutsNamed("My Layout"), draft.name, ""), true);
    });

    test.it("treats two names that agree up to the 40 character cut as taken", () => {
        const stem = "a".repeat(40);
        const draft = Model.normalise({ name: `${stem}-two` });
        assert.strictEqual(Saved.nameTaken(layoutsNamed(`${stem}-one`), draft.name, ""), true);
    });

    test.it("lets a layout keep its own name when it is saved again", () => {
        assert.strictEqual(Saved.nameTaken(layoutsNamed("wide"), "wide", "wide"), false);
    });

    test.it("refuses a rename onto the name of another saved layout", () => {
        const saved = layoutsNamed("wide", "tall");
        assert.strictEqual(Saved.nameTaken(saved, "wide", "tall"), true);
        assert.strictEqual(Saved.nameTaken(saved, "narrow", "tall"), false);
    });
});

test.describe("saving and removing in the list", () => {
    test.it("adds a new layout at the end", () => {
        const next = Saved.placed(layoutsNamed("a", "b"), Model.normalise({ name: "c" }), "");
        assert.deepStrictEqual(next.map(model => model.name), ["a", "b", "c"]);
    });

    test.it("keeps a layout's place when it is saved or renamed", () => {
        const list = layoutsNamed("a", "b", "c");
        const saved = Saved.placed(list, Model.normalise({ name: "b", messages: { step: 2 } }), "b");
        assert.deepStrictEqual(saved.map(model => model.name), ["a", "b", "c"]);
        assert.strictEqual(saved[1].messages.step, 2);
        const renamed = Saved.placed(list, Model.normalise({ name: "x" }), "b");
        assert.deepStrictEqual(renamed.map(model => model.name), ["a", "x", "c"]);
    });

    test.it("counts a save as a rename only when the old name is set and differs", () => {
        assert.strictEqual(Saved.isRename("", "wide"), false);
        assert.strictEqual(Saved.isRename("wide", "wide"), false);
        assert.strictEqual(Saved.isRename("wide", "tall"), true);
    });

    test.it("reselects a renamed layout only when its old name was the one in use", () => {
        assert.strictEqual(Saved.renamedInUse("wide", "tall", "lua:wide"), true);
        assert.strictEqual(Saved.renamedInUse("wide", "tall", "dwindle"), false);
        assert.strictEqual(Saved.renamedInUse("wide", "wide", "lua:wide"), false);
    });

    test.it("removes only the named layout from the list", () => {
        const left = Saved.without(layoutsNamed("a", "a-b", "b"), "a");
        assert.deepStrictEqual(left.map(model => model.name), ["a-b", "b"]);
    });
});

test.describe("removing a layout's file", () => {
    test.it("deletes only the named layout's file", () => withSandbox((dir, folder) => {
        fill(folder, ["a", "a-b", "b", "ba"]);
        const removed = run(Saved.removeCommand(folder, ["b"]));
        assert.strictEqual(removed.status, 0, removed.stderr);
        assert.deepStrictEqual(fs.readdirSync(folder).sort(), ["a-b.lua", "a.lua", "ba.lua"]);
    }));

    test.it("never deletes a file outside the layouts folder, even when given a path", () => withSandbox((dir, folder) => {
        fill(folder, ["a"]);
        fs.writeFileSync(path.join(dir, "outside.lua"), "keep");
        const removed = run(Saved.removeCommand(folder, ["../outside", "a"]));
        assert.strictEqual(removed.status, 0, removed.stderr);
        assert.strictEqual(fs.readFileSync(path.join(dir, "outside.lua"), "utf8"), "keep");
        assert.deepStrictEqual(fs.readdirSync(folder), []);
    }));

    test.it("never writes a name that could leave the layouts folder", () => withSandbox((dir, folder) => {
        const written = run(Saved.writeCommand(folder, [{ name: "../outside", text: "x" }, { name: "a", text: "a" }], ""));
        assert.strictEqual(written.status, 0, written.stderr);
        assert.deepStrictEqual(fs.readdirSync(folder), ["a.lua"]);
        assert.deepStrictEqual(fs.readdirSync(dir), ["layouts"]);
    }));

    test.it("succeeds and removes nothing when the layouts folder does not exist yet", () => withSandbox(dir => {
        const removed = run(Saved.removeCommand(path.join(dir, "missing"), ["a"]));
        assert.strictEqual(removed.status, 0, removed.stderr);
    }));
});

test.describe("writing a layout's file", () => {
    test.it("writes each layout's text byte for byte under its own name and leaves no part file", () => withSandbox((dir, folder) => {
        const text = 'local name = "$HOME" .. `tick`\n\'quote\' \\ end\n';
        const written = run(Saved.writeCommand(folder, [{ name: "a", text }, { name: "b", text: "b" }], ""));
        assert.strictEqual(written.status, 0, written.stderr);
        assert.strictEqual(fs.readFileSync(path.join(folder, "a.lua"), "utf8"), text);
        assert.deepStrictEqual(fs.readdirSync(folder).sort(), ["a.lua", "b.lua"]);
    }));

    test.it("creates the layouts folder on the first save", () => withSandbox(dir => {
        const folder = path.join(dir, "state", "layouts");
        const written = run(Saved.writeCommand(folder, [{ name: "a", text: "x" }], ""));
        assert.strictEqual(written.status, 0, written.stderr);
        assert.strictEqual(fs.readFileSync(path.join(folder, "a.lua"), "utf8"), "x");
    }));

    test.it("hands the loader to hyprctl eval once the files are written", () => withSandbox((dir, folder) => {
        const env = { ...process.env, PATH: `${stubHyprctl(dir, 'printf %s "$2"')}${path.delimiter}${process.env.PATH}` };
        const code = 'dofile("/x/a.lua")';
        const written = run(Saved.writeCommand(folder, [{ name: "a", text: "x" }], code), env);
        assert.strictEqual(written.status, 0, written.stderr);
        assert.strictEqual(written.stdout, code);
        assert.strictEqual(fs.readFileSync(path.join(folder, "a.lua"), "utf8"), "x");
    }));

    test.it("reports a missing hyprctl and keeps the files it wrote", () => withSandbox((dir, folder) => {
        const env = { ...process.env, PATH: binWith(dir, ["mkdir", "mv"]) };
        const written = run(Saved.writeCommand(folder, [{ name: "a", text: "x" }], "print(1)"), env);
        assert.strictEqual(written.status, 3);
        assert.strictEqual(written.stdout.trim(), "hyprctl is not installed");
        assert.strictEqual(fs.readFileSync(path.join(folder, "a.lua"), "utf8"), "x");
    }));
});

test.describe("settling a write", () => {
    const names = ["a", "b"];
    const folder = "/state/layouts";

    test.it("marks every layout ready when Hyprland answers ok", () => {
        const result = Saved.outcome({ ready: {}, names, output: "ok\n", code: 0, possible: true, folder, named: [] });
        assert.deepStrictEqual(result.ready, { a: true, b: true });
        assert.strictEqual(result.failed, false);
        assert.strictEqual(result.said, "2 layouts loaded");
    });

    test.it("names the one layout when a single layout loads", () => {
        const result = Saved.outcome({ ready: {}, names: ["a"], output: "ok", code: 0, possible: true, folder, named: [] });
        assert.strictEqual(result.said, "lua:a is loaded");
    });

    test.it("leaves only the layout whose Lua error names its file unready", () => {
        const output = `error: ${folder}/b.lua:3: unexpected symbol near 'x'`;
        const result = Saved.outcome({ ready: {}, names, output, code: 0, possible: true, folder, named: Lua.failedNames(output, names, folder) });
        assert.deepStrictEqual(result.ready, { a: true, b: false });
        assert.strictEqual(result.failed, true);
        assert.strictEqual(result.said, `${folder}/b.lua:3: unexpected symbol near 'x'`);
    });

    test.it("marks every layout in the write unready when a Lua error names none of them", () => {
        const output = "error: something in the loader went wrong";
        const result = Saved.outcome({ ready: {}, names, output, code: 0, possible: true, folder, named: Lua.failedNames(output, names, folder) });
        assert.deepStrictEqual(result.ready, { a: false, b: false });
    });

    test.it("keeps the readiness of layouts the write did not touch", () => {
        const result = Saved.outcome({ ready: { old: true, a: false }, names: ["a"], output: "ok", code: 0, possible: true, folder, named: [] });
        assert.deepStrictEqual(result.ready, { old: true, a: true });
    });

    test.it("marks nothing ready and reports the save when Hyprland does not run a Lua config", () => {
        const result = Saved.outcome({ ready: {}, names, output: "", code: 0, possible: false, folder, named: [] });
        assert.deepStrictEqual(result.ready, { a: false, b: false });
        assert.strictEqual(result.failed, false);
        assert.strictEqual(result.said, "saved · loading needs Hyprland with a Lua config");
    });

    test.it("reports a missing hyprctl as the trouble, with nothing ready", () => {
        const result = Saved.outcome({ ready: {}, names, output: "hyprctl is not installed\n", code: 3, possible: true, folder, named: [] });
        assert.deepStrictEqual(result.ready, { a: false, b: false });
        assert.strictEqual(result.failed, true);
        assert.strictEqual(result.said, "hyprctl is not installed");
    });

    test.it("never marks a layout ready on an answer that is neither ok nor an error", () => {
        const unclear = Saved.outcome({ ready: {}, names, output: "Unknown option", code: 0, possible: true, folder, named: [] });
        assert.deepStrictEqual(unclear.ready, { a: false, b: false });
        const silent = Saved.outcome({ ready: {}, names, output: "", code: 0, possible: true, folder, named: [] });
        assert.strictEqual(silent.said, `could not write ${folder}`);
    });
});

test.describe("settling against real Lua", { skip: !LUA && "no lua interpreter" }, () => {
    test.it("marks only the file that real Lua reports as broken unready", () => withSandbox((dir, folder) => {
        const broken = path.join(folder, "broken.lua");
        const good = path.join(folder, "stage-drawn.lua");
        fs.writeFileSync(broken, "local x = (");
        fs.writeFileSync(good, Lua.generate(Model.stage()));
        const runner = path.join(dir, "run.lua");
        fs.writeFileSync(runner, `hl = { layout = { register = function() end } }\nlocal ok, problem = pcall(load(${JSON.stringify(Lua.loader([broken, good]))}))\nio.write(ok and "ok" or problem)\n`);
        const loaded = spawnSync(LUA, [runner], { encoding: "utf8" });
        assert.strictEqual(loaded.status, 0, loaded.stderr);
        const names = ["broken", "stage-drawn"];
        const output = `error: ${loaded.stdout}`;
        const result = Saved.outcome({ ready: {}, names, output, code: 0, possible: true, folder, named: Lua.failedNames(output, names, folder) });
        assert.deepStrictEqual(result.ready, { broken: false, "stage-drawn": true });
    }));
});
