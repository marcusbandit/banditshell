const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const FIXTURES = path.join(__dirname, "fixtures/apps");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8");
const Entries = new Function(read("services/desktop-entries.js") + "\nreturn { parseBundle, indexEntries, indexPrograms, shownIn, setHidden, autostartText, autostartName, sessionLaunches };")();
const Startup = new Function(read("services/startup-apps.js") + "\nreturn { shellWords, quoteWord, parseExecLines, wrapperOf, offMarker, hyprlandApps, toggleReplacement, parseUnitFiles, candidateUnits, parseUnitShow, systemdApps, autostartApps, startSummary, launcherEnabled, readOverride, launcherApps, setDisabled, duplicateNotes, fullOrder, enqueueWrite, nextWrite, switchWrite, removalPath, addPlan, startedElsewhere, launchCommand };")();

const lua = fs.readFileSync(path.join(FIXTURES, "autostart.lua"), "utf8");
const files = [{ name: "lua/autostart.lua", text: lua }];

function apply(text, row, replacement) {
    const lines = text.split("\n");
    lines.splice(row.startLine - 1, row.endLine - row.startLine + 1, ...replacement);
    return lines.join("\n");
}

test("shell words honour quotes and keep their positions", () => {
    const words = Startup.shellWords("~/bin/shell-up 'qbittorrent --no-splash' spotify \"a b\" c\\ d");
    assert.deepStrictEqual(words.map(w => w.text), ["~/bin/shell-up", "qbittorrent --no-splash", "spotify", "a b", "c d"]);
    assert.strictEqual("~/bin/shell-up 'qbittorrent --no-splash'".slice(words[0].start, words[0].end), "~/bin/shell-up");
});

test("words are quoted only when they need it", () => {
    assert.strictEqual(Startup.quoteWord("spotify"), "spotify");
    assert.strictEqual(Startup.quoteWord("qbittorrent --no-splash"), "'qbittorrent --no-splash'");
    assert.strictEqual(Startup.quoteWord("it's"), "'it'\\''s'");
    assert.strictEqual(Startup.quoteWord("~/bin/x"), "~/bin/x");
});

test("exec lines are found, active or commented, single line only", () => {
    const lines = Startup.parseExecLines(lua);
    assert.deepStrictEqual(lines.map(l => [l.line, l.off, l.command]), [
        [6, false, "systemctl --user start hyprpolkitagent"],
        [9, false, "clipse -listen"],
        [11, false, "~/.config/hypr/scripts/shell-up 'qbittorrent --no-splash' spotify"],
        [13, false, "~/.local/bin/zen-pseudo-manager"],
        [14, true, "udiskie"],
        [17, false, "~/Projects/diablo/deploy/tmux-start.sh"]
    ]);
    assert.strictEqual(lines[3].comment, "keeps the pseudo window");
});

test("binds that run commands are not startup lines", () => {
    assert.ok(!Startup.parseExecLines(lua).some(l => l.command === "foot"));
});

test("hyprland apps skip session plumbing and split the wrapper into one app each", () => {
    const rows = Startup.hyprlandApps(files);
    assert.deepStrictEqual(rows.map(r => [r.command, r.on]), [
        ["clipse -listen", true],
        ["qbittorrent --no-splash", true],
        ["spotify", true],
        ["~/.local/bin/zen-pseudo-manager", true],
        ["udiskie", false],
        ["~/Projects/diablo/deploy/tmux-start.sh", true]
    ]);
    assert.ok(rows.every(r => r.file === "lua/autostart.lua"));
    assert.strictEqual(rows[1].wrapped, true);
    assert.strictEqual(rows[0].wrapped, false);
});

test("switching a plain line off comments it, and on takes the comment away again", () => {
    const rows = Startup.hyprlandApps(files);
    const clipse = rows.find(r => r.command === "clipse -listen");
    const off = apply(lua, clipse, Startup.toggleReplacement(clipse, false));
    assert.ok(off.includes("    -- hl.exec_cmd(\"clipse -listen\")\n"));
    const again = Startup.hyprlandApps([{ name: "x", text: off }]).find(r => r.command === "clipse -listen");
    assert.strictEqual(again.on, false);
    assert.strictEqual(apply(off, again, Startup.toggleReplacement(again, true)), lua);
});

