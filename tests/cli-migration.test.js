const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/cli-migration.js"), "utf8");
const Migration = new Function(src
    + "\nreturn { migrateArgs, rewriteText, RULES, GENERATION, parseActions, actionFor, rewriteStable, backupName };")();

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

test("a read-only old form never becomes one that acts", () => {
    const acting = /^(doctor$|doctor binds rewrite|start|stop|restart|dev (try|back|run|build|shaders)|panel close|screen \S+ (on|off|toggle)|wallpaper (on|off|toggle|next|prev|clear|set))( |$)/;
    for (const old of ["status migration", "status border", "status panel media", "status keyring", "status tablet",
        "status penmap", "status timer", "status alarm", "status wallpaper", "status output", "status screen",
        "list menu", "list clipboard", "list themes", "list worktree", "get theme", "dispatch alarm status"])
        assert.ok(!acting.test(migrate(old)), `${old} -> ${migrate(old)}`);
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
        ["dispatch keyring refuse", "dev keyring close"],
        ["status keyring", "dev keyring status"]
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
    for (const bad of ["set volume loud", "set volume .", "set volume +.", "set volume 1.2.3"])
        assert.strictEqual(Migration.migrateArgs(bad), null, bad);
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
        ["dispatch alarm status", "clock alarm"],
        ["dispatch alarm list", "clock alarm list"],
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
        ["dispatch picker close", "panel picker close"],
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
        ["dispatch migration migrate", "doctor binds rewrite"],
        ["status migration", "doctor binds"]
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
    assert.strictEqual(Migration.rewriteText("banditshell dispatch picker freeze 2>/dev/null").text, "banditshell screenshot save --freeze 2>/dev/null");
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


const ACTIONS = Migration.parseActions(fs.readFileSync(path.join(ROOT, "api/actions.tsv"), "utf8"));

function stable(text) {
    return Migration.rewriteStable(Migration.rewriteText(text).text, ACTIONS);
}

function lineFor(command, call = "hl.dsp.exec_cmd") {
    return `hl.bind("SUPER + X", ${call}("banditshell ${command}"))`;
}

function resolve(id, rows) {
    let best = null;
    for (const row of rows) {
        const pattern = row.id.split(".");
        const want = id.split(".");
        if (pattern.length !== want.length)
            continue;
        const captures = [];
        const fits = pattern.every((segment, i) => {
            if (segment === "*") {
                captures.push(want[i]);
                return true;
            }
            return segment === want[i];
        });
        if (fits && (!best || captures.length < best.captures.length))
            best = { row, captures };
    }
    return best && best.row.words.map(w => /^\$[1-9]$/.test(w) ? best.captures[Number(w[1]) - 1] : w);
}

test("the generation the QML keeps is the generation this file defines", () => {
    const qml = fs.readFileSync(path.join(ROOT, "services/CliMigration.qml"), "utf8");
    assert.strictEqual(Number(/property int generation: (\d+)/.exec(qml)[1]), Migration.GENERATION);
    assert.match(qml, /bindsDeclinedGeneration/);
    assert.ok(!/set\("cli\.bindsDeclined",/.test(qml));
    const config = fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8");
    assert.match(config, /bindsDeclinedGeneration: 0/);
});

test("the action table is read into rows of words", () => {
    const rows = Migration.parseActions("# api 1\n# id\tstatus\tsince\targv\tdescription\nlauncher.toggle\tstable\t1\tpanel launcher toggle\tOpen\n\npanel.*.close\tstable\t1\tpanel $1 close\tClose\n");
    assert.deepStrictEqual(rows.map(r => [r.id, r.words]), [["launcher.toggle", ["panel", "launcher", "toggle"]], ["panel.*.close", ["panel", "$1", "close"]]]);
});

test("a command maps to the most specific id, with what is left over as arguments", () => {
    const at = cmd => Migration.actionFor(cmd.split(" "), ACTIONS);
    assert.deepStrictEqual(at("panel launcher toggle"), { id: "launcher.toggle", length: 3, stars: 0, args: [] });
    assert.strictEqual(at("panel clipboard toggle").id, "panel.clipboard.toggle");
    assert.deepStrictEqual(at("panel launcher run firefox").args, ["firefox"]);
    assert.strictEqual(at("screen brightness +").id, "screen.brightness.up");
    assert.deepStrictEqual([at("screen brightness +5").id, at("screen brightness +5").args], ["screen.brightness.set", ["+5"]]);
    assert.strictEqual(at("screenshot copy --freeze").id, "screenshot.copy_frozen");
    assert.strictEqual(at("screenshot copy").id, "screenshot.copy");
    assert.strictEqual(at("wallpaper next all").id, "wallpaper.next");
    assert.strictEqual(at("dev try 2"), null);
    assert.strictEqual(at("panel"), null);
});

test("two rows that fit equally well are not guessed between", () => {
    const rows = Migration.parseActions("a.one\tstable\t1\tgo $1\tx\na.two\tstable\t1\tgo $1\ty\n".replace("a.one", "a.*").replace("a.two", "b.*"));
    assert.strictEqual(Migration.actionFor(["go", "x"], rows), null);
});

test("a deprecated or removed row is never the target of a rewrite", () => {
    const rows = Migration.parseActions("old.thing\tdeprecated=new.thing\t1\tpanel launcher toggle\tx\nnew.thing\tstable\t1\tpanel launcher toggle\ty\n");
    assert.strictEqual(Migration.actionFor(["panel", "launcher", "toggle"], rows).id, "new.thing");
});

test("every id round-trips: the command it stands for is the command it came from", () => {
    for (const row of ACTIONS) {
        const concrete = row.id.split(".").map(s => s === "*" ? "launcher" : s).join(".");
        const words = row.words.map(w => /^\$[1-9]$/.test(w) ? "launcher" : w);
        const found = Migration.actionFor(words, ACTIONS);
        assert.ok(found, row.id);
        assert.deepStrictEqual(resolve(found.id, ACTIONS).concat(found.args), words, `${row.id}: ${words.join(" ")} -> ${found.id}`);
        assert.ok(resolve(concrete, ACTIONS), concrete);
    }
});

test("exec strings in binds become ids, and a bare dispatcher stays a dispatcher", () => {
    const r = stable([
        'local mod = "SUPER"',
        lineFor("panel launcher toggle"),
        lineFor("panel clipboard toggle"),
        lineFor("screenshot copy --freeze"),
        lineFor("tablet on compositor"),
        lineFor("panel launcher run firefox"),
        'hl.bind("SUPER + A", hl.dsp.exec_cmd(\'banditshell panel close\'), { locked = true })'
    ].join("\n"));
    assert.deepStrictEqual(r.text.split("\n"), [
        'local bs = require("banditshell")',
        'local mod = "SUPER"',
        'hl.bind("SUPER + X", bs.launcher.toggle)',
        'hl.bind("SUPER + X", bs.panel.clipboard.toggle)',
        'hl.bind("SUPER + X", bs.screenshot.copy_frozen)',
        'hl.bind("SUPER + X", bs.action("tablet.on", "compositor"))',
        'hl.bind("SUPER + X", bs.action("launcher.run", "firefox"))',
        'hl.bind("SUPER + A", bs.panel.close, { locked = true })'
    ]);
    assert.strictEqual(r.changes.length, 6);
});

test("the old grammar goes straight to an id in one pass", () => {
    const r = stable(lineFor("toggle panel media") + "\n" + lineFor("dispatch wallpaper next all"));
    assert.deepStrictEqual(r.text.split("\n").slice(1), ['hl.bind("SUPER + X", bs.panel.media.toggle)', 'hl.bind("SUPER + X", bs.action("wallpaper.next", "all"))']);
});

test("hl.exec_cmd inside a function becomes bs.run", () => {
    const r = stable('hl.bind("K", function()\n  hl.exec_cmd("banditshell screen border toggle")\n  hl.exec_cmd("banditshell wallpaper toggle")\nend)');
    assert.match(r.text, /^local bs = require\("banditshell"\)\n/);
    assert.match(r.text, /^  bs\.run\("screen\.border\.toggle"\)$/m);
    assert.match(r.text, /^  bs\.run\("wallpaper\.toggle"\)$/m);
});

test("lines that are not one plain banditshell command stay exactly as they were", () => {
    const keep = [
        'hl.bind("A", hl.dsp.exec_cmd("terminal -e btop"))',
        'hl.bind("B", hl.dsp.exec_cmd("banditshell panel files toggle ~/docs"))',
        'hl.bind("C", hl.dsp.exec_cmd("banditshell panel launcher toggle && notify-send hi"))',
        'hl.bind("D", hl.dsp.exec_cmd(terminal .. " btop"))',
        'hl.bind("E", hl.dsp.exec_cmd("banditshell dev try 2"))',
        'hl.bind("F", hl.dsp.exec_cmd("banditshell panel launcher run \'a b\'"))',
        'hl.bind("G", hl.dsp.exec_cmd("banditshell set volume +"))',
        '-- hl.bind("H", hl.dsp.exec_cmd("banditshell panel close"))',
        'hl.bind("I", hl.dsp.exec_cmd("banditshell doctor"))'
    ];
    const r = Migration.rewriteStable(keep.join("\n"), ACTIONS);
    assert.strictEqual(r.text, keep.join("\n"));
    assert.deepStrictEqual(r.changes, []);
});

test("one require line per file, none when it is there, and a file with a clash is left alone", () => {
    const has = stable('local bs = require("banditshell")\n' + lineFor("panel close"));
    assert.strictEqual(has.text.match(/require/g).length, 1);
    assert.strictEqual(has.changes.length, 1);
    const other = stable('local b = require("banditshell")\n' + lineFor("panel close"));
    assert.strictEqual(other.changes.length, 0);
    assert.match(other.skipped, /another name/);
    assert.ok(other.text.includes("exec_cmd"));
    const clash = stable('local bs = 5\n' + lineFor("panel close"));
    assert.strictEqual(clash.changes.length, 0);
    assert.match(clash.skipped, /already uses the name bs/);
    const shebang = stable("-- header\n\n" + lineFor("panel close"));
    assert.deepStrictEqual(shebang.text.split("\n").slice(0, 3), ["-- header", "", 'local bs = require("banditshell")']);
    const none = stable('hl.bind("A", hl.dsp.exec_cmd("terminal"))');
    assert.ok(!none.text.includes("require"));
});

test("a rewrite is stable: running it on its own output changes nothing", () => {
    const once = stable([lineFor("panel launcher toggle"), lineFor("wallpaper next all"), lineFor("panel files toggle ~/x")].join("\n"));
    const twice = Migration.rewriteStable(once.text, ACTIONS);
    assert.strictEqual(twice.text, once.text);
    assert.deepStrictEqual(twice.changes, []);
});

test("backups carry the time and never replace an earlier one", () => {
    const now = new Date(2026, 9, 17, 14, 5, 9);
    const taken = new Set();
    const first = Migration.backupName("/h/binds.lua", now, f => taken.has(f));
    assert.strictEqual(first, "/h/binds.lua.bak-20261017-140509");
    taken.add(first);
    const second = Migration.backupName("/h/binds.lua", now, f => taken.has(f));
    assert.strictEqual(second, "/h/binds.lua.bak-20261017-140509-2");
    taken.add(second);
    assert.strictEqual(Migration.backupName("/h/binds.lua", now, f => taken.has(f)), "/h/binds.lua.bak-20261017-140509-3");
});

function scratch(text) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "banditshell-migrate-"));
    const file = path.join(dir, "binds.lua");
    fs.writeFileSync(file, text);
    return { dir, file };
}

