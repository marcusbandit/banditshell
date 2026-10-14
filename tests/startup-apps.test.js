const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const FIXTURES = path.join(__dirname, "fixtures/apps");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8");
const Entries = new Function(read("services/desktop-entries.js") + "\nreturn { parseBundle, indexEntries, indexPrograms, shownIn };")();
const Startup = new Function(read("services/startup-apps.js") + "\nreturn { shellWords, quoteWord, parseExecLines, wrapperOf, offMarker, hyprlandApps, toggleReplacement, parseUnitFiles, candidateUnits, parseUnitShow, systemdApps, autostartApps, startSummary };")();

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
    assert.ok(off.includes("    hl.exec_cmd(\"~/.config/hypr/scripts/shell-up spotify\") -- off: 'qbittorrent --no-splash'\n"));
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
    assert.ok(on.includes("hl.exec_cmd(\"~/.config/hypr/scripts/shell-up spotify 'qbittorrent --no-splash'\")\n"));
    assert.ok(!on.includes("off:"));
});

test("a comment of the user's on a wrapper line survives being switched", () => {
    const text = "hl.exec_cmd(\"shell-up a b\") -- tray apps\n";
    const row = Startup.hyprlandApps([{ name: "x", text }]).find(r => r.command === "a");
    const off = apply(text, row, Startup.toggleReplacement(row, false));
    assert.strictEqual(off, "hl.exec_cmd(\"shell-up b\") -- off: a | tray apps\n");
    const back = Startup.hyprlandApps([{ name: "x", text: off }]).find(r => r.command === "a");
    assert.deepStrictEqual(Startup.offMarker("off: a | tray apps"), { args: ["a"], foreign: "tray apps" });
    assert.strictEqual(apply(off, back, Startup.toggleReplacement(back, true)), "hl.exec_cmd(\"shell-up b a\") -- tray apps\n");
});

test("single-quoted lua strings and escaped quotes are written back as they came", () => {
    const text = "hl.exec_cmd('shell-up \"x y\" z')\n";
    const row = Startup.hyprlandApps([{ name: "x", text }]).find(r => r.command === "x y");
    assert.ok(row);
    assert.strictEqual(apply(text, row, Startup.toggleReplacement(row, false)), "hl.exec_cmd('shell-up z') -- off: 'x y'\n");
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

test("the summary counts what starts out of what is listed", () => {
    const rows = [{ on: true }, { on: true }, { on: false }];
    assert.strictEqual(Startup.startSummary(rows), "2 of 3 start");
    assert.strictEqual(Startup.startSummary(rows.slice(0, 2)), "all 2 start");
    assert.strictEqual(Startup.startSummary([]), "nothing to start yet");
});