test("switching a commented line on keeps a trailing comment of the user's", () => {
    const zen = Startup.hyprlandApps(files).find(r => r.command.endsWith("zen-pseudo-manager"));
    const off = apply(lua, zen, Startup.toggleReplacement(zen, false));
    assert.ok(off.includes("    -- hl.exec_cmd(\"~/.local/bin/zen-pseudo-manager\") -- keeps the pseudo window\n"));
    const udiskie = Startup.hyprlandApps(files).find(r => r.command === "udiskie");
    assert.ok(apply(lua, udiskie, Startup.toggleReplacement(udiskie, true)).includes("    hl.exec_cmd(\"udiskie\")\n"));
});

test("switching one app of the wrapper off drops its argument and remembers it on the line", () => {
    const qbit = Startup.hyprlandApps(files).find(r => r.command === "qbittorrent --no-splash");
    const off = apply(lua, qbit, Startup.toggleReplacement(qbit, false));
    assert.ok(off.includes("    hl.exec_cmd(\"~/.config/hypr/scripts/shell-up spotify\") -- off: @0 'qbittorrent --no-splash'\n"));
    const rows = Startup.hyprlandApps([{ name: "x", text: off }]);
    assert.deepStrictEqual(rows.filter(r => r.wrapped).map(r => [r.command, r.on]), [["spotify", true], ["qbittorrent --no-splash", false]]);
});

test("switching the wrapper's apps off one after the other empties its arguments and keeps the wrapper", () => {
    let text = lua;
    for (const command of ["qbittorrent --no-splash", "spotify"]) {
        const row = Startup.hyprlandApps([{ name: "x", text }]).find(r => r.command === command);
        text = apply(text, row, Startup.toggleReplacement(row, false));
    }
    assert.ok(text.includes("hl.exec_cmd(\"~/.config/hypr/scripts/shell-up\") -- off: 'qbittorrent --no-splash' spotify\n"));
});

test("switching a wrapper app back on restores its argument and clears the marker", () => {
    const qbit = Startup.hyprlandApps(files).find(r => r.command === "qbittorrent --no-splash");
    const off = apply(lua, qbit, Startup.toggleReplacement(qbit, false));
    const row = Startup.hyprlandApps([{ name: "x", text: off }]).find(r => r.command === "qbittorrent --no-splash");
    const on = apply(off, row, Startup.toggleReplacement(row, true));
    assert.strictEqual(on, lua);
});

test("a comment of the user's on a wrapper line survives being switched", () => {
    const text = "hl.exec_cmd(\"shell-up a b\") -- tray apps\n";
    const row = Startup.hyprlandApps([{ name: "x", text }]).find(r => r.command === "a");
    const off = apply(text, row, Startup.toggleReplacement(row, false));
    assert.strictEqual(off, "hl.exec_cmd(\"shell-up b\") -- off: @0 a | tray apps\n");
    const back = Startup.hyprlandApps([{ name: "x", text: off }]).find(r => r.command === "a");
    assert.deepStrictEqual(Startup.offMarker("off: a | tray apps"), { args: ["a"], indexes: [undefined], foreign: "tray apps" });
    assert.strictEqual(apply(off, back, Startup.toggleReplacement(back, true)), text);
});

function roundTrip(text, order) {
    let current = text;
    for (const [command, on] of order) {
        const row = Startup.hyprlandApps([{ name: "x", text: current }]).find(r => r.command === command);
        current = apply(current, row, Startup.toggleReplacement(row, on));
    }
    return current;
}

