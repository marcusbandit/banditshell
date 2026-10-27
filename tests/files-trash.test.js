const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

process.env.TZ = "Europe/Copenhagen";

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Trash = lib("services/files-trash.js", ["within", "trashed", "topdirs", "readCommand", "parse", "entries", "infoPath", "restoreCommand"]);

const UID = process.getuid();

function sandbox() {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "files-trash-"));
    const bin = path.join(dir, "bin");
    fs.mkdirSync(bin);
    for (const tool of ["mv", "mkdir", "rm", "cat", "id", "awk"])
        fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(bin, tool));
    const lister = path.join(bin, "bs-ls");
    fs.writeFileSync(lister, `#!/bin/sh
exec ${JSON.stringify(process.execPath)} -e 'const fs = require("fs"); const d = process.argv[1]; console.log(JSON.stringify({path: d, ok: true, entries: fs.readdirSync(d).map(name => ({name, kind: fs.statSync(d + "/" + name).isDirectory() ? "dir" : "file", hidden: name[0] === "."}))}))' "$1"
`);
    fs.chmodSync(lister, 0o755);
    const put = (trash, name, info, body = name) => {
        fs.mkdirSync(path.join(trash, "info"), { recursive: true });
        fs.mkdirSync(path.join(trash, "files"), { recursive: true });
        if (info !== null)
            fs.writeFileSync(path.join(trash, "info", `${name}.trashinfo`), info);
        fs.writeFileSync(path.join(trash, "files", name), body);
    };
    return {
        dir,
        lister,
        home: path.join(dir, "data", "Trash"),
        at: (...parts) => path.join(dir, ...parts),
        put,
        run: argv => spawnSync("/bin/sh", argv.slice(1), { env: { PATH: bin }, encoding: "utf8" }).stdout,
        done: () => fs.rmSync(dir, { recursive: true, force: true })
    };
}

const info = (where, when = "2026-10-25T22:34:34") => `[Trash Info]\nPath=${where}\nDeletionDate=${when}\n`;