function node(...args) {
    return spawnSync("node", [path.join(ROOT, "services/cli-migration.js"), ...args], { encoding: "utf8" });
}

test("--write keeps every backup it ever made", () => {
    const { dir, file } = scratch('os.execute("banditshell toggle border")\n');
    try {
        assert.strictEqual(node("--write", file).status, 0);
        fs.writeFileSync(file, 'os.execute("banditshell toggle wallpaper")\n');
        assert.strictEqual(node("--write", file).status, 0);
        const backups = fs.readdirSync(dir).filter(f => f.startsWith("binds.lua.bak-"));
        assert.strictEqual(backups.length, 2);
        assert.ok(!fs.existsSync(file + ".bak"));
        assert.deepStrictEqual(backups.map(f => fs.readFileSync(path.join(dir, f), "utf8")).sort(), ['os.execute("banditshell toggle border")\n', 'os.execute("banditshell toggle wallpaper")\n']);
        assert.strictEqual(fs.readFileSync(file, "utf8"), 'os.execute("banditshell wallpaper toggle")\n');
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
});

test("--stable-check reports and writes nothing; --stable-write rewrites with a backup", () => {
    const text = [lineFor("panel launcher toggle"), lineFor("terminal")].join("\n") + "\n";
    const { dir, file } = scratch(text);
    try {
        const check = node("--stable-check", file);
        assert.strictEqual(check.status, 0);
        assert.match(check.stdout, /bs\.launcher\.toggle/);
        assert.strictEqual(fs.readFileSync(file, "utf8"), text);
        const scan = node("--stable-scan", file);
        assert.strictEqual(scan.stdout, `1\t${file}\n`);
        assert.strictEqual(node("--stable-write", file).status, 0);
        assert.match(fs.readFileSync(file, "utf8"), /^local bs = require\("banditshell"\)\n.*bs\.launcher\.toggle\)\)?/s);
        const backups = fs.readdirSync(dir).filter(f => f.startsWith("binds.lua.bak-"));
        assert.strictEqual(backups.length, 1);
        assert.strictEqual(fs.readFileSync(path.join(dir, backups[0]), "utf8"), text);
        assert.strictEqual(node("--stable-write", file).status, 2);
        assert.strictEqual(fs.readdirSync(dir).filter(f => f.startsWith("binds.lua.bak-")).length, 1);
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
});

test("--stable-scan counts nothing in a file that is already on ids, and the plain --scan is unchanged", () => {
    const { dir, file } = scratch('local bs = require("banditshell")\nhl.bind("A", bs.launcher.toggle)\nhl.bind("B", hl.dsp.exec_cmd("banditshell panel launcher toggle"))\n');
    try {
        assert.strictEqual(node("--stable-scan", file).stdout, `1\t${file}\n`);
        assert.strictEqual(node("--scan", file).stdout, "");
        assert.strictEqual(execFileSync("node", [path.join(ROOT, "services/cli-migration.js"), "--generation"], { encoding: "utf8" }), `${Migration.GENERATION}\n`);
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
});