test("a comment with quotes and pipes comes back verbatim after many toggles", () => {
    const text = "hl.exec_cmd(\"shell-up a 'b c' d\") -- 'tray' \"apps\" | two  spaces  \n";
    const toggles = [["a", false], ["d", false], ["a", true], ["d", true], ["b c", false], ["b c", true]];
    assert.strictEqual(roundTrip(text, toggles.slice(0, 4)), text);
    assert.strictEqual(roundTrip(text, toggles), text);
    const mid = roundTrip(text, toggles.slice(0, 2));
    assert.ok(mid.endsWith("-- off: @0 a @2 d | 'tray' \"apps\" | two  spaces  \n"));
});

test("an app switched off and on again goes back where it was in the arguments", () => {
    const text = "hl.exec_cmd(\"shell-up a b c d\")\n";
    for (const command of ["a", "b", "c", "d"])
        assert.strictEqual(roundTrip(text, [[command, false], [command, true]]), text);
    assert.strictEqual(roundTrip(text, [["b", false], ["d", false], ["b", true], ["d", true]]), text);
    assert.strictEqual(roundTrip(text, [["b", false], ["d", false], ["d", true], ["b", true]]), text);
    const some = roundTrip(text, [["c", false], ["a", false]]);
    assert.strictEqual(some, "hl.exec_cmd(\"shell-up b d\") -- off: @0 a @2 c\n");
    assert.strictEqual(roundTrip(some, [["a", true]]), "hl.exec_cmd(\"shell-up a b d\") -- off: @2 c\n");
    assert.strictEqual(roundTrip(some, [["c", true], ["a", true]]), text);
});

test("apps off at the end of the arguments need no positions on the line", () => {
    const text = "hl.exec_cmd(\"shell-up a b c\")\n";
    assert.strictEqual(roundTrip(text, [["c", false]]), "hl.exec_cmd(\"shell-up a b\") -- off: c\n");
    assert.strictEqual(roundTrip(text, [["b", false], ["c", false]]), "hl.exec_cmd(\"shell-up a\") -- off: b c\n");
    assert.strictEqual(roundTrip(text, [["a", false], ["b", false], ["c", false]]), "hl.exec_cmd(\"shell-up\") -- off: a b c\n");
});

test("a note written before positions existed still puts its apps back at the end", () => {
    const text = "hl.exec_cmd(\"shell-up b\") -- off: a c | note\n";
    const row = Startup.hyprlandApps([{ name: "x", text }]).find(r => r.command === "a");
    assert.strictEqual(apply(text, row, Startup.toggleReplacement(row, true)), "hl.exec_cmd(\"shell-up b a\") -- off: c | note\n");
});

test("a word that looks like a position is quoted so it stays a word", () => {
    assert.strictEqual(Startup.quoteWord("@2"), "'@2'");
    const text = "hl.exec_cmd(\"shell-up a '@2'\")\n";
    assert.strictEqual(roundTrip(text, [["a", false], ["a", true]]), text);
    assert.strictEqual(roundTrip(text, [["@2", false], ["@2", true]]), text);
});

test("single-quoted lua strings and escaped quotes are written back as they came", () => {
    const text = "hl.exec_cmd('shell-up \"x y\" z')\n";
    const row = Startup.hyprlandApps([{ name: "x", text }]).find(r => r.command === "x y");
    assert.ok(row);
    assert.strictEqual(apply(text, row, Startup.toggleReplacement(row, false)), "hl.exec_cmd('shell-up z') -- off: @0 'x y'\n");
});

test("a commented wrapper line is left alone", () => {
    assert.deepStrictEqual(Startup.hyprlandApps([{ name: "x", text: "-- hl.exec_cmd(\"shell-up a\")\n" }]), []);
});

test("unit files list only services and skip templates", () => {
    const files = Startup.parseUnitFiles(fs.readFileSync(path.join(FIXTURES, "unit-files.txt"), "utf8"));
    assert.ok(!files.some(f => f.unit.includes("@")));
    assert.strictEqual(files.find(f => f.unit === "vesktop.service").state, "enabled");
    assert.ok(!Startup.candidateUnits(files).includes("dunst.service"));
    assert.ok(Startup.candidateUnits(files).includes("wireplumber.service"));
});

