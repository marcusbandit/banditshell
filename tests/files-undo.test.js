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

const Undo = lib("services/files-undo.js", [
    "LIMIT", "into", "moved", "renamed", "copied", "trashed", "remember",
    "existsCommand", "existing", "parseTrash", "pick", "command", "outcome", "summary"
]);

const LISTING = fs.readFileSync(path.join(ROOT, "tests/fixtures/gio-trash-list.txt"), "utf8");

function local(y, mo, d, h, mi, s) {
    return new Date(y, mo - 1, d, h, mi, s).getTime() / 1000;
}

function sandbox() {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "files-undo-"));
    const bin = path.join(dir, "bin");
    const trash = path.join(dir, "trash");
    fs.mkdirSync(bin);
    fs.mkdirSync(trash);
    for (const tool of ["mv", "mkdir", "rm", "cp", "cat"])
        fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(bin, tool));
    fs.writeFileSync(path.join(bin, "gio"), `#!/bin/sh
echo "$*" >> "${dir}/gio.log"
if [ "$1 $2" = "trash --restore" ]; then
    shift 3
    [ -e "${trash}/$1" ] || exit 1
    [ -e "$(cat "${trash}/$1.origin")" ] && exit 1
    mv -- "${trash}/$1" "$(cat "${trash}/$1.origin")" && rm -- "${trash}/$1.origin"
    exit
fi
[ "$1 $2" = "trash --" ] || exit 2
shift 2
for p; do n=$(printf %s "$p" | cksum | cut -d" " -f1); mv -- "$p" "${trash}/$n" && printf %s "$p" > "${trash}/$n.origin"; done
`);
    fs.chmodSync(path.join(bin, "gio"), 0o755);
    fs.symlinkSync(spawnSync("sh", ["-c", "command -v cksum"], { encoding: "utf8" }).stdout.trim(), path.join(bin, "cksum"));
    fs.symlinkSync(spawnSync("sh", ["-c", "command -v cut"], { encoding: "utf8" }).stdout.trim(), path.join(bin, "cut"));
    const home = path.join(dir, "home");
    fs.mkdirSync(home);
    return {
        home,
        trash,
        at: (...parts) => path.join(home, ...parts),
        run: argv => {
            const out = spawnSync("/bin/sh", argv.slice(1), { env: { PATH: bin }, encoding: "utf8" });
            return out.stdout;
        },
        gio: () => fs.existsSync(path.join(dir, "gio.log")) ? fs.readFileSync(path.join(dir, "gio.log"), "utf8") : "",
        done: () => fs.rmSync(dir, { recursive: true, force: true })
    };
}

const ODD = ["plain.txt", "two words", "it's \"quoted\"", "-leading-dash", "new\nline", "tab\there", "$(touch pwned)"];

