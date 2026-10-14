const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const FIXTURES = path.join(__dirname, "fixtures/apps");
const src = fs.readFileSync(path.join(ROOT, "services/desktop-entries.js"), "utf8");
const Entries = new Function(src + "\nreturn { unescapeValue, escapeValue, parseEntry, parseBundle, indexEntries, indexPrograms, programOf, stripFieldCodes, shownIn, setHidden, autostartText, autostartName, sessionLaunches, splitList, idOf };")();

function bundleOf(dir) {
    return fs.readdirSync(dir).filter(f => f.endsWith(".desktop")).sort().map(f => `@@@${f}\n${fs.readFileSync(path.join(dir, f), "utf8")}`).join("");
}

test("a desktop entry parses its own section and ignores actions and translations", () => {
    const entry = Entries.parseEntry(fs.readFileSync(path.join(FIXTURES, "applications/firefox.desktop"), "utf8"));
    assert.strictEqual(entry.name, "Firefox");
    assert.strictEqual(entry.exec, "/usr/lib/firefox/firefox %u");
    assert.deepStrictEqual(entry.categories, ["Network", "WebBrowser"]);
    assert.ok(entry.mimeTypes.includes("x-scheme-handler/https"));
    assert.strictEqual(entry.terminal, false);
});

test("text without a desktop entry section is not an entry", () => {
    assert.strictEqual(Entries.parseEntry("[Desktop Action x]\nName=x\n"), null);
    assert.strictEqual(Entries.parseEntry(""), null);
});

test("lists split on semicolons and keep escaped ones", () => {
    assert.deepStrictEqual(Entries.splitList("a;b\\;c;;d;"), ["a", "b;c", "d"]);
});

test("a bundle of files turns into an index keyed by file name, first one winning, hidden ones left out", () => {
    const early = "@@@firefox.desktop\n[Desktop Entry]\nName=Mine\nExec=mine\n";
    const bundle = Entries.parseBundle(early + bundleOf(path.join(FIXTURES, "applications")));
    const index = Entries.indexEntries(bundle);
    assert.strictEqual(index.find(e => e.id === "firefox.desktop").name, "Mine");
    assert.ok(!index.some(e => e.id === "hidden.desktop"));
    assert.ok(index.some(e => e.id === "feh.desktop" && e.noDisplay));
});

test("the program of a command skips env, assignments and absolute paths", () => {
    assert.strictEqual(Entries.programOf("env ELECTRON_OZONE_PLATFORM_HINT=auto /usr/bin/vesktop %U"), "vesktop");
    assert.strictEqual(Entries.programOf("~/.config/hypr/scripts/shell-up spotify"), "shell-up");
    assert.strictEqual(Entries.programOf("flatpak run --branch=stable org.mozilla.firefox @@u %u @@"), "org.mozilla.firefox");
    assert.strictEqual(Entries.programOf("\"/opt/My App/bin/app\" --x"), "app");
    assert.strictEqual(Entries.programOf(""), "");
});

test("programs map back to the entry that runs them, and shells stay out of the map", () => {
    const entries = Entries.indexEntries(Entries.parseBundle(bundleOf(path.join(FIXTURES, "applications")) + "@@@wrapped.desktop\n[Desktop Entry]\nName=Wrapped\nExec=sh -c 'thing'\n"));
    const programs = Entries.indexPrograms(entries);
    assert.strictEqual(programs.vesktop.name, "Vesktop");
    assert.strictEqual(programs.firefox.name, "Firefox");
    assert.ok(!("sh" in programs));
});

test("a wrapper in front of an absolute program still maps the program, and the id names the entry as a last resort", () => {
    const wrapped = "@@@vesktop.desktop\n[Desktop Entry]\nName=Vesktop\nExec=/home/x/.local/bin/focus-or-launch \"^vesktop\\$\" /usr/bin/vesktop %U\n@@@odd.desktop\n[Desktop Entry]\nName=Odd\nExec=sh -c 'odd-thing'\n";
    const programs = Entries.indexPrograms(Entries.indexEntries(Entries.parseBundle(wrapped)));
    assert.strictEqual(programs.vesktop.name, "Vesktop");
    assert.strictEqual(programs["focus-or-launch"].name, "Vesktop");
    assert.strictEqual(programs.odd.name, "Odd");
});

test("field codes come off an exec line and a doubled percent stays", () => {
    assert.strictEqual(Entries.stripFieldCodes("firefox %u"), "firefox");
    assert.strictEqual(Entries.stripFieldCodes("app --open %F --x"), "app --open --x");
    assert.strictEqual(Entries.stripFieldCodes("printf 100%% %f"), "printf 100%");
});

test("an entry is shown in a desktop when OnlyShowIn and NotShowIn allow it", () => {
    const only = Entries.parseEntry("[Desktop Entry]\nOnlyShowIn=GNOME;KDE;\n");
    const not = Entries.parseEntry("[Desktop Entry]\nNotShowIn=Hyprland;\n");
    const free = Entries.parseEntry("[Desktop Entry]\nName=x\n");
    assert.strictEqual(Entries.shownIn(only, ["Hyprland"]), false);
    assert.strictEqual(Entries.shownIn(only, ["kde"]), true);
    assert.strictEqual(Entries.shownIn(not, ["Hyprland"]), false);
    assert.strictEqual(Entries.shownIn(free, ["Hyprland"]), true);
});

