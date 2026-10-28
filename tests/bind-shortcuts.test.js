const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const { spawn, spawnSync } = require("node:child_process");
const { ROOT, CLI, cleanup, directory, stubs } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const src = fs.readFileSync(path.join(ROOT, "modules/ipc/bind-shortcuts.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Shortcuts = new Function(src + "\nreturn { shortcutFor, names, callsFor };")();

const LUA = ["lua5.5", "lua5.4", "lua", "luajit"].find(name => spawnSync(name, ["-e", "os.exit(0)"]).status === 0);
const skip = LUA ? false : "no lua interpreter";

const PANELS = ["launcher", "session", "clipboard", "media", "calculator", "quickcontrols", "keyboard", "settings", "notifications", "island", "hotkeys", "files", "wallpaper", "audio", "network", "bluetooth", "battery", "calendar", "clock", "update", "notch", "picker", "penmap", "tray_app"];

function everyId() {
    const ids = [];
    for (const line of fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8").split("\n")) {
        if (!line || line.startsWith("#"))
            continue;
        const id = line.split("\t")[0];
        if (id.includes("*"))
            ids.push(...PANELS.map(name => id.replace("*", name)));
        else
            ids.push(id);
    }
    return [...new Set(ids)];
}

function run(file, args, env) {
    return new Promise(resolve => {
        const child = spawn(file, args, { env, cwd: ROOT });
        let out = "";
        child.stdout.on("data", d => (out += d));
        child.on("close", code => resolve({ code, out }));
    });
}

async function inBatches(items, work, size = 16) {
    const results = [];
    for (let i = 0; i < items.length; i += size)
        results.push(...(await Promise.all(items.slice(i, i + size).map(work))));
    return results;
}

function luaPresses(ids, withLayers, realCli = false) {
    const dir = directory("lua");
    const root = path.join(dir, "checkout");
    for (const part of ["lua", "api", "cli"])
        fs.mkdirSync(path.join(root, part), { recursive: true });
    fs.copyFileSync(path.join(ROOT, "lua/banditshell.lua"), path.join(root, "lua/banditshell.lua"));
    fs.copyFileSync(path.join(ROOT, "api/actions.tsv"), path.join(root, "api/actions.tsv"));
    if (realCli)
        fs.symlinkSync(CLI, path.join(root, "cli/banditshell"));
    else
        fs.writeFileSync(path.join(root, "cli/banditshell"), "#!/bin/sh\nprintf '%s\\n' \"$@\"\n", { mode: 0o755 });
    const scenario = path.join(dir, "scenario.lua");
    fs.writeFileSync(scenario, `
        local out = {}
        hl.dsp.global = function(name) return { name = name } end
        hl.dispatch = function(d) out[#out + 1] = "global " .. d.name end
        hl.get_layers = function() return ${withLayers ? '{ { namespace = "banditshell" } }' : "{}"} end
        hl.exec_cmd = function(command) out[#out + 1] = command end
        bs = load_api()
        for _, id in ipairs({ ${ids.map(id => JSON.stringify(id)).join(", ")} }) do
            bs.run(id)
            bs.run(id, "first arg", "it's")
        end
        return out
    `);
    const result = spawnSync(LUA, [path.join(ROOT, "tests/lua/harness.lua"), scenario], {
        encoding: "utf8",
        env: { PATH: process.env.PATH, HOME: dir, BS_ROOT: root }
    });
    assert.strictEqual(result.status, 0, result.stderr);
    const parsed = JSON.parse(result.stdout);
    assert.strictEqual(parsed.ok, true, parsed.error);
    assert.deepStrictEqual(parsed.notifications, []);
    return parsed.result;
}

function sandbox() {
    const stub = stubs();
    fs.writeFileSync(path.join(stub.dir, "awk"), '#!/bin/sh\ncase "$*" in *want=*) echo "table lookup" >>"$STUB_LOG" ;; esac\nexec /usr/bin/awk "$@"\n', { mode: 0o755 });
    const home = directory("home");
    return {
        log: stub.log,
        env: { PATH: `${stub.dir}:/usr/bin:/bin`, HOME: home, LANG: "C.UTF-8", XDG_RUNTIME_DIR: path.join(home, "run"), STUB_LOG: stub.log, NO_COLOR: "1", BANDITSHELL_DRY: "1" }
    };
}

async function observe(file, args) {
    const box = sandbox();
    const ran = await run(file, args, box.env);
    const same = text => text.split(box.env.HOME).join("~").replace(/\d{4}-\d\d-\d\d-\d{6}/g, "<time>");
    const calls = fs.readFileSync(box.log, "utf8").split("\n").filter(Boolean).map(same);
    return { code: ran.code, out: same(ran.out), calls: calls.filter(c => c !== "table lookup"), lookups: calls.filter(c => c === "table lookup").length };
}

test("every action, pressed through the Lua module, does what the plain action route does without the table lookup", { skip }, async () => {
    const ids = everyId();
    const presses = luaPresses(ids, false, true);
    assert.strictEqual(presses.length, ids.length * 2);
    const hinted = await inBatches(presses, command => observe("sh", ["-c", command]));
    const plain = await inBatches(ids.flatMap(id => [[id], [id, "first arg", "it's"]]), words => observe("bash", [CLI, "action", ...words]));
    ids.forEach((id, i) => {
        for (const k of [i * 2, i * 2 + 1]) {
            assert.deepStrictEqual({ code: hinted[k].code, out: hinted[k].out, calls: hinted[k].calls }, { code: plain[k].code, out: plain[k].out, calls: plain[k].calls }, id);
            assert.strictEqual(hinted[k].lookups, plain[k].lookups - 1, id);
        }
    });
});

test("a row hint the table no longer has falls back to the lookup", async () => {
    for (const row of ["panel.*.toggle\tstable\t1\tpanel $1 togle", "panel.*.toggle\tdeprecated=x\t1\tpanel $1 toggle", "panel.files.toggle\tstable\t1\tpanel files toggle"]) {
        const box = sandbox();
        const ran = await run("bash", [CLI, "action", "panel.files.toggle"], { ...box.env, BANDITSHELL_ROW: row });
        assert.strictEqual(ran.out, "ipc files toggle \n", row);
        assert.ok(fs.readFileSync(box.log, "utf8").includes("table lookup"), row);
    }
});

test("a hint whose id another row of the table now also matches falls back to the lookup", async () => {
    const table = path.join(directory("table"), "actions.tsv");
    const rows = fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8").split("\n");
    rows.splice(2, 0, "panel.files.*\tstable\t1\tpanel files $1 --newer\tA closer row");
    fs.writeFileSync(table, rows.join("\n"));
    const box = sandbox();
    const ran = await run("bash", [CLI, "action", "panel.files.toggle"], { ...box.env, BANDITSHELL_API_TABLE: table, BANDITSHELL_ROW: "panel.*.toggle\tstable\t1\tpanel $1 toggle" });
    const plain = await run("bash", [CLI, "action", "panel.files.toggle"], { ...sandbox().env, BANDITSHELL_API_TABLE: table });
    assert.strictEqual(ran.out, plain.out);
    assert.ok(fs.readFileSync(box.log, "utf8").includes("table lookup"));
});

test("every panel the CLI knows is served by a shortcut, except settings", () => {
    const surfaces = /^SURFACES=\(([^)]*)\)/m.exec(fs.readFileSync(CLI, "utf8"))[1].split(/\s+/).filter(Boolean);
    assert.ok(surfaces.length > 10);
    assert.deepStrictEqual(surfaces.filter(name => !Shortcuts.shortcutFor(`panel.${name}.toggle`)), ["settings"]);
});

test("Lua takes the global shortcut for exactly the ids the shell registers, and only bare", { skip }, () => {
    const ids = everyId();
    const presses = luaPresses(ids, true);
    ids.forEach((id, i) => {
        const name = Shortcuts.shortcutFor(id);
        if (name)
            assert.strictEqual(presses[i * 2], `global banditshell:${name}`, id);
        else
            assert.doesNotMatch(presses[i * 2], /^global /, id);
        assert.doesNotMatch(presses[i * 2 + 1], /^global /, id);
        if (name)
            assert.ok(Shortcuts.names().includes(name), name);
    });
    for (const name of Shortcuts.names())
        assert.ok(ids.some(id => Shortcuts.shortcutFor(id) === name), name);
});

test("a shortcut makes the same shell calls, in the same order, as the CLI makes for its action", async () => {
    const ids = everyId().filter(id => Shortcuts.shortcutFor(id));
    assert.ok(ids.length > 60);
    const calls = await inBatches(ids, async id => {
        const stub = stubs();
        fs.writeFileSync(path.join(stub.dir, "qs"), `#!/bin/sh
case "$1" in
list) printf 'Instance a:\\n  Process ID: %s\\n  Config path: %s/shell.qml\\n' "$$" "${ROOT}" ;;
ipc) shift; while [ "$1" != call ]; do shift; done; shift; printf '%s\\n' "$*" >>"$STUB_LOG"; echo ok ;;
esac
`, { mode: 0o755 });
        const home = directory("home");
        await run("bash", [CLI, "action", id], { PATH: `${stub.dir}:/usr/bin:/bin`, HOME: home, XDG_RUNTIME_DIR: path.join(home, "run"), STUB_LOG: stub.log, NO_COLOR: "1" });
        return fs.readFileSync(stub.log, "utf8").split("\n").filter(Boolean);
    });
    ids.forEach((id, i) => {
        const expected = Shortcuts.callsFor(Shortcuts.shortcutFor(id)).map(call => call.join(" "));
        assert.deepStrictEqual(calls[i], expected, id);
    });
});
