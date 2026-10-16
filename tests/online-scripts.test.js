const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const zlib = require("node:zlib");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const UNINSTALL = path.join(ROOT, "scripts/uninstall-app.sh");
const SEARCH = path.join(ROOT, "scripts/package-search.sh");
const FLATPAK_INDEX = path.join(ROOT, "scripts/flatpak-index.py");
const PLACES = path.join(ROOT, "scripts/browser-places.py");

function scratch() {
    return fs.mkdtempSync(path.join(os.tmpdir(), "online-scripts-"));
}

function stubs(dir, tools) {
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin, { recursive: true });
    for (const [name, body] of Object.entries(tools)) {
        fs.writeFileSync(path.join(bin, name), `#!/bin/sh\n${body}\n`);
        fs.chmodSync(path.join(bin, name), 0o755);
    }
    return bin;
}

function core(dir, tools) {
    const where = path.join(dir, "core");
    fs.mkdirSync(where, { recursive: true });
    for (const tool of tools)
        fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(where, tool));
    return where;
}

test.describe("uninstall-app.sh --package", () => {
    function plan(args, tools) {
        const dir = scratch();
        const bin = stubs(dir, tools);
        const base = core(dir, ["sed", "head", "basename", "grep", "id", "cut", "sort", "tr"]);
        const out = spawnSync("/bin/bash", [UNINSTALL, ...args], { env: { PATH: `${bin}:${base}`, BANDITSHELL_SYSTEM_PATH: `${bin}:${base}`, HOME: path.join(dir, "home") }, encoding: "utf8" });
        fs.rmSync(dir, { recursive: true, force: true });
        return { status: out.status, stdout: out.stdout.trim() };
    }

    test.it("removes a named package without looking for a desktop file", () => {
        assert.deepStrictEqual(plan(["plan", "--package", "pacman", "ripgrep"], { pkexec: "exit 0" }), { status: 0, stdout: "pkexec pacman -Rs --noconfirm -- ripgrep" });
        assert.deepStrictEqual(plan(["plan", "--package", "flatpak-user", "com.spotify.Client"], {}), { status: 0, stdout: "flatpak uninstall -y --noninteractive --user -- com.spotify.Client" });
        assert.deepStrictEqual(plan(["find", "--package", "apt", "ripgrep"], {}), { status: 0, stdout: "apt\tripgrep" });
    });

    test.it("refuses kinds that only make sense for a desktop file", () => {
        assert.strictEqual(plan(["plan", "--package", "steam", "960090"], {}).status, 2);
        assert.strictEqual(plan(["plan", "--package", "pacman"], {}).status, 2);
        assert.strictEqual(plan(["plan", "--package", "pacman", "-Rdd"], {}).status, 2);
        assert.strictEqual(plan(["plan", "--package", "pacman", "a;b"], {}).status, 2);
    });

    test.it("reports the manager's own failure as one code of its own", () => {
        assert.strictEqual(plan(["remove", "--package", "zypper", "thing"], { zypper: "exit 4", pkexec: '"$@"' }).status, 10);
        assert.strictEqual(plan(["remove", "--package", "pacman", "thing"], { pacman: "exit 1", pkexec: '"$@"' }).status, 10);
        assert.strictEqual(plan(["remove", "--package", "pacman", "thing"], { pacman: "exit 0", pkexec: "exit 126" }).status, 126);
        assert.strictEqual(plan(["remove", "--package", "pacman", "thing"], { pacman: "exit 0", pkexec: '"$@"' }).status, 0);
    });
});

test.describe("package-search.sh", () => {
    function search(args, tools) {
        const dir = scratch();
        const bin = stubs(dir, tools);
        const base = core(dir, ["cut", "sed", "head", "grep"]);
        const out = spawnSync("/bin/bash", [SEARCH, ...args], { env: { PATH: `${bin}:${base}` }, encoding: "utf8" });
        fs.rmSync(dir, { recursive: true, force: true });
        return out;
    }

    test.it("lists the tools it can use", () => {
        assert.deepStrictEqual(search(["tools"], { pacman: "exit 0", flatpak: "exit 0", paru: "exit 0" }).stdout.trim().split("\n"), ["pacman", "flatpak", "paru"]);
    });

    test.it("searches pacman first and labels the section", () => {
        const out = search(["system", "rip grep"], { pacman: 'printf "extra/ripgrep 15-1\\n    %s\\n" "$*"', "apt-cache": "echo nope" });
        assert.strictEqual(out.stdout, "@@ pacman\nextra/ripgrep 15-1\n    -Ss -- rip grep\n");
    });

    test.it("hands pacman each word as a literal pattern", () => {
        const out = search(["system", "c++ (gtk"], { pacman: 'printf "%s|" "$@"' });
        assert.strictEqual(out.stdout, "@@ pacman\n-Ss|--|c\\+\\+|\\(gtk|");
    });

    test.it("adds the apt policy for what apt found", () => {
        const out = search(["system", "ripgrep"], { "apt-cache": '[ "$1" = search ] && echo "ripgrep - grep" || printf "%s\\n" "$*"' });
        assert.strictEqual(out.stdout, "@@ apt\nripgrep - grep\n@@ apt-policy\npolicy -- ripgrep\n");
    });

    test.it("asks the AUR with the term encoded and lists what is foreign", () => {
        const out = search(["aur", "c++ tools"], { pacman: 'echo "paru 2.0-1"', curl: 'printf "%s\\n" "$*"' });
        assert.strictEqual(out.status, 0);
        assert.ok(out.stdout.startsWith("@@ foreign\nparu 2.0-1\n@@ aur\n"));
        assert.ok(out.stdout.includes("--data-urlencode arg=c++ tools"));
        assert.strictEqual(search(["aur", "x"], { curl: "exit 0" }).status, 3);
    });
});