test("Hidden is set in place, added when missing, and the GNOME flag follows", () => {
    const off = fs.readFileSync(path.join(FIXTURES, "autostart/off.desktop"), "utf8");
    const on = Entries.setHidden(off, false);
    assert.match(on, /^Hidden=false$/m);
    assert.match(on, /^X-GNOME-Autostart-enabled=true$/m);
    assert.strictEqual(Entries.parseEntry(on).hidden, false);
    assert.strictEqual(Entries.parseEntry(on).autostartEnabled, true);

    const bare = "[Desktop Entry]\nName=x\nExec=x\n\n[Desktop Action a]\nName=a\n";
    const added = Entries.setHidden(bare, true);
    assert.strictEqual(added, "[Desktop Entry]\nHidden=true\nName=x\nExec=x\n\n[Desktop Action a]\nName=a\n");
    assert.strictEqual(Entries.setHidden(added, true), added);
    assert.strictEqual(Entries.setHidden(added, false).split("\n")[1], "Hidden=false");
});

test("an autostart file is written from a chosen app, without field codes", () => {
    const text = Entries.autostartText({ name: "Firefox", exec: "firefox %u", icon: "firefox", terminal: false });
    assert.strictEqual(text, "[Desktop Entry]\nType=Application\nName=Firefox\nExec=firefox\nIcon=firefox\nTerminal=false\nHidden=false\n");
    const entry = Entries.parseEntry(text);
    assert.strictEqual(entry.exec, "firefox");
    assert.strictEqual(entry.hidden, false);
    assert.strictEqual(Entries.autostartName("firefox"), "firefox.desktop");
    assert.strictEqual(Entries.autostartName("org.x.App.desktop"), "org.x.App.desktop");
    assert.strictEqual(Entries.autostartName(""), "");
});

test("an exec line with quotes and backslashes survives being written and read", () => {
    const exec = 'sh -c "echo \\"hi\\""';
    const text = Entries.autostartText({ name: "Greeter", exec, icon: "", terminal: false });
    assert.ok(text.includes('Exec=sh -c "echo \\\\"hi\\\\""\n'));
    assert.strictEqual(Entries.parseEntry(text).exec, exec);
    const files = Entries.parseBundle(`@@@greeter.desktop\n${text}`);
    assert.deepStrictEqual(Entries.sessionLaunches(files, ["Hyprland"]), [`exec ${exec}`]);
});

test("a written exec line, run the way a session runs it, does what it says", () => {
    const text = Entries.autostartText({ name: "Greeter", exec: 'sh -c "echo \\"hi\\" %u"', terminal: false });
    const [launch] = Entries.sessionLaunches(Entries.parseBundle(`@@@greeter.desktop\n${text}`), ["Hyprland"]);
    const ran = require("node:child_process").spawnSync("sh", ["-c", launch], { encoding: "utf8" });
    assert.strictEqual(ran.stdout, "hi\n");
});

test("escapes follow the desktop entry spec both ways, and an exec line keeps escapes the spec does not know", () => {
    assert.strictEqual(Entries.escapeValue("a\\b\nc\td"), "a\\\\b\\nc\\td");
    assert.strictEqual(Entries.escapeValue(" lead"), "\\slead");
    assert.strictEqual(Entries.unescapeValue(Entries.escapeValue(" a\\b\n\t\r ")), " a\\b\n\t\r ");
    assert.strictEqual(Entries.parseEntry("[Desktop Entry]\nExec=a \\\\ \\$HOME\n").exec, "a \\ \\$HOME");
    assert.strictEqual(Entries.parseEntry("[Desktop Entry]\nName=a\\$b\nIcon=x\\sy\n").name, "a$b");
});

test("a session launches the enabled autostart entries that suit its desktop", () => {
    const files = Entries.parseBundle(bundleOf(path.join(FIXTURES, "autostart")));
    assert.deepStrictEqual(Entries.sessionLaunches(files, ["Hyprland"]), ["exec remmina -i"]);
    const guarded = Entries.parseBundle("@@@a.desktop\n[Desktop Entry]\nName=a\nExec=a %U\nTryExec=a b\n");
    assert.deepStrictEqual(Entries.sessionLaunches(guarded, ["Hyprland"]), ["command -v 'a b' >/dev/null 2>&1 || exit 0; exec a"]);
    const terminal = Entries.parseBundle("@@@t.desktop\n[Desktop Entry]\nName=t\nExec=t\nTerminal=true\n");
    assert.deepStrictEqual(Entries.sessionLaunches(terminal, ["Hyprland"]), []);
});

test("an autostart entry another source already starts is not started again", () => {
    const text = Entries.autostartText({ name: "Spotify", exec: "spotify", terminal: false });
    const files = Entries.parseBundle(`@@@/home/a/.config/autostart/spotify.desktop\n${text}`);
    assert.deepStrictEqual(Entries.sessionLaunches(files, ["Hyprland"], ["spotify"]), []);
    assert.deepStrictEqual(Entries.sessionLaunches(files, ["Hyprland"], ["vesktop"]), ["exec spotify"]);
});
