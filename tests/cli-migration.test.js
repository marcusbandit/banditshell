const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/cli-migration.js"), "utf8");
const Migration = new Function(src
    + "\nreturn { migrateArgs, rewriteText, RULES };")();

function migrate(cmd) {
    const hit = Migration.migrateArgs(cmd);
    if (!hit)
        return cmd;
    return hit.run ? `!${hit.args}` : hit.args;
}

function table(pairs) {
    for (const [old, now] of pairs)
        assert.strictEqual(migrate(old), now, old);
}

test("lifecycle words need nothing", () => {
    for (const verb of ["start", "stop", "restart", "status", "log", "doctor", "completions install"])
        assert.strictEqual(Migration.migrateArgs(verb), null, verb);
});

test("the new grammar passes through untouched", () => {
    for (const cmd of ["panel launcher toggle", "panel close", "screen border off", "wallpaper next",
        "wallpaper", "tablet on compositor", "clock timer start 10m", "output toggle", "config set edge.bare true",
        "screenshot copy --freeze", "dev try 2", "dev back", "help panel"])
        assert.strictEqual(Migration.migrateArgs(cmd), null, cmd);
});

test("a panel comes first, then what to do with it", () => {
    table([
        ["toggle panel launcher", "panel launcher toggle"],
        ["open panel clipboard", "panel clipboard open"],
        ["close panel notifications", "panel notifications close"],
        ["status panel notch DP-1", "panel notch status DP-1"],
        ["toggle panel files ~/docs", "panel files toggle ~/docs"],
        ["open panel settings wifi DP-1", "panel settings open wifi DP-1"],
        ["toggle panel calendar", "panel calendar toggle"],
        ["toggle panel wallpaper DP-1", "panel wallpaper toggle DP-1"],
        ["close", "panel close"],
        ["panic", "panel close"],
        ["files", "panel files toggle"],
        ["files open ~/docs", "panel files open ~/docs"]
    ]);
});

test("a panel's own actions follow its name", () => {
    table([
        ["dispatch launcher run firefox", "panel launcher run firefox"],
        ["dispatch settings page wifi", "panel settings page wifi"],
        ["dispatch settings float", "panel settings float"],
        ["dispatch keyboard dock", "panel keyboard dock"],
        ["dispatch keyboard page symbols DP-1", "panel keyboard page symbols DP-1"],
        ["dispatch clipboard pin 3", "panel clipboard pin 3"],
        ["dispatch clipboard clear", "panel clipboard clear"],
        ["list clipboard", "panel clipboard list"],
        ["dispatch calculator app", "panel calculator full"],
        ["dispatch calculator panel", "panel calculator compact"],
        ["dispatch calculator answer 2 + 2", "panel calculator answer 2 + 2"],
        ["dispatch notifications clear", "panel notifications clear"],
        ["dispatch keyring refuse", "panel keyring close"],
        ["status keyring", "panel keyring status"]
    ]);
});

test("the screen holds its levels and the shell's frame", () => {
    table([
        ["toggle border", "screen border toggle"],
        ["set border off", "screen border off"],
        ["status border", "screen border"],
        ["toggle sidebar", "screen sidebar toggle"],
        ["toggle sidebar DP-2", "screen sidebar toggle DP-2"],
        ["set sidebar on all", "screen sidebar on all"],
        ["status sidebar", "screen sidebar"],
        ["set stream on DP-1", "screen stream on DP-1"],
        ["set stream off", "screen stream off"],
        ["status stream", "screen stream"],
        ["set brightness +.1", "screen brightness +.1"],
        ["set temperature off", "screen temperature off"],
        ["status screen", "screen"]
    ]);
});

test("everything about the wallpaper starts with wallpaper", () => {
    table([
        ["toggle wallpaper", "wallpaper toggle"],
        ["set wallpaper off", "wallpaper off"],
        ["set wallpaper ~/a.png DP-1", "wallpaper set ~/a.png DP-1"],
        ["status wallpaper", "wallpaper"],
        ["list wallpaper DP-1", "wallpaper list DP-1"],
        ["dispatch wallpaper next all", "wallpaper next all"],
        ["dispatch wallpaper palette", "wallpaper palette"]
    ]);
});

test("the output keeps its speakers and headphones", () => {
    table([
        ["toggle output", "output toggle"],
        ["set output headphones", "output headphones"],
        ["set output speakers alsa_output.pci", "output assign speakers alsa_output.pci"],
        ["status output", "output"],
        ["list output", "output list"]
    ]);
});