test("unit properties are read from systemctl show", () => {
    const shows = Startup.parseUnitShow(fs.readFileSync(path.join(FIXTURES, "unit-show.txt"), "utf8"));
    assert.deepStrictEqual(shows.map(s => s.unit), ["vesktop.service", "tmux.service", "spotify-spare.service", "wireplumber.service", "syncthing.service"]);
    assert.strictEqual(shows[0].program, "vesktop");
    assert.strictEqual(shows[0].description, "Vesktop (Discord)");
});

test("systemd apps are the enabled units that run an installed app, plus the user's own disabled ones", () => {
    const unitFiles = Startup.parseUnitFiles(fs.readFileSync(path.join(FIXTURES, "unit-files.txt"), "utf8"));
    const shows = Startup.parseUnitShow(fs.readFileSync(path.join(FIXTURES, "unit-show.txt"), "utf8"));
    const applications = fs.readdirSync(path.join(FIXTURES, "applications")).map(f => `@@@${f}\n${fs.readFileSync(path.join(FIXTURES, "applications", f), "utf8")}`).join("");
    const programs = Entries.indexPrograms(Entries.indexEntries(Entries.parseBundle(applications)));
    programs.syncthing = { name: "Syncthing" };
    const rows = Startup.systemdApps(unitFiles, shows, programs, "/home/bandit/.config/systemd/user");
    assert.deepStrictEqual(rows.map(r => [r.unit, r.on]), [["vesktop.service", true], ["spotify-spare.service", false], ["syncthing.service", true]]);
});

test("autostart apps are the entries this desktop would show, on unless hidden", () => {
    const bundle = fs.readdirSync(path.join(FIXTURES, "autostart")).sort().map(f => `@@@/home/bandit/.config/autostart/${f}\n${fs.readFileSync(path.join(FIXTURES, "autostart", f), "utf8")}`).join("");
    const rows = Startup.autostartApps(Entries.parseBundle(bundle), ["Hyprland"], Entries.shownIn);
    assert.deepStrictEqual(rows.map(r => [r.id, r.on]), [["autostart:off.desktop", false], ["autostart:remmina-applet.desktop", true]]);
    assert.strictEqual(rows[1].path, "/home/bandit/.config/autostart/remmina-applet.desktop");
});

function launcherBundle(withOverrides) {
    const dir = path.join(FIXTURES, "launcher");
    return fs.readdirSync(dir).filter(f => f.endsWith(".desktop")).sort().map(f => {
        const override = path.join(dir, "overrides", f.replace(/\.desktop$/, ".conf"));
        const has = withOverrides && fs.existsSync(override);
        return `\n@@@/home/x/.config/autostart-managed/${f}\n${fs.readFileSync(path.join(dir, f), "utf8")}\n@@@override /home/x/.config/autostart-managed/${f}\n${has ? fs.readFileSync(override, "utf8") : ""}`;
    }).join("");
}

test("the launcher counts only while its unit is enabled", () => {
    assert.strictEqual(Startup.launcherEnabled([{ unit: "autostart-launcher.service", state: "enabled" }]), true);
    assert.strictEqual(Startup.launcherEnabled([{ unit: "autostart-launcher.service", state: "disabled" }]), false);
    assert.strictEqual(Startup.launcherEnabled([]), false);
});

test("an override is read for what the launcher honours, quotes and comments included", () => {
    const text = fs.readFileSync(path.join(FIXTURES, "launcher/overrides/spotify.conf"), "utf8");
    assert.deepStrictEqual(Startup.readOverride(text), { disabled: false, delay: 5, extraArgs: "--minimized", extraEnv: "GDK_BACKEND=wayland FOO=bar" });
    assert.strictEqual(Startup.readOverride("disabled=\"true\"\n").disabled, true);
    assert.strictEqual(Startup.readOverride("disabled=true\ndisabled=false\n").disabled, false);
    assert.strictEqual(Startup.readOverride("#disabled=true\n").disabled, false);
    assert.deepStrictEqual(Startup.readOverride(""), { disabled: false, delay: 0, extraArgs: "", extraEnv: "" });
});

