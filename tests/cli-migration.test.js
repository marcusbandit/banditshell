const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/cli-migration.js"), "utf8");
const Migration = new Function(src
    + "\nreturn { migrateArgs, rewriteText, RULES, PANELS };")();

function migrate(cmd) {
    const hit = Migration.migrateArgs(cmd);
    return hit ? hit.args : cmd;
}

test("lifecycle verbs need nothing", () => {
    for (const verb of ["start", "stop", "restart", "run", "log"])
        assert.strictEqual(migrate(verb), verb);
});

test("get and set were already generic-first", () => {
    assert.strictEqual(migrate("get theme"), "get theme");
    assert.strictEqual(migrate("set theme dark"), "set theme dark");
    assert.strictEqual(migrate("get edge.bare"), "get edge.bare");
    assert.strictEqual(migrate("set edge.bare true"), "set edge.bare true");
});

test("dev verbs pass through untouched", () => {
    for (const cmd of ["build", "test", "shaders", "shot x.png", "demo calendar",
        "gallery 1280x800", "lockpreview", "settingspreview 400x800 lock",
        "completions install", "completions status"])
        assert.strictEqual(migrate(cmd), cmd);
});

test("every panel's surface verbs move in front of panel", () => {
    for (const [old, now] of [
        ["launcher toggle", "toggle panel launcher"],
        ["launcher open", "open panel launcher"],
        ["launcher close", "close panel launcher"],
        ["clipboard toggle", "toggle panel clipboard"],
        ["session toggle", "toggle panel session"],
        ["media status", "status panel media"],
        ["keyboard toggle", "toggle panel keyboard"],
        ["notifications toggle", "toggle panel notifications"],
        ["notifications close", "close panel notifications"],
        ["notch status DP-1", "status panel notch DP-1"],
        ["hotkeys open DP-1", "open panel hotkeys DP-1"],
        ["settings status", "status panel settings"],
        ["files toggle", "toggle panel files"],
        ["files open ~/docs", "open panel files ~/docs"],
        ["files close", "close panel files"]
    ])
        assert.strictEqual(migrate(old), now, old);
});

test("the wallpaper picker loses the plural, keeps the panel", () => {
    assert.strictEqual(migrate("wallpapers toggle"), "toggle panel wallpaper");
    assert.strictEqual(migrate("wallpapers toggle DP-1"), "toggle panel wallpaper DP-1");
    assert.strictEqual(migrate("wallpapers open"), "open panel wallpaper");
    assert.strictEqual(migrate("wallpapers status"), "status panel wallpaper");
});

test("menu's key becomes the panel instance", () => {
    assert.strictEqual(migrate("menu list"), "list menu");
    assert.strictEqual(migrate("menu open calendar"), "open panel calendar");
    assert.strictEqual(migrate("menu open calendar DP-1"), "open panel calendar DP-1");
    assert.strictEqual(migrate("menu toggle clock"), "toggle panel clock");
    assert.strictEqual(migrate("menu close"), "close panel menu");
    assert.strictEqual(migrate("menu current"), "dispatch menu current");
    assert.strictEqual(migrate("menu hover"), "dispatch menu hover");
});

test("the sugar verbs become the panel toggles they always were", () => {
    assert.strictEqual(migrate("calendar"), "toggle panel calendar");
    assert.strictEqual(migrate("clock"), "toggle panel clock");
});

test("bespoke panel verbs go through dispatch", () => {
    for (const [old, now] of [
        ["launcher run firefox", "dispatch launcher run firefox"],
        ["launcher scrub 0.5", "dispatch launcher scrub 0.5"],
        ["clipboard use 3", "dispatch clipboard use 3"],
        ["clipboard pin 3", "dispatch clipboard pin 3"],
        ["clipboard remove 3", "dispatch clipboard remove 3"],
        ["clipboard clear", "dispatch clipboard clear"],
        ["clipboard list", "list clipboard"],
        ["calculator app", "dispatch calculator app"],
        ["calculator panel", "dispatch calculator panel"],
        ["calculator answer \"2+3*4\"", "dispatch calculator answer \"2+3*4\""],
        ["keyboard page letters", "dispatch keyboard page letters"],
        ["keyboard dock", "dispatch keyboard dock"],
        ["keyboard float", "dispatch keyboard float"],
        ["settings page general", "dispatch settings page general"],
        ["settings float", "dispatch settings float"]
    ])
        assert.strictEqual(migrate(old), now, old);
});

