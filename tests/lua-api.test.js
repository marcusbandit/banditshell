const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const HARNESS = path.join(ROOT, "tests/lua/harness.lua");
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-lua-"));
test.after(() => fs.rmSync(TMP, { recursive: true, force: true }));

function findLua() {
    for (const name of ["lua5.5", "lua5.4", "lua", "luajit"]) {
        const probe = spawnSync(name, ["-e", "os.exit(0)"], { encoding: "utf8" });
        if (probe.status === 0)
            return name;
    }
    return null;
}

const LUA = findLua();
const skip = LUA ? false : "no lua interpreter";
let counter = 0;

function fresh(name) {
    const dir = path.join(TMP, `${name}-${counter++}`);
    fs.mkdirSync(dir, { recursive: true });
    return dir;
}

function checkout(options = {}) {
    const dir = fresh("checkout");
    fs.mkdirSync(path.join(dir, "lua"));
    fs.mkdirSync(path.join(dir, "api"));
    fs.mkdirSync(path.join(dir, "cli"));
    fs.copyFileSync(path.join(ROOT, "lua/banditshell.lua"), path.join(dir, "lua/banditshell.lua"));
    if (options.table !== null)
        fs.writeFileSync(path.join(dir, "api/actions.tsv"), options.table ?? fs.readFileSync(path.join(ROOT, "api/actions.tsv")));
    fs.writeFileSync(path.join(dir, "cli/banditshell"), '#!/bin/sh\nprintf \'%s\\n\' "$@" >"$OUT"\n', { mode: 0o755 });
    return dir;
}

function table(...rows) {
    return ["# api 1", ...rows.map(r => r.join("\t"))].join("\n") + "\n";
}

function run(root, source, options = {}) {
    const home = options.home ?? fresh("home");
    const file = path.join(fresh("scenario"), "scenario.lua");
    fs.writeFileSync(file, source);
    const env = {
        PATH: process.env.PATH,
        HOME: home,
        BS_ROOT: root,
        BS_LOAD: options.via ?? "module",
        ...(options.env ?? {})
    };
    const result = spawnSync(LUA, [HARNESS, file], { env, encoding: "utf8" });
    assert.strictEqual(result.status, 0, result.stderr);
    return JSON.parse(result.stdout);
}

function execute(command, home) {
    const out = path.join(fresh("out"), "argv");
    const result = spawnSync("sh", ["-c", command], {
        env: { PATH: process.env.PATH, HOME: home, OUT: out, XDG_STATE_HOME: path.join(home, ".local/state") },
        encoding: "utf8"
    });
    assert.strictEqual(result.status, 0, result.stderr);
    return fs.readFileSync(out, "utf8").split("\n").slice(0, -1);
}

test("a bound id runs the checkout's CLI with the action verb and nothing else", { skip }, () => {
    const home = fresh("home");
    const root = checkout();
    const r = run(root, `
        bs = load_api()
        hl.bind("SUPER + SPACE", bs.launcher.toggle)
        hl.bind("SUPER + V", bs.panel.clipboard.toggle)
        hl.bind("SUPER + ESCAPE", bs.panel.close)
        press(1) press(2) press(3)
    `, { home });
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.binds.map(b => b.kind), ["function", "function", "function"]);
    assert.deepStrictEqual(r.exec.map(c => execute(c, home)), [
        ["action", "launcher.toggle"],
        ["action", "panel.clipboard.toggle"],
        ["action", "panel.close"]
    ]);
    assert.deepStrictEqual(r.notifications, []);
});

test("panel and menu binds dispatch the shell's global shortcut while the shell is up, everything else runs the CLI", { skip }, () => {
    const home = fresh("home");
    const r = run(checkout(), `
        local dispatched = {}
        hl.dsp.global = function(name) return { dispatcher = "global", name = name } end
        hl.dispatch = function(d) dispatched[#dispatched + 1] = d.name end
        hl.get_layers = function(filter) return filter.namespace == "banditshell" and { { namespace = "banditshell" } } or {} end
        bs = load_api()
        hl.bind("SUPER + SPACE", bs.launcher.toggle)
        hl.bind("SUPER + V", bs.panel.clipboard.toggle)
        hl.bind("SUPER + U", bs.panel.update.open)
        bs.bind("SUPER + ESCAPE", "panel.close")
        hl.bind("SUPER + I", bs.panel.settings.toggle)
        hl.bind("SUPER + D", bs.panel.files.toggle("DP-1"))
        hl.bind("SUPER + B", bs.screen.border.toggle)
        press(1) press(2) press(3) press(4) press(5) press(6) press(7)
        hl.notification.create({ text = "dispatched " .. table.concat(dispatched, ",") })
    `, { home });
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.notifications, ["dispatched banditshell:launcher,banditshell:panel.clipboard.toggle,banditshell:panel.update.open,banditshell:panel.close"]);
    assert.deepStrictEqual(r.exec.map(c => execute(c, home)), [
        ["action", "panel.settings.toggle"],
        ["action", "panel.files.toggle", "DP-1"],
        ["action", "screen.border.toggle"]
    ]);
});