test("launcher apps pair each entry with the override that follows it", () => {
    const rows = Startup.launcherApps(Entries.parseBundle(launcherBundle(true)), "/home/x/.config/autostart-managed/overrides");
    assert.deepStrictEqual(rows.map(r => [r.id, r.on, r.delay]), [["launcher:claude-launcher.desktop", false, 0], ["launcher:spotify.desktop", true, 5]]);
    assert.strictEqual(rows[1].overridePath, "/home/x/.config/autostart-managed/overrides/spotify.conf");
    assert.ok(rows[1].overrideText.includes("extra_env"));
    assert.strictEqual(rows[0].entry.name, "Claude");
});

test("an app without an override file is on and has nothing to keep", () => {
    const rows = Startup.launcherApps(Entries.parseBundle(launcherBundle(false)), "/o");
    assert.deepStrictEqual(rows.map(r => [r.on, r.overrideText]), [[true, ""], [true, ""]]);
});

test("switching a launcher app off appends disabled after every other line, and creates the file when there is none", () => {
    const text = fs.readFileSync(path.join(FIXTURES, "launcher/overrides/spotify.conf"), "utf8");
    const off = Startup.setDisabled(text, true);
    assert.ok(off.endsWith("extra_env=\"GDK_BACKEND=wayland FOO=bar\"\ndisabled=true\n"));
    assert.ok(off.includes("#disabled=false\n"));
    assert.strictEqual(Startup.setDisabled("", true), "disabled=true\n");
    assert.strictEqual(Startup.readOverride(off).disabled, true);
    assert.strictEqual(Startup.readOverride(off).delay, 5);
});

test("switching on updates an active line and leaves a file without one alone", () => {
    assert.strictEqual(Startup.setDisabled("delay=2\ndisabled=\"true\"\nextra_args=x\n", false), "delay=2\ndisabled=false\nextra_args=x\n");
    const text = fs.readFileSync(path.join(FIXTURES, "launcher/overrides/spotify.conf"), "utf8");
    assert.strictEqual(Startup.setDisabled(text, false), text);
    assert.strictEqual(Startup.setDisabled("", false), "");
});

test("an app that starts from two sources says so on both rows, and only while both are on", () => {
    const entries = [
        { id: "hyprland:spotify", source: "hyprland", desktopId: "spotify.desktop", on: true },
        { id: "launcher:spotify.desktop", source: "launcher", desktopId: "spotify.desktop", on: true },
        { id: "launcher:claude.desktop", source: "launcher", desktopId: "claude.desktop", on: true },
        { id: "systemd:x", source: "systemd", desktopId: "", on: true }
    ];
    assert.deepStrictEqual(Startup.duplicateNotes(entries), { "hyprland:spotify": "also starts from launcher", "launcher:spotify.desktop": "also starts from hyprland" });
    entries[0].on = false;
    assert.deepStrictEqual(Startup.duplicateNotes(entries), {});
});

test("the summary counts what starts out of what is listed", () => {
    const rows = [{ on: true }, { on: true }, { on: false }];
    assert.strictEqual(Startup.startSummary(rows), "2 of 3 start");
    assert.strictEqual(Startup.startSummary(rows.slice(0, 2)), "all 2 start");
    assert.strictEqual(Startup.startSummary([]), "nothing to start yet");
});

test("an app on a commented line and on another active line is listed on, from the active line", () => {
    const text = "-- hl.exec_cmd(\"spotify\")\nhl.exec_cmd(\"spotify\")\n";
    const rows = Startup.hyprlandApps([{ name: "x", text }]);
    assert.deepStrictEqual(rows.map(r => [r.command, r.on, r.line.line]), [["spotify", true, 2]]);
});