test("the noun aliases still land on the same panel", () => {
    assert.strictEqual(migrate("calc toggle"), "toggle panel calculator");
    assert.strictEqual(migrate("osk toggle"), "toggle panel keyboard");
    assert.strictEqual(migrate("pen open"), "open panel penmap");
});

test("border", () => {
    assert.strictEqual(migrate("border toggle"), "toggle border");
    assert.strictEqual(migrate("border on"), "set border on");
    assert.strictEqual(migrate("border off"), "set border off");
    assert.strictEqual(migrate("border status"), "status border");
});

test("wallpaper state, value and actions", () => {
    assert.strictEqual(migrate("wallpaper toggle"), "toggle wallpaper");
    assert.strictEqual(migrate("wallpaper on"), "set wallpaper on");
    assert.strictEqual(migrate("wallpaper off"), "set wallpaper off");
    assert.strictEqual(migrate("wallpaper status"), "status wallpaper");
    assert.strictEqual(migrate("wallpaper list DP-1"), "list wallpaper DP-1");
    assert.strictEqual(migrate("wallpaper set ~/pics/x.jpg all"), "set wallpaper ~/pics/x.jpg all");
    assert.strictEqual(migrate("wallpaper next all"), "dispatch wallpaper next all");
    assert.strictEqual(migrate("wallpaper prev"), "dispatch wallpaper prev");
    assert.strictEqual(migrate("wallpaper clear"), "dispatch wallpaper clear");
    assert.strictEqual(migrate("wallpaper palette"), "dispatch wallpaper palette");
});

test("volume: set is absolute, relative, and mute is the boolean part", () => {
    assert.strictEqual(migrate("volume set 50"), "set volume 50");
    assert.strictEqual(migrate("volume set .5"), "set volume .5");
    assert.strictEqual(migrate("volume up 5"), "set volume +5");
    assert.strictEqual(migrate("volume down 3"), "set volume -3");
    assert.strictEqual(migrate("volume up"), "set volume +");
    assert.strictEqual(migrate("volume mute"), "toggle volume mute");
    assert.strictEqual(migrate("volume mute on"), "set volume mute on");
    assert.strictEqual(migrate("volume mute off"), "set volume mute off");
    assert.strictEqual(migrate("volume status"), "status volume");
});

test("output", () => {
    assert.strictEqual(migrate("output toggle"), "toggle output");
    assert.strictEqual(migrate("output speakers"), "set output speakers");
    assert.strictEqual(migrate("output headphones"), "set output headphones");
    assert.strictEqual(migrate("output assign speakers alsa_out"), "set output speakers alsa_out");
    assert.strictEqual(migrate("output list"), "list output");
    assert.strictEqual(migrate("output status"), "status output");
});

test("tablet: hinge, lid, and the probe", () => {
    assert.strictEqual(migrate("tablet on"), "set tablet on");
    assert.strictEqual(migrate("tablet off compositor"), "set tablet off compositor");
    assert.strictEqual(migrate("tablet toggle"), "toggle tablet");
    assert.strictEqual(migrate("tablet toggle compositor"), "toggle tablet compositor");
    assert.strictEqual(migrate("tablet status"), "status tablet");
    assert.strictEqual(migrate("tablet lid closed"), "set tablet lid closed");
    assert.strictEqual(migrate("tablet lid open"), "set tablet lid open");
    assert.strictEqual(migrate("tablet lid toggle"), "toggle tablet lid");
    assert.strictEqual(migrate("tablet probe"), "dispatch tablet probe");
    assert.strictEqual(migrate("tablet probe-lid"), "dispatch tablet probe lid");
});

