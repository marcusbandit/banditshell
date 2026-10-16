const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Search = lib("modules/launcher/search.js", ["suggestions", "sameChord", "legacyChord", "chordText", "hotkeyCommand", "cleanAlias", "aliasTarget", "aliasesById", "withAlias", "fallbackRows", "contentRow", "ENGINES", "FALLBACKS"]);

test.describe("hotkey chords", () => {
    test.it("treats the same keys in another order as the same chord", () => {
        assert.ok(Search.sameChord("SUPER + SHIFT + F", "shift+super+f"));
        assert.ok(!Search.sameChord("SUPER + F", "SUPER + SHIFT + F"));
        assert.ok(!Search.sameChord("", ""));
    });

    test.it("writes the legacy keyword form and a readable form", () => {
        assert.strictEqual(Search.legacyChord("SUPER + SHIFT + F"), "SUPER SHIFT, F");
        assert.strictEqual(Search.chordText("SUPER + ALT + F12"), "Super Alt F12");
        assert.strictEqual(Search.chordText("CTRL + ALT + T"), "Ctrl Alt T");
    });

    test.it("quotes the row id so app names with spaces survive the shell", () => {
        assert.strictEqual(Search.hotkeyCommand("command:lock"), "banditshell panel launcher run 'command:lock'");
        assert.strictEqual(Search.hotkeyCommand("app:Bloons TD 6"), "banditshell panel launcher run 'app:Bloons TD 6'");
        const run = spawnSync("sh", ["-c", Search.hotkeyCommand("app:it's").replace("banditshell panel launcher run", "printf %s")], { encoding: "utf8" });
        assert.strictEqual(run.stdout, "app:it's");
    });
});

test.describe("aliases", () => {
    const ff = { id: "app:firefox", label: "Firefox" };
    const gimp = { id: "app:gimp", label: "GIMP" };

    test.it("finds the row an alias points at, whatever the case and spacing", () => {
        const aliases = { ff, "lock it": { id: "command:lock", label: "Lock screen" } };
        assert.strictEqual(Search.aliasTarget(aliases, " FF "), "app:firefox");
        assert.strictEqual(Search.aliasTarget(aliases, "lock   it"), "command:lock");
        assert.strictEqual(Search.aliasTarget(aliases, "f"), "");
        assert.strictEqual(Search.aliasTarget(aliases, "constructor"), "");
    });

    test.it("gives each row one alias, and a reused alias moves to the new row", () => {
        const before = { ff, g: gimp };
        assert.deepStrictEqual(Search.withAlias(before, "app:firefox", "fx", "Firefox"), { g: gimp, fx: ff });
        assert.deepStrictEqual(Search.withAlias(before, "app:zen", "ff", "Zen"), { ff: { id: "app:zen", label: "Zen" }, g: gimp });
        assert.deepStrictEqual(Search.withAlias(before, "app:firefox", " ", "Firefox"), { g: gimp });
        assert.deepStrictEqual(Search.aliasesById(before), { "app:firefox": "ff", "app:gimp": "g" });
    });
});

test.describe("fallbacks", () => {
    test.it("lists the chosen ones in a fixed order with their search links", () => {
        const rows = Search.fallbackRows({ youtube: true, web: true }, "cat videos", "https://duckduckgo.com/?q=%s");
        assert.deepStrictEqual(rows.map(r => r.id), ["web", "youtube"]);
        assert.strictEqual(rows[0].url, "https://duckduckgo.com/?q=cat%20videos");
        assert.strictEqual(rows[1].url, "https://www.youtube.com/results?search_query=cat%20videos");
        assert.strictEqual(rows[1].label, "Search YouTube for “cat videos”");
    });

    test.it("keeps dollar signs in the typed words as they are", () => {
        const rows = Search.fallbackRows({ web: true }, "cost $& $' $`", "https://duckduckgo.com/?q=%s");
        assert.strictEqual(rows[0].label, "Search the web for “cost $& $' $`”");
    });

    test.it("runs the terminal one instead of opening a link", () => {
        const rows = Search.fallbackRows({ terminal: true }, "ls -la", "");
        assert.strictEqual(rows[0].url, "");
        assert.strictEqual(rows[0].label, "Run “ls -la” in a terminal");
    });

    test.it("every search engine template has a place for the words", () => {
        for (const [template] of Search.ENGINES)
            assert.ok(template.includes("%s"), template);
    });
});