test("with no shell surface on screen a panel bind runs the CLI, so a stopped shell still says so", { skip }, () => {
    const home = fresh("home");
    const r = run(checkout(), `
        local dispatched = 0
        hl.dsp.global = function(name) return { dispatcher = "global", name = name } end
        hl.dispatch = function(d) dispatched = dispatched + 1 end
        hl.get_layers = function() return {} end
        bs = load_api()
        hl.bind("SUPER + V", bs.panel.clipboard.toggle)
        press(1)
        return { dispatched = dispatched }
    `, { home });
    assert.strictEqual(r.ok, true, r.error);
    assert.strictEqual(r.result.dispatched, 0);
    assert.deepStrictEqual(r.exec.map(c => execute(c, home)), [["action", "panel.clipboard.toggle"]]);
});

test("a wildcard row and an exact row under one prefix both resolve", { skip }, () => {
    const home = fresh("home");
    const r = run(checkout(), `
        bs = load_api()
        hl.bind("A", bs.panel.settings.toggle)
        hl.bind("B", bs.panel.settings.page("wifi"))
        hl.bind("C", bs.panel.files.open)
        press(1) press(2) press(3)
    `, { home });
    assert.deepStrictEqual(r.exec.map(c => execute(c, home)), [
        ["action", "panel.settings.toggle"],
        ["action", "panel.settings.page", "wifi"],
        ["action", "panel.files.open"]
    ]);
    assert.deepStrictEqual(r.notifications, []);
});

test("arguments are quoted so no byte of them reaches the shell as syntax", { skip }, () => {
    const home = fresh("home");
    const nasty = ["/tmp/it's here/$(touch pwned).png", 'a "b" `c`', "x;y&z|w", "line\none", "-n", "--flag"];
    const r = run(checkout(), `
        bs = load_api()
        hl.bind("A", bs.wallpaper.set(${nasty.map(s => `[==[${s}]==]`).join(", ")}))
        hl.bind("B", bs.action("tablet.on", "compositor", 7))
        press(1) press(2)
    `, { home });
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(execute(r.exec[0], home), ["action", "wallpaper.set", ...nasty.flatMap(s => s.split("\n"))]);
    assert.deepStrictEqual(execute(r.exec[1], home), ["action", "tablet.on", "compositor", "7"]);
    assert.ok(!fs.existsSync(path.join(home, "pwned")));
});

test("bs.action and bs.run take an id and arguments, a table spec or a bare function", { skip }, () => {
    const home = fresh("home");
    const r = run(checkout(), `
        bs = load_api()
        hl.bind("A", bs.action("wallpaper.next", "all"))
        hl.bind("B", bs.action({ "clock.timer.start", "10m" }))
        hl.bind("C", function() bs.run("screen.border.toggle") end)
        press(1) press(2) press(3)
    `, { home });
    assert.deepStrictEqual(r.exec.map(c => execute(c, home)), [
        ["action", "wallpaper.next", "all"],
        ["action", "clock.timer.start", "10m"],
        ["action", "screen.border.toggle"]
    ]);
});

test("a name that does not exist never raises and tells the owner once when binding and once when pressed", { skip }, () => {
    const r = run(checkout(), `
        bs = load_api()
        hl.bind("A", bs.volume.up)
        hl.bind("B", bs.volume.up)
        hl.bind("C", bs.panel.clipboard)
        hl.bind("D", bs.screen.sidebar.togle)
        hl.bind("E", bs.action("nothing.here"))
        hl.bind("F", bs.a.b.c.d.e)
        bs.run("also.missing")
        press(1) press(1) press(2) press(3) press(4) press(5) press(6)
        local called = pcall(function() bs.volume.up() end)
        return { called = called }
    `);
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.press_errors, []);
    assert.deepStrictEqual(r.exec, []);
    assert.deepStrictEqual(r.binds.map(b => b.kind), Array(6).fill("function"));
    assert.strictEqual(r.result.called, true);
    const texts = r.notifications;
    for (const text of new Set(texts))
        assert.ok(texts.filter(t => t === text).length <= 2, text);
    for (const name of ["bs.volume.up", "bs.panel.clipboard", "bs.screen.sidebar.togle", "bs.nothing.here", "bs.a.b.c.d.e", "bs.also.missing"])
        assert.ok(texts.some(t => t.includes(name)), name);
});