test.describe("files trash", () => {
    test.it("knows what is inside the trash and which folders could hold a drive's trash", () => {
        assert.ok(Trash.within("/h/.local/share/Trash/files", "/h/.local/share/Trash/files"));
        assert.ok(Trash.within("/h/.local/share/Trash/files/old folder", "/h/.local/share/Trash/files"));
        assert.ok(!Trash.within("/h/.local/share/Trash/filesystem", "/h/.local/share/Trash/files"));
        assert.ok(Trash.trashed("/mnt/disk/.Trash-1000/files/clip.mkv", "/h/.local/share/Trash/files"));
        assert.ok(Trash.trashed("/mnt/disk/.Trash/1000/files/clip.mkv", "/h/.local/share/Trash/files"));
        assert.ok(!Trash.trashed("/mnt/disk/media/clip.mkv", "/h/.local/share/Trash/files"));
        assert.deepStrictEqual(Trash.topdirs(["/mnt/disk/a/x.mkv", "/mnt/disk/b"]), ["/mnt/disk/a", "/mnt/disk", "/mnt", "/"]);
    });

    test.it("reads the home trash and each drive's trash into where things came from", () => {
        const box = sandbox();
        try {
            box.put(box.home, "notes.txt", info("/h/Documents/My%20Notes%20%C3%A9.txt"));
            box.put(box.home, "new\nline", info("/h/new%0Aline", "2026-10-26T08:00:00"));
            box.put(box.home, "junk", "Path=/h/junk\n");
            box.put(box.home, ".env", info("/h/project/.env"));
            box.put(box.home, "empty", "");
            box.put(box.home, "bad", info("/h/bad%ZZ"));
            box.put(box.at("drive", `.Trash-${UID}`), "clip.mkv", info("media/clip.mkv"));
            fs.mkdirSync(box.at("drive", ".Trash"), { mode: 0o1777 });
            fs.chmodSync(box.at("drive", ".Trash"), 0o1777);
            box.put(box.at("drive", ".Trash", String(UID)), "shared", info("shared"));
            fs.mkdirSync(box.at("loose", ".Trash"), { recursive: true });
            box.put(box.at("loose", ".Trash", String(UID)), "planted", info("planted"));

            const { items, listings } = Trash.parse(box.run(Trash.readCommand("-", box.home, [box.at("drive"), box.at("loose"), box.at("nothing")])));
            assert.deepStrictEqual(listings, []);
            const byName = Object.fromEntries(items.map(item => [item.name, item]));
            assert.deepStrictEqual(Object.keys(byName).sort(), [".env", "bad", "clip.mkv", "junk", "new\nline", "notes.txt", "shared"]);
            assert.strictEqual(byName[".env"].path, "/h/project/.env");
            assert.deepStrictEqual(byName["notes.txt"], { dir: box.home, name: "notes.txt", path: "/h/Documents/My Notes é.txt", deleted: Date.UTC(2026, 9, 25, 22, 34, 34) / 1000 });
            assert.strictEqual(byName["new\nline"].path, "/h/new\nline");
            assert.strictEqual(byName.junk.path, "");
            assert.strictEqual(byName.bad.path, "");
            assert.strictEqual(byName["clip.mkv"].path, box.at("drive", "media", "clip.mkv"));
            assert.strictEqual(byName.shared.path, box.at("drive", "shared"));
        } finally {
            box.done();
        }
    });

    test.it("lists the trash under the names and folders things came from", () => {
        const box = sandbox();
        try {
            box.put(box.home, "a.txt", info("/h/Documents/a.txt"));
            box.put(box.home, "a.2.txt", info("/h/Music/a.txt"));
            box.put(box.home, "stray", null);
            box.put(box.at("drive", `.Trash-${UID}`), "clip.mkv", info("media/clip.mkv"));

            const listed = Trash.entries(Trash.parse(box.run(Trash.readCommand(box.lister, box.home, [box.at("drive")]))));
            const shown = listed.map(e => [e.name, e.dir, e.key]).sort();
            assert.deepStrictEqual(shown, [
                ["a.txt", "/h/Documents", path.join(box.home, "files", "a.txt")],
                ["a.txt", "/h/Music", path.join(box.home, "files", "a.2.txt")],
                ["clip.mkv", box.at("drive", "media"), box.at("drive", `.Trash-${UID}`, "files", "clip.mkv")],
                ["stray", "", path.join(box.home, "files", "stray")]
            ]);
            const music = listed.find(e => e.dir === "/h/Music");
            assert.deepStrictEqual(music.trash, { dir: box.home, name: "a.2.txt", path: "/h/Music/a.txt", deleted: Date.UTC(2026, 9, 25, 22, 34, 34) / 1000 });
            assert.strictEqual(Trash.infoPath(music.trash), path.join(box.home, "info", "a.2.txt.trashinfo"));
            assert.deepStrictEqual(Trash.entries(Trash.parse(box.run(Trash.readCommand(box.lister, box.at("empty"), [])))), []);
        } finally {
            box.done();
        }
    });

    test.it("restores to where things came from, making the folder again, never over something newer", () => {
        const box = sandbox();
        try {
            const odd = ["two words", "it's \"quoted\"", "-dash", "$(touch pwned)"];
            for (const name of odd)
                box.put(box.home, name, info(encodeURIComponent(box.at("gone folder", name)).replace(/%2F/g, "/")));
            box.put(box.home, "taken.txt", info(box.at("taken.txt")));
            fs.writeFileSync(box.at("taken.txt"), "newer");
            box.put(box.home, "vanished", info(box.at("vanished")));
            fs.rmSync(path.join(box.home, "files", "vanished"));
            box.put(box.home, "nowhere", "junk");

            const items = Trash.parse(box.run(Trash.readCommand("-", box.home, []))).items;
            const order = [...odd, "taken.txt", "vanished", "nowhere"].map(name => items.find(item => item.name === name));
            const said = box.run(Trash.restoreCommand([...order, null])).trim().split("\n");

            assert.deepStrictEqual(said, ["ok", "ok", "ok", "ok", "taken", "gone", "failed", "gone"]);
            for (const name of odd)
                assert.strictEqual(fs.readFileSync(box.at("gone folder", name), "utf8"), name);
            assert.strictEqual(fs.readFileSync(box.at("taken.txt"), "utf8"), "newer");
            assert.deepStrictEqual(fs.readdirSync(path.join(box.home, "files")).sort(), ["nowhere", "taken.txt"]);
            assert.deepStrictEqual(fs.readdirSync(path.join(box.home, "info")).sort(), ["nowhere.trashinfo", "taken.txt.trashinfo", "vanished.trashinfo"]);
            assert.ok(!fs.existsSync(box.at("bin", "pwned")) && !fs.existsSync(path.join(process.cwd(), "pwned")));
        } finally {
            box.done();
        }
    });
});