test("turning such an app off comments out the line that starts it", () => {
    const text = "-- hl.exec_cmd(\"spotify\")\nhl.exec_cmd(\"spotify\")\n";
    const row = Startup.hyprlandApps([{ name: "x", text }])[0];
    const off = apply(text, row, Startup.toggleReplacement(row, false));
    assert.strictEqual(off, "-- hl.exec_cmd(\"spotify\")\n-- hl.exec_cmd(\"spotify\")\n");
    assert.strictEqual(Startup.hyprlandApps([{ name: "x", text: off }])[0].on, false);
});

test("an app on two active Hyprland lines is listed once", () => {
    const text = "hl.exec_cmd(\"spotify\")\nhl.exec_cmd(\"spotify\")\n";
    assert.strictEqual(Startup.hyprlandApps([{ name: "x", text }]).length, 1);
});

const AUTOSTART_DIR = "/home/bandit/.config/autostart";

function autostartFiles() {
    const dir = path.join(FIXTURES, "autostart");
    const bundle = fs.readdirSync(dir).sort().map(f => `@@@${AUTOSTART_DIR}/${f}\n${fs.readFileSync(path.join(dir, f), "utf8")}`).join("");
    return Entries.parseBundle(bundle);
}

function autostartRows() {
    return Startup.autostartApps(autostartFiles(), ["Hyprland"], Entries.shownIn);
}

function withTempDir(run) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "startup-apps-"));
    try {
        run(dir);
    } finally {
        fs.rmSync(dir, { recursive: true, force: true });
    }
}

test("adding an app that is listed switches it on instead of writing its file", () => {
    const plan = Startup.addPlan("remmina-applet.desktop", "[Desktop Entry]\n", AUTOSTART_DIR, autostartRows());
    assert.strictEqual(plan.kind, "switch");
    assert.strictEqual(plan.entry.id, "autostart:remmina-applet.desktop");
});

test("adding an app whose file the list hides writes that file again", () => {
    const plan = Startup.addPlan("gnome-only.desktop", "[Desktop Entry]\n", AUTOSTART_DIR, autostartRows());
    assert.deepStrictEqual(plan, { kind: "create", path: `${AUTOSTART_DIR}/gnome-only.desktop`, text: "[Desktop Entry]\n" });
});

test("adding an app with a new file name writes it into the autostart folder", () => {
    const plan = Startup.addPlan("spotify.desktop", "[Desktop Entry]\n", AUTOSTART_DIR, autostartRows());
    assert.deepStrictEqual(plan, { kind: "create", path: `${AUTOSTART_DIR}/spotify.desktop`, text: "[Desktop Entry]\n" });
});

test("adding an app with no usable file name changes nothing", () => {
    assert.deepStrictEqual(Startup.addPlan(Entries.autostartName(""), "x", AUTOSTART_DIR, []), { kind: "none" });
});

test("switching an autostart app off rewrites only its own file, with Hidden set", () => {
    const row = autostartRows().find(r => r.file === "remmina-applet.desktop");
    const write = Startup.switchWrite({ source: "autostart", row }, false, Entries.setHidden);
    assert.strictEqual(write.path, `${AUTOSTART_DIR}/remmina-applet.desktop`);
    assert.strictEqual(write.text, Entries.setHidden(row.text, true));
    assert.ok(write.text.includes("Hidden=true"));
});

test("switching an autostart app on rewrites only its own file, with Hidden cleared", () => {
    const row = autostartRows().find(r => r.file === "off.desktop");
    const write = Startup.switchWrite({ source: "autostart", row }, true, Entries.setHidden);
    assert.strictEqual(write.path, `${AUTOSTART_DIR}/off.desktop`);
    assert.strictEqual(write.text, Entries.setHidden(row.text, false));
    assert.ok(write.text.includes("Hidden=false"));
});

test("switching a launcher app off writes only its own override", () => {
    const rows = Startup.launcherApps(Entries.parseBundle(launcherBundle(true)), "/home/x/.config/autostart-managed/overrides");
    const row = rows.find(r => r.id === "launcher:spotify.desktop");
    const write = Startup.switchWrite({ source: "launcher", row }, false, Entries.setHidden);
    assert.strictEqual(write.path, "/home/x/.config/autostart-managed/overrides/spotify.conf");
    assert.strictEqual(write.text, Startup.setDisabled(row.overrideText, true));
});