test("a missing action table makes every name a notice, not an error", { skip }, () => {
    const r = run(checkout({ table: null }), `
        bs = load_api()
        hl.bind("A", bs.launcher.toggle)
        bs.bind("B", "panel.close")
        press(1) press(2)
    `);
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.exec, []);
    assert.ok(r.notifications.every(t => t.includes("action table is missing")));
    assert.strictEqual(r.binds.length, 2);
});

test("deprecated and removed rows still run, and say so once", { skip }, () => {
    const home = fresh("home");
    const root = checkout({
        table: table(
            ["launcher.show", "deprecated=launcher.toggle", "1", "panel launcher toggle", "Old name"],
            ["launcher.hide", "removed=launcher.close", "1", "panel launcher close", "Older name"],
            ["launcher.toggle", "stable", "1", "panel launcher toggle", "New name"]
        )
    });
    const r = run(root, `
        bs = load_api()
        hl.bind("A", bs.launcher.show)
        hl.bind("B", bs.launcher.show)
        hl.bind("C", bs.launcher.hide)
        press(1) press(3)
    `, { home });
    assert.deepStrictEqual(r.exec.map(c => execute(c, home)), [["action", "launcher.show"], ["action", "launcher.hide"]]);
    assert.strictEqual(r.notifications.length, 2);
    assert.match(r.notifications[0], /bs\.launcher\.show is deprecated, use bs\.launcher\.toggle/);
    assert.match(r.notifications[1], /bs\.launcher\.hide is gone, use bs\.launcher\.close/);
});

test("bs.bind fills the description from the table and respects one the user gave", { skip }, () => {
    const r = run(checkout(), `
        bs = load_api()
        bs.bind("A", "launcher.toggle")
        bs.bind("B", bs.panel.close, { locked = true })
        bs.bind("C", "launcher.toggle", { description = "mine" })
        bs.bind("D", { "clock.timer.start", "10m" })
        bs.bind("E", function() end)
        bs.bind("F", bs.nonsense.name)
        return { d = bs.describe(bs.panel.close), e = bs.describe("nonsense"), f = bs.describe("panel.clipboard.toggle") }
    `);
    assert.strictEqual(r.ok, true, r.error);
    const by = Object.fromEntries(r.binds.map(b => [b.keys, b]));
    assert.strictEqual(by.A.opts.description, "Open or close the launcher");
    assert.strictEqual(by.B.opts.description, "Close every panel and menu");
    assert.strictEqual(by.B.opts.locked, true);
    assert.strictEqual(by.C.opts.description, "mine");
    assert.match(by.D.opts.description, /Start a timer/);
    assert.strictEqual(by.E.opts.description, undefined);
    assert.strictEqual(by.F.kind, "function");
    assert.strictEqual(r.result.d, "Close every panel and menu");
    assert.strictEqual(r.result.e, undefined);
    assert.match(r.result.f, /Open or close a panel/);
});

test("pressing a key does no file or process work in Lua", { skip }, () => {
    const home = fresh("home");
    const r = run(checkout(), `
        bs = load_api()
        hl.bind("A", bs.launcher.toggle)
        hl.bind("B", bs.wallpaper.set("/x"))
        hl.bind("C", bs.volume.up)
        bs.bind("D", "panel.close")
        forbid_io()
        press(1) press(2) press(3) press(4)
    `, { home });
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.press_errors, []);
    assert.strictEqual(r.exec.length, 3);
});

test("the version number the module reports is the table's", { skip }, () => {
    const r = run(checkout(), `bs = load_api() return { api = bs.api, has = bs.has("panel.close"), no = bs.has("panel.nothing"), cli = bs.cli() }`);
    const header = /^# api (\d+)/.exec(fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8"))[1];
    assert.strictEqual(String(r.result.api), header);
    assert.strictEqual(r.result.has, true);
    assert.strictEqual(r.result.no, false);
    assert.ok(r.result.cli.endsWith("/cli/banditshell"));
});

test("a config that wants a newer api is told, not broken", { skip }, () => {
    const r = run(checkout(), `bs = load_api() bs.need(1) bs.need(99)`);
    assert.strictEqual(r.notifications.length, 1);
    assert.match(r.notifications[0], /api 99/);
});

test("a checkout that moved after the config loaded is found through the pointer at run time", { skip }, () => {
    const home = fresh("home");
    const old = checkout();
    const moved = checkout();
    fs.mkdirSync(path.join(home, ".local/state/banditshell"), { recursive: true });
    const r = run(old, `
        bs = load_api()
        hl.bind("A", bs.launcher.toggle)
        press(1)
    `, { home });
    fs.rmSync(path.join(old, "cli/banditshell"));
    fs.writeFileSync(path.join(home, ".local/state/banditshell/root"), moved + "\n");
    fs.writeFileSync(path.join(moved, "cli/banditshell"), '#!/bin/sh\n{ echo moved; printf \'%s\\n\' "$@"; } >"$OUT"\n', { mode: 0o755 });
    assert.deepStrictEqual(execute(r.exec[0], home), ["moved", "action", "launcher.toggle"]);
});