test("penmap, picker, lock, keyring", () => {
    assert.strictEqual(migrate("penmap open"), "open panel penmap");
    assert.strictEqual(migrate("penmap commit"), "dispatch penmap commit");
    assert.strictEqual(migrate("penmap follow"), "dispatch penmap follow");
    assert.strictEqual(migrate("penmap set 0 0 100 100"), "set penmap rect 0 0 100 100");
    assert.strictEqual(migrate("penmap status"), "status penmap");
    assert.strictEqual(migrate("picker freezeclip"), "dispatch picker freezeclip");
    assert.strictEqual(migrate("picker clip"), "dispatch picker clip");
    assert.strictEqual(migrate("picker close"), "close panel picker");
    assert.strictEqual(migrate("lock"), "dispatch lock");
    assert.strictEqual(migrate("lock status"), "status lock");
    assert.strictEqual(migrate("keyring status"), "status keyring");
    assert.strictEqual(migrate("keyring demo"), "dispatch keyring demo");
});

test("timer, alarm, zone", () => {
    assert.strictEqual(migrate("timer start 10m tea"), "dispatch timer start 10m tea");
    assert.strictEqual(migrate("timer pause"), "dispatch timer pause");
    assert.strictEqual(migrate("timer status"), "status timer");
    assert.strictEqual(migrate("alarm list"), "list alarm");
    assert.strictEqual(migrate("alarm status"), "status alarm");
    assert.strictEqual(migrate("alarm enable 2"), "dispatch alarm enable 2");
    assert.strictEqual(migrate("alarm add 07:00 --days mon,wed --label standup --run echo hi"),
        "dispatch alarm add 07:00 --days mon,wed --label standup --run echo hi");
    assert.strictEqual(migrate("zone list"), "list zone");
    assert.strictEqual(migrate("zone add new york"), "dispatch zone add new york");
    assert.strictEqual(migrate("zone find oslo"), "dispatch zone find oslo");
});

test("theme sugar folds into get/set", () => {
    assert.strictEqual(migrate("theme"), "get theme");
    assert.strictEqual(migrate("theme dark"), "set theme dark");
    assert.strictEqual(migrate("themes"), "list themes");
});

test("the rescue stays one word", () => {
    assert.strictEqual(migrate("close"), "close");
    assert.strictEqual(migrate("panic"), "close");
});

test("new forms pass through untouched", () => {
    for (const cmd of ["toggle panel launcher", "set volume 50", "dispatch clipboard use 3",
        "list wallpaper", "status border", "close panel notifications", "close"])
        assert.strictEqual(Migration.migrateArgs(cmd), null, cmd);
});

test("rewrites inside exec_cmd strings", () => {
    const { text, changes } = Migration.rewriteText(
        "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"banditshell media toggle\"))");
    assert.strictEqual(text,
        "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"banditshell toggle panel media\"))");
    assert.strictEqual(changes.length, 1);
});

test("leaves the && tail alone", () => {
    const line = "bind = $mod SHIFT, K, exec, banditshell border toggle && hyprctl eval \"hl.config({ gaps_out = 0 })\"";
    const { text } = Migration.rewriteText(line);
    assert.ok(text.includes("banditshell toggle border && hyprctl eval"), text);
    assert.ok(text.includes("hl.config"), text);
});

test("quoted arguments survive the span", () => {
    const { text } = Migration.rewriteText("exec = banditshell calculator answer \"2+3*4\"");
    assert.ok(text.includes("banditshell dispatch calculator answer \"2+3*4\""), text);
});

test("does not touch names that merely contain the word", () => {
    const line = "windowrule = float, match:title ^(banditshell-settingspreview)$";
    const { text, changes } = Migration.rewriteText(line);
    assert.strictEqual(text, line);
    assert.strictEqual(changes.length, 0);
});