test.describe("search inside files", () => {
    test.it("reads ripgrep's path, line and text", () => {
        assert.deepStrictEqual(Search.contentRow("/home/me/notes/todo.md:12:   buy   milk ", "/home/me"), {
            path: "/home/me/notes/todo.md",
            name: "todo.md",
            line: 12,
            text: "buy milk",
            where: "~/notes"
        });
    });

    test.it("keeps colons that belong to the matched text", () => {
        const row = Search.contentRow("/home/me/a.txt:3:time: 10:30", "/home/me");
        assert.strictEqual(row.text, "time: 10:30");
        assert.strictEqual(row.line, 3);
    });

    test.it("ignores lines that are not matches", () => {
        assert.strictEqual(Search.contentRow("", "/home/me"), null);
        assert.strictEqual(Search.contentRow("rg: some error", "/home/me"), null);
    });
});

const UNINSTALL = path.join(ROOT, "scripts/uninstall-app.sh");

function sandbox(tools, files) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "uninstall-app-"));
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin);
    for (const [name, body] of Object.entries(tools)) {
        fs.writeFileSync(path.join(bin, name), `#!/bin/sh\n${body}\n`);
        fs.chmodSync(path.join(bin, name), 0o755);
    }
    for (const [rel, body] of Object.entries(files)) {
        fs.mkdirSync(path.dirname(path.join(dir, rel)), { recursive: true });
        fs.writeFileSync(path.join(dir, rel), body);
    }
    return dir;
}

function uninstall(args, tools, files) {
    const dir = sandbox(tools, files);
    const env = { PATH: `${path.join(dir, "bin")}:/usr/bin:/bin`, HOME: path.join(dir, "home"), XDG_DATA_HOME: path.join(dir, "home/.local/share"), XDG_DATA_DIRS: path.join(dir, "usr/share") };
    const out = spawnSync("bash", [UNINSTALL, ...args], { env, encoding: "utf8" });
    fs.rmSync(dir, { recursive: true, force: true });
    return { status: out.status, stdout: out.stdout.trim().split(dir).join("$SANDBOX"), stderr: out.stderr.trim() };
}

const DESKTOP = "[Desktop Entry]\nType=Application\nName=Thing\nExec=thing\n";