test("switching a Hyprland or systemd app writes no file", () => {
    assert.strictEqual(Startup.switchWrite({ source: "hyprland", row: {} }, false, Entries.setHidden), null);
    assert.strictEqual(Startup.switchWrite({ source: "systemd", row: {} }, false, Entries.setHidden), null);
});

test("removing an autostart app names only its own file", () => {
    const row = autostartRows().find(r => r.file === "remmina-applet.desktop");
    assert.strictEqual(Startup.removalPath({ source: "autostart", row }), `${AUTOSTART_DIR}/remmina-applet.desktop`);
});

test("removing a Hyprland, systemd or launcher app names no file", () => {
    assert.strictEqual(Startup.removalPath({ source: "hyprland", row: { path: "/x/y" } }), null);
    assert.strictEqual(Startup.removalPath({ source: "systemd", row: {} }), null);
    assert.strictEqual(Startup.removalPath({ source: "launcher", row: { overridePath: "/o/x.conf" } }), null);
});

test("a removal is queued with no text", () => {
    assert.deepStrictEqual(Startup.enqueueWrite([], `${AUTOSTART_DIR}/a.desktop`, null), [{ path: `${AUTOSTART_DIR}/a.desktop`, text: null }]);
});

test("queued writes run one at a time, in the order they were queued", () => {
    let queue = Startup.enqueueWrite([], "/x/a.desktop", "one");
    queue = Startup.enqueueWrite(queue, "/x/a.desktop", "two");
    assert.strictEqual(Startup.nextWrite(queue, true), null);
    const first = Startup.nextWrite(queue, false);
    assert.deepStrictEqual(first.command.slice(4), ["/x/a.desktop", "one"]);
    const second = Startup.nextWrite(first.queue, false);
    assert.deepStrictEqual(second.command.slice(4), ["/x/a.desktop", "two"]);
    assert.strictEqual(Startup.nextWrite(second.queue, false), null);
});

test("a removal runs rm -f on exactly its own path", () => {
    const next = Startup.nextWrite(Startup.enqueueWrite([], "/x/a.desktop", null), false);
    assert.deepStrictEqual(next.command, ["rm", "-f", "/x/a.desktop"]);
});

function runNext(queue) {
    const next = Startup.nextWrite(queue, false);
    const done = spawnSync(next.command[0], next.command.slice(1), { encoding: "utf8" });
    assert.strictEqual(done.status, 0, done.stderr);
}

test("a write stores its text exactly, with quotes and substitutions left alone", () => withTempDir(dir => {
    const file = path.join(dir, "a b.desktop");
    const text = `Exec=sh -c 'echo "$(touch ${dir}/pwned)" \`touch ${dir}/ticked\`' %u\n`;
    runNext(Startup.enqueueWrite([], file, text));
    assert.strictEqual(fs.readFileSync(file, "utf8"), text);
    assert.deepStrictEqual(fs.readdirSync(dir), ["a b.desktop"]);
}));

test("a write creates the folder it goes into", () => withTempDir(dir => {
    const file = path.join(dir, "autostart", "a.desktop");
    runNext(Startup.enqueueWrite([], file, "[Desktop Entry]\n"));
    assert.strictEqual(fs.readFileSync(file, "utf8"), "[Desktop Entry]\n");
}));

test("a removal deletes only the file it names", () => withTempDir(dir => {
    fs.writeFileSync(path.join(dir, "a.desktop"), "a");
    fs.writeFileSync(path.join(dir, "b.desktop"), "b");
    runNext(Startup.enqueueWrite([], path.join(dir, "a.desktop"), null));
    assert.deepStrictEqual(fs.readdirSync(dir), ["b.desktop"]);
}));