test("volume goes to wpctl, the lock to loginctl", () => {
    const sink = "@DEFAULT_AUDIO_SINK@";
    table([
        ["set volume +", `!wpctl set-volume -l 1 ${sink} 5%+`],
        ["set volume -", `!wpctl set-volume -l 1 ${sink} 5%-`],
        ["set volume +10", `!wpctl set-volume -l 1 ${sink} 10%+`],
        ["set volume -.1", `!wpctl set-volume -l 1 ${sink} 10%-`],
        ["set volume 40", `!wpctl set-volume -l 1 ${sink} 40%`],
        ["set volume .5", `!wpctl set-volume -l 1 ${sink} 50%`],
        ["toggle volume mute", `!wpctl set-mute ${sink} toggle`],
        ["set volume mute", `!wpctl set-mute ${sink} toggle`],
        ["set volume mute on", `!wpctl set-mute ${sink} 1`],
        ["set volume mute off", `!wpctl set-mute ${sink} 0`],
        ["status volume", `!wpctl get-volume ${sink}`],
        ["dispatch lock", "!loginctl lock-session"],
        ["lock", "!loginctl lock-session"],
        ["status lock", "!loginctl show-session auto -p LockedHint"]
    ]);
    assert.strictEqual(Migration.migrateArgs("set volume loud"), null);
});

test("the tablet holds its hinge, lid, probe and pen", () => {
    table([
        ["set tablet on compositor", "tablet on compositor"],
        ["set tablet off", "tablet off"],
        ["toggle tablet", "tablet toggle"],
        ["toggle tablet lid hand", "tablet lid toggle hand"],
        ["set tablet lid closed", "tablet lid closed"],
        ["status tablet", "tablet"],
        ["dispatch tablet probe", "tablet probe"],
        ["dispatch tablet probe lid", "tablet probe lid"],
        ["dispatch penmap probe", "tablet probe"],
        ["open panel penmap", "tablet pen edit"],
        ["toggle panel penmap", "tablet pen edit"],
        ["close panel penmap", "tablet pen cancel"],
        ["status panel penmap", "tablet pen"],
        ["status penmap", "tablet pen"],
        ["dispatch penmap commit", "tablet pen commit"],
        ["set penmap rect 0 0 1920 1080", "tablet pen area 0 0 1920 1080"]
    ]);
});

test("timers, alarms and zones live in the clock", () => {
    table([
        ["dispatch timer start 10m tea", "clock timer start 10m tea"],
        ["dispatch timer toggle", "clock timer toggle"],
        ["status timer", "clock timer"],
        ["dispatch alarm snooze", "clock alarm snooze"],
        ["dispatch alarm add 7:00 --days weekdays", "clock alarm add 7:00 --days weekdays"],
        ["status alarm", "clock alarm"],
        ["list alarm", "clock alarm list"],
        ["list zone", "clock zone list"],
        ["dispatch zone add Tokyo", "clock zone add Tokyo"]
    ]);
});

test("the picker is screenshot", () => {
    table([
        ["dispatch picker open", "screenshot save"],
        ["dispatch picker freeze", "screenshot save --freeze"],
        ["dispatch picker clip", "screenshot copy"],
        ["dispatch picker freezeclip", "screenshot copy --freeze"],
        ["dispatch picker close", "panel close"],
        ["shot", "screenshot full"],
        ["shot /tmp/a.png", "screenshot full /tmp/a.png"]
    ]);
});

test("settings start with config", () => {
    table([
        ["get theme", "config theme"],
        ["set theme slate", "config theme slate"],
        ["list themes", "config theme list"],
        ["get edge.bare", "config get edge.bare"],
        ["set edge.bare true", "config set edge.bare true"]
    ]);
});

test("working on the shell starts with dev", () => {
    table([
        ["try", "dev try"],
        ["try wall", "dev try wall"],
        ["back", "dev back"],
        ["run", "dev run"],
        ["build", "dev build"],
        ["shaders", "dev shaders"],
        ["test --test-name-pattern x", "dev test --test-name-pattern x"],
        ["check", "dev check"],
        ["list worktree", "dev worktrees"],
        ["list menu", "dev menu list"],
        ["dispatch menu hover", "dev menu hover"],
        ["dispatch launcher scrub .5", "dev launcher scrub .5"],
        ["dispatch keyring demo", "dev keyring demo"],
        ["demo calendar", "dev preview menu calendar"],
        ["gallery 1280x800", "dev preview gallery 1280x800"],
        ["lockpreview", "dev preview lock"],
        ["settingspreview 400x800 wifi", "dev preview settings 400x800 wifi"],
        ["filespreview ~/docs /tmp/f.png", "dev preview files ~/docs /tmp/f.png"],
        ["dispatch migration migrate", "doctor binds"],
        ["status migration", "doctor"]
    ]);
});