test.describe("uninstall-app.sh", () => {
    test.it("asks dpkg who owns a system app and removes it through pkexec", () => {
        const tools = { "dpkg-query": 'echo "thing-gtk: $2"', "apt-get": 'echo "Remv thing-gtk [1.0]"', pkexec: "exit 0", pacman: "exit 1" };
        const files = { "usr/share/applications/thing.desktop": DESKTOP };
        assert.strictEqual(uninstall(["find", "thing"], tools, files).stdout, "apt\tthing-gtk\t$SANDBOX/usr/share/applications/thing.desktop");
        assert.strictEqual(uninstall(["plan", "thing"], tools, files).stdout, "pkexec env DEBIAN_FRONTEND=noninteractive apt-get remove -y thing-gtk");
    });

    test.it("refuses when apt would take other packages with it", () => {
        const tools = { "dpkg-query": 'echo "libthing: $2"', "apt-get": 'printf "Remv libthing [1]\\nRemv thing-gtk [1]\\n"', pkexec: "exit 0", pacman: "exit 1" };
        const out = uninstall(["remove", "thing"], tools, { "usr/share/applications/thing.desktop": DESKTOP });
        assert.strictEqual(out.status, 5);
        assert.strictEqual(out.stdout, "other packages need it: thing-gtk");
    });

    test.it("prefers the package over a copy of its desktop file in the home folder", () => {
        const tools = { pacman: '[ "$1" = -Qqo ] && case "$2" in */usr/share/*) echo thing ;; *) exit 1 ;; esac', pkexec: "exit 0" };
        const files = { "home/.local/share/applications/thing.desktop": DESKTOP, "usr/share/applications/thing.desktop": DESKTOP };
        assert.strictEqual(uninstall(["plan", "thing"], tools, files).stdout, "pkexec pacman -Rs --noconfirm thing");
    });

    test.it("hands flatpaks, Steam games and AppImages to their own tools", () => {
        const none = { pacman: "exit 1" };
        const flat = uninstall(["plan", "org.thing.App"], none, { "home/.local/share/flatpak/exports/share/applications/org.thing.App.desktop": `${DESKTOP}X-Flatpak=org.thing.App\n` });
        assert.strictEqual(flat.stdout, "flatpak uninstall -y --noninteractive --user org.thing.App");
        const steam = uninstall(["plan", "Some Game"], none, { "home/.local/share/applications/Some Game.desktop": "[Desktop Entry]\nName=Some Game\nExec=steam steam://rungameid/960090\n" });
        assert.strictEqual(steam.stdout, "xdg-open steam://uninstall/960090");
    });

    test.it("removes only the shortcut for a hand-made entry, and nothing outside home", () => {
        const none = { pacman: "exit 1" };
        assert.strictEqual(uninstall(["find", "mine"], none, { "home/.local/share/applications/mine.desktop": DESKTOP }).stdout, "entry\tmine.desktop\t$SANDBOX/home/.local/share/applications/mine.desktop");
        assert.strictEqual(uninstall(["find", "loose"], none, { "usr/share/applications/loose.desktop": DESKTOP }).status, 3);
        assert.strictEqual(uninstall(["find", "missing"], none, {}).status, 1);
    });

    test.it("finds a desktop file kept in a subfolder, whichever dash is the slash", () => {
        const tools = { pacman: '[ "$1" = -Qqo ] && echo thing', pkexec: "exit 0" };
        const files = { "usr/share/applications/kde-org/thing.desktop": DESKTOP };
        assert.strictEqual(uninstall(["find", "kde-org-thing"], tools, files).stdout, "pacman\tthing\t$SANDBOX/usr/share/applications/kde-org/thing.desktop");
    });

    test.it("says so when pkexec is missing, so the shell can fall back to a terminal", () => {
        const dir = sandbox({ pacman: '[ "$1" = -Qqo ] && echo thing' }, { "usr/share/applications/thing.desktop": DESKTOP });
        const core = path.join(dir, "core");
        fs.mkdirSync(core);
        for (const tool of ["sed", "head", "basename", "grep", "id", "cut", "sort", "tr"])
            fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(core, tool));
        const out = spawnSync("/bin/bash", [UNINSTALL, "remove", "thing"], { env: { PATH: `${path.join(dir, "bin")}:${core}`, HOME: path.join(dir, "home"), XDG_DATA_DIRS: path.join(dir, "usr/share") }, encoding: "utf8" });
        fs.rmSync(dir, { recursive: true, force: true });
        assert.strictEqual(out.status, 4);
    });
});

test.describe("tab completion", () => {
    test.it("offers the phrase while its first words are typed", () => {
        assert.deepStrictEqual(Search.suggestions("days u", {}), ["days until "]);
        assert.ok(Search.suggestions("da", {}).includes("days since "));
        assert.deepStrictEqual(Search.suggestions("x", {}), []);
    });

    test.it("offers what can follow the phrase, narrowed by what is typed", () => {
        assert.ok(Search.suggestions("days until ", {}).includes("days until christmas"));
        assert.deepStrictEqual(Search.suggestions("days until chr", {}), ["days until christmas", "days until christmas eve"]);
        assert.deepStrictEqual(Search.suggestions("days until christmas eve", {}), []);
    });

    test.it("fills places, workspaces and apps from what the shell knows", () => {
        assert.deepStrictEqual(Search.suggestions("time in to", { places: ["Tokyo", "Toronto", "Oslo"] }), ["time in tokyo", "time in toronto"]);
        assert.deepStrictEqual(Search.suggestions("focus workspace ", { workspaces: ["1", "6"] }), ["focus workspace 1", "focus workspace 6"]);
        assert.deepStrictEqual(Search.suggestions("time in", {}), []);
    });
});