test("only a running entry with a desktop file counts as started elsewhere", () => {
    const entries = [
        { source: "hyprland", on: true, desktopId: "spotify.desktop" },
        { source: "hyprland", on: true, desktopId: "" },
        { source: "launcher", on: false, desktopId: "vesktop.desktop" },
        { source: "autostart", on: true, desktopId: "kitty.desktop" }
    ];
    assert.deepStrictEqual(Startup.startedElsewhere(entries), ["spotify"]);
});

test("an app another source starts is left out of the session launch", () => {
    const entries = [{ source: "hyprland", on: true, desktopId: "remmina-applet.desktop" }];
    assert.deepStrictEqual(Entries.sessionLaunches(autostartFiles(), ["Hyprland"], Startup.startedElsewhere(entries)), []);
});

test("an autostart entry never keeps its own app out of the session launch", () => {
    const entries = [{ source: "autostart", on: true, desktopId: "remmina-applet.desktop" }];
    assert.deepStrictEqual(Entries.sessionLaunches(autostartFiles(), ["Hyprland"], Startup.startedElsewhere(entries)), ["exec remmina -i"]);
});

test("an app whose other source is switched off still starts from its autostart file", () => {
    const entries = [{ source: "hyprland", on: false, desktopId: "remmina-applet.desktop" }];
    assert.deepStrictEqual(Entries.sessionLaunches(autostartFiles(), ["Hyprland"], Startup.startedElsewhere(entries)), ["exec remmina -i"]);
});

function stubSession(dir, active) {
    fs.mkdirSync(path.join(dir, "bin"));
    fs.writeFileSync(path.join(dir, "bin", "systemctl"), `#!/bin/sh\nexit ${active ? 0 : 1}\n`, { mode: 0o755 });
    fs.writeFileSync(path.join(dir, "bin", "setsid"), `#!/bin/sh\nprintf '%s\\n' "$4" >> "${dir}/launched"\n`, { mode: 0o755 });
}

function startSession(dir, signature, launches, runtime = path.join(dir, "runtime")) {
    if (runtime)
        fs.mkdirSync(runtime, { recursive: true });
    const argv = Startup.launchCommand(signature, launches);
    const done = spawnSync(argv[0], argv.slice(1), { encoding: "utf8", env: { PATH: `${dir}/bin:/usr/bin:/bin`, XDG_RUNTIME_DIR: runtime } });
    assert.strictEqual(done.status, 0, done.stderr);
}

function launched(dir) {
    const file = path.join(dir, "launched");
    return fs.existsSync(file) ? fs.readFileSync(file, "utf8").split("\n").filter(Boolean) : [];
}

test("a session starts each of its launches once, in order", () => withTempDir(dir => {
    stubSession(dir, false);
    startSession(dir, "sig-1", ["exec spotify", "exec vesktop"]);
    assert.deepStrictEqual(launched(dir), ["exec spotify", "exec vesktop"]);
}));

test("a second start in the same Hyprland session starts nothing again", () => withTempDir(dir => {
    stubSession(dir, false);
    startSession(dir, "sig-1", ["exec spotify"]);
    startSession(dir, "sig-1", ["exec spotify"]);
    assert.deepStrictEqual(launched(dir), ["exec spotify"]);
}));

test("a new Hyprland session starts its launches again", () => withTempDir(dir => {
    stubSession(dir, false);
    startSession(dir, "sig-1", ["exec spotify"]);
    startSession(dir, "sig-2", ["exec spotify"]);
    assert.deepStrictEqual(launched(dir), ["exec spotify", "exec spotify"]);
}));

test("a session starts nothing while xdg-desktop-autostart already runs the apps", () => withTempDir(dir => {
    stubSession(dir, true);
    startSession(dir, "sig-1", ["exec spotify"]);
    assert.deepStrictEqual(launched(dir), []);
}));

test("a session starts nothing without a runtime directory", () => withTempDir(dir => {
    stubSession(dir, false);
    startSession(dir, "sig-1", ["exec spotify"], "");
    assert.deepStrictEqual(launched(dir), []);
}));