test("the map covers every verb and dispatch target the old CLI had", () => {
    const sources = Migration.RULES.map(r => String(r.re));
    for (const word of ["toggle", "open", "close", "panic", "status", "set", "get", "list", "files",
        "menu", "timer", "alarm", "zone", "clipboard", "calculator", "keyboard", "settings", "launcher",
        "wallpaper", "penmap", "tablet", "keyring", "notifications", "migration", "lock", "picker",
        "volume", "output", "border", "sidebar", "stream", "brightness", "temperature", "theme", "themes",
        "worktree", "try", "back", "run", "build", "shaders", "test", "check", "shot", "demo", "gallery", "preview"])
        assert.ok(sources.some(s => s.includes(word)), `no rule names ${word}`);
});

test("rewrites inside exec_cmd strings", () => {
    const { text, changes } = Migration.rewriteText(
        "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"banditshell toggle panel media\"))");
    assert.strictEqual(text,
        "hl.bind(\"SUPER + M\", hl.dsp.exec_cmd(\"banditshell panel media toggle\"))");
    assert.strictEqual(changes.length, 1);
});

test("a bind that now belongs to another program names that program", () => {
    const { text } = Migration.rewriteText(
        "{ \"XF86AudioRaiseVolume\", \"banditshell set volume +\", true },\nhl.bind(\"SUPER + L\", hl.dsp.exec_cmd(\"banditshell dispatch lock\"))");
    assert.strictEqual(text,
        "{ \"XF86AudioRaiseVolume\", \"wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+\", true },\nhl.bind(\"SUPER + L\", hl.dsp.exec_cmd(\"loginctl lock-session\"))");
});

test("a redirection or a pipe ends the command", () => {
    const line = 'banditshell set border "$border" >/dev/null 2>&1 || return 1';
    const { text } = Migration.rewriteText(line);
    assert.strictEqual(text, 'banditshell screen border "$border" >/dev/null 2>&1 || return 1');
    assert.strictEqual(Migration.rewriteText("banditshell list menu | head").text, "banditshell dev menu list | head");
});

test("a named thing never falls through to config set", () => {
    table([
        ["set border $mode", "screen border $mode"],
        ["set tablet $state compositor", "tablet $state compositor"],
        ["set output $role", "output $role"]
    ]);
    for (const name of ["wallpaper", "volume", "brightness", "temperature", "theme", "penmap"])
        assert.ok(!migrate(`set ${name} "$x"`).startsWith("config set"), name);
});

test("leaves the && tail alone", () => {
    const line = "bind = $mod SHIFT, K, exec, banditshell toggle border && hyprctl eval \"hl.config({ gaps_out = 0 })\"";
    const { text } = Migration.rewriteText(line);
    assert.ok(text.includes("banditshell screen border toggle && hyprctl eval"), text);
    assert.ok(text.includes("hl.config"), text);
});

test("quoted arguments survive the span", () => {
    const { text } = Migration.rewriteText("exec = banditshell dispatch calculator answer \"2+3*4\"");
    assert.ok(text.includes("banditshell panel calculator answer \"2+3*4\""), text);
});

test("does not touch names that merely contain the word", () => {
    const line = "windowrule = float, match:title ^(banditshell-settingspreview)$";
    const { text, changes } = Migration.rewriteText(line);
    assert.strictEqual(text, line);
    assert.strictEqual(changes.length, 0);
});

test("rewriting twice changes nothing the second time", () => {
    for (const line of ["hl.dsp.exec_cmd(\"banditshell toggle panel wallpaper\")",
        "bindel = , XF86AudioRaiseVolume, exec, banditshell set volume +"]) {
        const once = Migration.rewriteText(line);
        const twice = Migration.rewriteText(once.text);
        assert.strictEqual(twice.changes.length, 0, line);
        assert.strictEqual(twice.text, once.text, line);
    }
});

test("the example binds speak only the new grammar", () => {
    const example = fs.readFileSync(path.join(ROOT, "docs/hyprland-binds.example.conf"), "utf8");
    assert.deepStrictEqual(Migration.rewriteText(example).changes.map(c => c.from), []);
});

test("comments are prose, not binds: they are never counted or rewritten", () => {
    const conf = [
        "# the old key ran `banditshell toggle panel media",
        "-- banditshell toggle sidebar was the old form",
        "bind = $mod, Z, exec, banditshell toggle sidebar # the sidebar"
    ].join("\n");
    const { text, changes } = Migration.rewriteText(conf);
    assert.strictEqual(changes.length, 1);
    assert.strictEqual(text.split("\n")[2], "bind = $mod, Z, exec, banditshell screen sidebar toggle # the sidebar");
    assert.strictEqual(text.split("\n")[1], "-- banditshell toggle sidebar was the old form");
});