test("with no checkout anywhere the shim hands back a hollow object that never raises", { skip }, () => {
    const home = fresh("home");
    const shim = path.join(ROOT, "api/shim.lua");
    const r = run(path.join(home, "nowhere"), `
        bs = load_api()
        hl.bind("A", bs.launcher.toggle)
        hl.bind("B", bs.panel.clipboard.toggle)
        hl.bind("C", bs.nothing.at.all)
        bs.bind("D", "panel.close")
        bs.need(5)
        bs.run("launcher.toggle")
        press(1) press(2) press(3)
        return { api = bs.api, d = bs.describe("x"), h = bs.has("x"), cli = bs.cli() }
    `, { home, via: "shim", env: { BS_SHIM: shim } });
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.press_errors, []);
    assert.deepStrictEqual(r.exec, []);
    assert.deepStrictEqual(r.binds.map(b => b.kind), ["function", "function", "function", "function"]);
    assert.deepStrictEqual(r.result, { api: 0, h: false, cli: "banditshell" });
    assert.ok(r.notifications.length >= 1);
});

test("the shim finds the checkout through BANDITSHELL_DIR, then the pointer file", { skip }, () => {
    const home = fresh("home");
    const viaPointer = checkout();
    const viaEnv = checkout();
    fs.mkdirSync(path.join(home, ".local/state/banditshell"), { recursive: true });
    fs.writeFileSync(path.join(home, ".local/state/banditshell/root"), viaPointer + "\n");
    const shim = path.join(ROOT, "api/shim.lua");
    const scenario = `bs = load_api() return { root = bs.root, api = bs.api }`;
    const a = run(path.join(home, "unused"), scenario, { home, via: "shim", env: { BS_SHIM: shim } });
    assert.strictEqual(a.result.root, viaPointer);
    const b = run(path.join(home, "unused"), scenario, { home, via: "shim", env: { BS_SHIM: shim, BANDITSHELL_DIR: viaEnv } });
    assert.strictEqual(b.result.root, viaEnv);
    assert.strictEqual(b.result.api, 1);
});

test("the shim does not mention a single action, verb or version of the CLI", () => {
    const text = fs.readFileSync(path.join(ROOT, "api/shim.lua"), "utf8");
    assert.match(text.split("\n")[0], /^-- banditshell shim, format \d+\./);
    for (const word of ["launcher", "panel", "toggle", "wallpaper", "actions.tsv", "action "])
        assert.ok(!text.includes(word), word);
});

test("the example bind file loads clean: every bound id exists and nothing notifies", { skip }, () => {
    const example = path.join(ROOT, "docs/hyprland-binds.example.lua");
    const r = run(checkout(), `
        package.loaded["banditshell"] = load_api()
        dofile(${JSON.stringify(example)})
        for i = 1, #events.binds do
            if events.binds[i].kind == "function" then press(i) end
        end
        return { count = #events.binds }
    `);
    assert.strictEqual(r.ok, true, r.error);
    assert.deepStrictEqual(r.notifications, []);
    assert.deepStrictEqual(r.press_errors, []);
    assert.ok(r.result.count > 30);
    const rows = fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8").split("\n").filter(l => l && !l.startsWith("#")).map(l => l.split("\t")[0].split("."));
    const ids = r.exec.map(c => /exec "\$cli" action '([a-z0-9_.]+)'/.exec(c)[1]);
    assert.ok(ids.length > 30);
    for (const id of ids) {
        const parts = id.split(".");
        assert.ok(rows.some(row => row.length === parts.length && row.every((s, i) => s === "*" || s === parts[i])), id);
    }
    const described = r.binds.filter(b => b.opts && b.opts.description);
    assert.ok(described.length >= 1);
});

test("the hotkey sheet's scanner reads the example: plain binds, and only the switch pair is dynamic", () => {
    const src = fs.readFileSync(path.join(ROOT, "services/hyprland-lua.js"), "utf8");
    const scanner = new Function(src + "\nreturn { scanLua };")();
    const binds = scanner.scanLua(fs.readFileSync(path.join(ROOT, "docs/hyprland-binds.example.lua"), "utf8")).binds;
    assert.ok(binds.length > 30);
    assert.deepStrictEqual(binds.filter(b => b.dynamic).map(b => b.chord), ['"switch:on:" .. switch', '"switch:off:" .. switch']);
    assert.ok(binds.some(b => b.expr === "bs.launcher.toggle" && !b.dynamic));
});