test.describe("files undo", () => {
    test.it("pairs each path with where it lands in the folder, skipping ones already there", () => {
        assert.deepStrictEqual(Undo.into(["/a/x.txt", "/b/dir/", "/c/y"], "/c"), [
            { from: "/a/x.txt", to: "/c/x.txt" },
            { from: "/b/dir/", to: "/c/dir" }
        ]);
        assert.deepStrictEqual(Undo.into(["/x"], "/"), []);
        assert.deepStrictEqual(Undo.into(["/a/x"], "/"), [{ from: "/a/x", to: "/x" }]);
    });

    test.it("keeps the newest entries on top and drops nothing-entries", () => {
        let stack = [];
        stack = Undo.remember(stack, Undo.renamed("/a/x", "/a/x"));
        stack = Undo.remember(stack, Undo.moved([]));
        assert.strictEqual(stack.length, 0);
        for (let i = 0; i < Undo.LIMIT + 5; i++)
            stack = Undo.remember(stack, Undo.renamed(`/a/${i}`, `/a/${i}.bak`));
        assert.strictEqual(stack.length, Undo.LIMIT);
        assert.strictEqual(stack[stack.length - 1].pairs[0].from, `/a/${Undo.LIMIT + 4}`);
    });

    test.it("never records a pasted copy whose name was already there before the paste", () => {
        const pairs = Undo.into(["/a/keep", "/a/new"], "/b");
        assert.deepStrictEqual(Undo.copied(pairs, ["/b/keep"]).pairs, [{ from: "/a/new", to: "/b/new" }]);
    });

    test.it("finds which paste targets already exist, odd names and dangling links included", () => {
        const box = sandbox();
        try {
            fs.writeFileSync(box.at(ODD[1]), "");
            fs.writeFileSync(box.at(ODD[4]), "");
            fs.symlinkSync(box.at("nowhere"), box.at("dangling"));
            const targets = [...ODD, "dangling"].map(name => box.at(name));
            assert.deepStrictEqual(Undo.existing(targets, box.run(Undo.existsCommand(targets))), [box.at(ODD[1]), box.at(ODD[4]), box.at("dangling")]);
            assert.ok(!fs.existsSync(path.join(process.cwd(), "pwned")));
        } finally {
            box.done();
        }
    });

    test.it("moves files and folders back to where they came from", () => {
        const box = sandbox();
        try {
            fs.mkdirSync(box.at("into"));
            fs.mkdirSync(box.at("folder"));
            fs.writeFileSync(box.at("folder", "inside"), "kept");
            for (const name of ODD)
                fs.writeFileSync(box.at(name), name);
            const paths = [...ODD, "folder"].map(name => box.at(name));
            const entry = Undo.moved(Undo.into(paths, box.at("into")));
            box.run(["sh", "-c", 'd=$1; shift; mv -- "$@" "$d"', "sh", box.at("into"), ...paths]);
            assert.ok(!fs.existsSync(box.at(ODD[0])));

            const counts = Undo.outcome(box.run(Undo.command(entry, [])));
            assert.deepStrictEqual(counts, { ok: ODD.length + 1, gone: 0, taken: 0, failed: 0, total: ODD.length + 1 });
            for (const name of ODD)
                assert.strictEqual(fs.readFileSync(box.at(name), "utf8"), name);
            assert.strictEqual(fs.readFileSync(box.at("folder", "inside"), "utf8"), "kept");
            assert.deepStrictEqual(fs.readdirSync(box.at("into")), []);
            assert.strictEqual(Undo.summary(entry, counts), `${ODD.length + 1} files moved back`);
        } finally {
            box.done();
        }
    });

    test.it("renames back, and never overwrites something that took the old name since", () => {
        const box = sandbox();
        try {
            fs.writeFileSync(box.at("draft.txt"), "mine");
            fs.renameSync(box.at("draft.txt"), box.at("final.txt"));
            const entry = Undo.renamed(box.at("draft.txt"), box.at("final.txt"));
            fs.writeFileSync(box.at("draft.txt"), "newer");

            const blocked = Undo.outcome(box.run(Undo.command(entry, [])));
            assert.deepStrictEqual([blocked.ok, blocked.taken], [0, 1]);
            assert.strictEqual(fs.readFileSync(box.at("draft.txt"), "utf8"), "newer");
            assert.strictEqual(fs.readFileSync(box.at("final.txt"), "utf8"), "mine");
            assert.strictEqual(Undo.summary(entry, blocked), "draft.txt not brought back, the name is taken");

            fs.unlinkSync(box.at("draft.txt"));
            const counts = Undo.outcome(box.run(Undo.command(entry, [])));
            assert.strictEqual(counts.ok, 1);
            assert.strictEqual(fs.readFileSync(box.at("draft.txt"), "utf8"), "mine");
            assert.strictEqual(Undo.summary(entry, counts), "Renamed back to draft.txt");
        } finally {
            box.done();
        }
    });

    test.it("says the file is gone when a moved file was deleted since", () => {
        const box = sandbox();
        try {
            const entry = Undo.moved([{ from: box.at("a"), to: box.at("b") }]);
            const counts = Undo.outcome(box.run(Undo.command(entry, [])));
            assert.deepStrictEqual([counts.ok, counts.gone], [0, 1]);
            assert.strictEqual(Undo.summary(entry, counts), "a is no longer where it was moved");
        } finally {
            box.done();
        }
    });

    test.it("takes back a paste by trashing only the copies it made", () => {
        const box = sandbox();
        try {
            fs.mkdirSync(box.at("from"));
            fs.mkdirSync(box.at("to"));
            for (const name of ["one", "two words", "old"])
                fs.writeFileSync(box.at("from", name), name);
            fs.writeFileSync(box.at("to", "old"), "was here first");
            const sources = ["one", "two words", "old"].map(name => box.at("from", name));
            const pairs = Undo.into(sources, box.at("to"));
            const targets = pairs.map(pair => pair.to);
            const entry = Undo.copied(pairs, Undo.existing(targets, box.run(Undo.existsCommand(targets))));
            box.run(["sh", "-c", 'd=$1; shift; cp -rn -- "$@" "$d"', "sh", box.at("to"), ...sources]);

            const counts = Undo.outcome(box.run(Undo.command(entry, [])));
            assert.strictEqual(counts.ok, 2);
            assert.deepStrictEqual(fs.readdirSync(box.at("to")), ["old"]);
            assert.strictEqual(fs.readFileSync(box.at("to", "old"), "utf8"), "was here first");
            assert.deepStrictEqual(fs.readdirSync(box.at("from")).sort(), ["old", "one", "two words"]);
            assert.strictEqual(fs.readdirSync(box.trash).length, 4);
            assert.strictEqual(Undo.summary(entry, counts), "2 copies moved to the trash");
        } finally {
            box.done();
        }
    });

    test.it("reads the trash listing gio prints, unescaping the bytes in its paths", () => {
        const items = Undo.parseTrash(LISTING);
        assert.strictEqual(items.length, 6);
        assert.deepStrictEqual(items[0], { uri: "trash:///notes.txt", path: "/home/user/Documents/notes.txt", deleted: local(2026, 10, 25, 22, 34, 34) });
        assert.strictEqual(items[2].path, "/home/user/a b\tt é \"q\".txt");
        assert.strictEqual(items[3].path, "/home/user/back\\slash");
        assert.strictEqual(items[4].path, "/home/user/Documents/My Old Notes");
        assert.strictEqual(items[5].path, "/mnt/disk/media/clip.mkv");
        assert.deepStrictEqual(Undo.parseTrash("gio: trash:///: Operation not supported\n"), []);
    });

    test.it("picks the trash item deleted by this very delete, not an older or later one", () => {
        const items = Undo.parseTrash(LISTING);
        const first = Undo.trashed(["/home/user/Documents/notes.txt"], local(2026, 10, 25, 22, 34, 33) + 0.4);
        const second = Undo.trashed(["/home/user/Documents/notes.txt"], local(2026, 10, 25, 22, 40, 1) + 0.8);
        assert.deepStrictEqual(Undo.pick(items, first), ["trash:///notes.txt"]);
        assert.deepStrictEqual(Undo.pick(items, second), ["trash:///notes.txt.2"]);
        const later = Undo.trashed(["/home/user/Documents/My Old Notes", "/home/user/missing"], local(2026, 10, 25, 22, 0, 0));
        assert.deepStrictEqual(Undo.pick(items, later), ["-", "-"]);
    });

    test.it("restores trashed files through gio and counts what came back", () => {
        const box = sandbox();
        try {
            for (const name of ODD)
                fs.writeFileSync(box.at(name), name);
            const paths = ODD.map(name => box.at(name));
            box.run(["sh", "-c", 'gio trash -- "$@"', "sh", ...paths]);
            assert.deepStrictEqual(fs.readdirSync(box.home), []);
            const uris = fs.readdirSync(box.trash).filter(name => !name.endsWith(".origin"));
            const byPath = Object.fromEntries(uris.map(uri => [fs.readFileSync(path.join(box.trash, `${uri}.origin`), "utf8"), uri]));
            const entry = Undo.trashed(paths, 0);
            fs.writeFileSync(box.at(ODD[0]), "made again");

            const counts = Undo.outcome(box.run(Undo.command(entry, [...paths.slice(0, -1).map(p => byPath[p]), "-"])));
            assert.deepStrictEqual(counts, { ok: ODD.length - 2, gone: 1, taken: 1, failed: 0, total: ODD.length });
            assert.strictEqual(fs.readFileSync(box.at(ODD[0]), "utf8"), "made again");
            for (const name of ODD.slice(1, -1))
                assert.strictEqual(fs.readFileSync(box.at(name), "utf8"), name);
            assert.strictEqual(Undo.summary(entry, counts), `${ODD.length - 2} of ${ODD.length} files restored`);
            assert.ok(box.gio().includes("trash --restore --"));
        } finally {
            box.done();
        }
    });

    test.it("says what came back in a few words", () => {
        const one = Undo.trashed(["/h/report.pdf"], 0);
        const three = Undo.trashed(["/h/a", "/h/b", "/h/c"], 0);
        const all = n => ({ ok: n, gone: 0, taken: 0, failed: 0, total: n });
        assert.strictEqual(Undo.summary(one, all(1)), "report.pdf restored");
        assert.strictEqual(Undo.summary(three, all(3)), "3 files restored");
        assert.strictEqual(Undo.summary(three, { ok: 0, gone: 3, taken: 0, failed: 0, total: 3 }), "Nothing restored, no longer in the trash");
        assert.strictEqual(Undo.summary(one, { ok: 0, gone: 1, taken: 0, failed: 0, total: 1 }), "report.pdf is no longer in the trash");
        assert.strictEqual(Undo.summary(Undo.moved(Undo.into(["/h/a"], "/h/d")), all(1)), "a moved back");
        assert.strictEqual(Undo.summary(Undo.copied(Undo.into(["/h/a"], "/h/d"), []), all(1)), "Copy of a moved to the trash");
        assert.strictEqual(Undo.summary(three, { ok: 0, gone: 0, taken: 0, failed: 0, total: 0 }), "Nothing could be brought back");
        for (const text of [Undo.summary(three, all(3)), Undo.summary(one, { ok: 0, gone: 0, taken: 1, failed: 0, total: 1 })])
            assert.ok(text.length <= 70);
    });
});