test("rewriting twice changes nothing the second time", () => {
    const once = Migration.rewriteText("hl.dsp.exec_cmd(\"banditshell wallpapers toggle\")");
    const twice = Migration.rewriteText(once.text);
    assert.strictEqual(twice.changes.length, 0);
    assert.strictEqual(twice.text, once.text);
});

test("the map covers every noun the old CLI had", () => {
    const oldNouns = ["menu", "launcher", "clipboard", "session", "media", "calculator",
        "tablet", "keyboard", "settings", "notifications", "notch", "hotkeys",
        "timer", "alarm", "zone", "volume", "output", "lock", "keyring", "picker",
        "wallpaper", "wallpapers", "border", "files", "calendar", "clock", "theme", "themes"];
    const sources = Migration.RULES.map(r => String(r.re));
    for (const noun of oldNouns)
        assert.ok(sources.some(s => s.includes(noun)), `no rule names ${noun}`);
});

test("the sidebar's old noun-first forms become its generic verbs", () => {
    assert.strictEqual(migrate("sidebar toggle"), "toggle sidebar");
    assert.strictEqual(migrate("sidebar toggle DP-2"), "toggle sidebar DP-2");
    assert.strictEqual(migrate("sidebar toggle all"), "toggle sidebar all");
    assert.strictEqual(migrate("sidebar on"), "set sidebar on");
    assert.strictEqual(migrate("sidebar off all"), "set sidebar off all");
    assert.strictEqual(migrate("sidebar status"), "status sidebar");
});

test("a bare old noun runs what the old CLI defaulted it to", () => {
    const bare = {
        launcher: "toggle panel launcher",
        clipboard: "toggle panel clipboard",
        session: "toggle panel session",
        media: "toggle panel media",
        calculator: "toggle panel calculator",
        calc: "toggle panel calculator",
        keyboard: "toggle panel keyboard",
        osk: "toggle panel keyboard",
        settings: "toggle panel settings",
        notifications: "toggle panel notifications",
        notch: "toggle panel notch",
        hotkeys: "toggle panel hotkeys",
        wallpapers: "toggle panel wallpaper",
        wallpaper: "toggle wallpaper",
        border: "toggle border",
        menu: "list menu",
        alarm: "list alarm",
        zone: "list zone",
        penmap: "status penmap",
        pen: "status penmap",
        tablet: "status tablet",
        timer: "status timer",
        volume: "status volume",
        output: "status output",
        keyring: "status keyring",
        picker: "dispatch picker freezeclip",
        lock: "dispatch lock"
    };
    for (const old in bare)
        assert.strictEqual(migrate(old), bare[old], old);
});

test("bare words that are still verbs stay as they are", () => {
    for (const verb of ["files", "status", "close", "start", "doctor"])
        assert.strictEqual(Migration.migrateArgs(verb), null, verb);
});

test("the sidebar bind is rewritten where it lives in a Lua config", () => {
    const { text, changes } = Migration.rewriteText('hl.bind("SUPER + K", hl.dsp.exec_cmd("banditshell sidebar toggle"))');
    assert.strictEqual(changes.length, 1);
    assert.strictEqual(text, 'hl.bind("SUPER + K", hl.dsp.exec_cmd("banditshell toggle sidebar"))');
});

test("the example binds speak only the new grammar", () => {
    const example = fs.readFileSync(path.join(ROOT, "docs/hyprland-binds.example.conf"), "utf8");
    assert.deepStrictEqual(Migration.rewriteText(example).changes.map(c => c.from), []);
});

test("comments are prose, not binds: they are never counted or rewritten", () => {
    const conf = [
        "# the old key ran `banditshell media",
        "-- banditshell sidebar toggle was the old form",
        "bind = $mod, Z, exec, banditshell sidebar toggle # the sidebar"
    ].join("\n");
    const { text, changes } = Migration.rewriteText(conf);
    assert.strictEqual(changes.length, 1);
    assert.strictEqual(text.split("\n")[2], "bind = $mod, Z, exec, banditshell toggle sidebar # the sidebar");
    assert.strictEqual(text.split("\n")[1], "-- banditshell sidebar toggle was the old form");
});