test.describe("flatpak-index.py", () => {
    test.it("indexes desktop apps from each remote with their cached icons", () => {
        const dir = scratch();
        const active = path.join(dir, "system/appstream/flathub/x86_64/active");
        fs.mkdirSync(path.join(active, "icons/64x64"), { recursive: true });
        fs.writeFileSync(path.join(active, "icons/64x64/com.example.Notes.png"), "png");
        const xml = `<?xml version="1.0"?><components>
            <component type="desktop-application"><id>com.example.Notes</id><name>Notes</name><name xml:lang="de">Notizen</name><summary>Write things</summary>
                <icon type="cached" height="64" width="64">com.example.Notes.png</icon><releases><release version="2.1"/><release version="2.0"/></releases></component>
            <component type="runtime"><id>org.example.Platform</id><name>Platform</name></component>
            <component type="desktop-application"><id>-rf.Evil</id><name>Evil</name></component>
        </components>`;
        fs.writeFileSync(path.join(active, "appstream.xml.gz"), zlib.gzipSync(xml));
        const target = path.join(dir, "out/index.json");
        const env = { PATH: "/usr/bin:/bin", HOME: dir, FLATPAK_SYSTEM_DIR: path.join(dir, "system"), FLATPAK_USER_DIR: path.join(dir, "user") };
        const run = spawnSync("python3", ["-I", FLATPAK_INDEX, target], { env, encoding: "utf8" });
        assert.strictEqual(run.status, 0, run.stderr);
        const index = JSON.parse(fs.readFileSync(target, "utf8"));
        assert.deepStrictEqual(index.apps, [{ id: "com.example.Notes", name: "Notes", summary: "Write things", version: "2.1", remote: "flathub", installation: "system", icon: path.join(active, "icons/64x64/com.example.Notes.png") }]);
        const again = spawnSync("python3", ["-I", FLATPAK_INDEX, target], { env, encoding: "utf8" });
        assert.strictEqual(again.status, 0);
        assert.strictEqual(fs.statSync(target).mode & 0o777, 0o600);
        assert.strictEqual(fs.statSync(path.dirname(target)).mode & 0o777, 0o700);
        fs.rmSync(dir, { recursive: true, force: true });
    });
});

test.describe("browser-places.py", () => {
    test.it("reads Firefox bookmarks and history in place, read only, into private files", () => {
        const dir = scratch();
        const profile = path.join(dir, "home/.mozilla/firefox/abc.default");
        fs.mkdirSync(profile, { recursive: true });
        const db = path.join(profile, "places.sqlite");
        const made = spawnSync("python3", ["-I", "-c", `
import sqlite3, sys
c = sqlite3.connect(sys.argv[1])
c.executescript("""
CREATE TABLE moz_places (id INTEGER PRIMARY KEY, url TEXT, title TEXT, visit_count INTEGER, hidden INTEGER, frecency INTEGER, last_visit_date INTEGER);
CREATE TABLE moz_bookmarks (id INTEGER PRIMARY KEY, type INTEGER, fk INTEGER, title TEXT);
INSERT INTO moz_places VALUES (1, 'https://www.example.com/', 'Example', 5, 0, 100, 1700000000000000);
INSERT INTO moz_places VALUES (2, 'https://news.ycombinator.com/', 'Hacker News', 40, 0, 900, 1700000000000000);
INSERT INTO moz_places VALUES (3, 'place:sort=8', 'Recent', 0, 0, 0, 0);
INSERT INTO moz_bookmarks VALUES (1, 1, 1, 'My example');
INSERT INTO moz_bookmarks VALUES (2, 2, NULL, 'Folder');
""")
c.commit()
`, db], { encoding: "utf8" });
        assert.strictEqual(made.status, 0, made.stderr);
        const before = fs.statSync(db).mtimeMs;
        const target = path.join(dir, "cache/places.json");
        const env = { PATH: "/usr/bin:/bin", HOME: path.join(dir, "home"), XDG_CONFIG_HOME: path.join(dir, "home/.config"), TMPDIR: dir };
        const run = spawnSync("python3", ["-I", PLACES, target, path.join(dir, "cache/icons")], { env, encoding: "utf8" });
        assert.strictEqual(run.status, 0, run.stderr);
        const places = JSON.parse(fs.readFileSync(target, "utf8")).places;
        assert.deepStrictEqual(places.map(p => [p.title, p.host, p.bookmark, p.visits]), [["My example", "example.com", true, 5], ["Hacker News", "news.ycombinator.com", false, 40]]);
        assert.strictEqual(fs.statSync(db).mtimeMs, before);
        assert.deepStrictEqual(fs.readdirSync(dir).filter(n => n.startsWith("banditshell-places-")), []);
        assert.strictEqual(fs.statSync(target).mode & 0o777, 0o600);
        assert.strictEqual(fs.statSync(path.dirname(target)).mode & 0o777, 0o700);
        fs.rmSync(dir, { recursive: true, force: true });
    });
});
