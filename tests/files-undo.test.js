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

const Undo = lib("services/files-undo.js", [
    "LIMIT", "into", "moved", "renamed", "copied", "fresh", "trashed", "remember",
    "existsCommand", "existing", "pick", "command", "outcome", "summary"
]);
const Trash = lib("services/files-trash.js", ["readCommand", "parse", "restoreCommand"]);
const GioTrash = require("./fixtures/gio-trash.js");

function local(y, mo, d, h, mi, s) {
    return new Date(y, mo - 1, d, h, mi, s).getTime() / 1000;
}

function wall(y, mo, d, h, mi, s) {
    return Date.UTC(y, mo - 1, d, h, mi, s) / 1000;
}

function sandbox() {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "files-undo-"));
    const bin = path.join(dir, "bin");
    const trash = path.join(dir, "data", "Trash");
    fs.mkdirSync(bin);
    for (const tool of ["mv", "mkdir", "rm", "cp", "cat", "id"])
        fs.symlinkSync(spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim(), path.join(bin, tool));
    GioTrash.install(bin, trash);
    const home = path.join(dir, "home");
    fs.mkdirSync(home);
    const box = {
        home,
        trash,
        at: (...parts) => path.join(home, ...parts),
        run: argv => {
            const out = spawnSync("/bin/sh", argv.slice(1), { env: { PATH: bin }, encoding: "utf8" });
            return out.stdout;
        },
        undo: entry => box.run(Trash.restoreCommand(Undo.pick(Trash.parse(box.run(Trash.readCommand("-", trash, []))).items, entry))),
        done: () => fs.rmSync(dir, { recursive: true, force: true })
    };
    return box;
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

    test.it("never records a paste, move or rename onto a name that was already there", () => {
        const pairs = Undo.into(["/a/keep", "/a/new"], "/b");
        assert.deepStrictEqual(Undo.fresh(Undo.copied(pairs), ["/b/keep"]), { kind: "copy", pairs: [{ from: "/a/new", to: "/b/new" }] });
        assert.deepStrictEqual(Undo.fresh(Undo.moved(pairs), ["/b/keep"]).pairs, [{ from: "/a/new", to: "/b/new" }]);
        assert.deepStrictEqual(Undo.fresh(Undo.renamed("/a/notes.txt", "/a/Projects"), ["/a/Projects"]).pairs, []);
    });

    test.it("never renames a folder back when a file was renamed into it", () => {
        const box = sandbox();
        try {
            fs.mkdirSync(box.at("Projects"));
            fs.writeFileSync(box.at("Projects", "plan"), "kept");
            fs.writeFileSync(box.at("notes.txt"), "mine");
            const entry = Undo.renamed(box.at("notes.txt"), box.at("Projects"));
            const targets = entry.pairs.map(pair => pair.to);
            const kept = Undo.fresh(entry, Undo.existing(targets, box.run(Undo.existsCommand(targets))));
            box.run(["sh", "-c", 'mv -- "$1" "$2"', "sh", box.at("notes.txt"), box.at("Projects")]);
            assert.deepStrictEqual(Undo.remember([], kept), []);
            assert.strictEqual(fs.readFileSync(box.at("Projects", "plan"), "utf8"), "kept");
        } finally {
            box.done();
        }
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

            const counts = Undo.outcome(entry, box.run(Undo.command(entry, [])));
            assert.deepStrictEqual(counts, { ok: ODD.length + 1, gone: 0, taken: 0, failed: 0, done: paths });
            for (const name of ODD)
                assert.strictEqual(fs.readFileSync(box.at(name), "utf8"), name);
            assert.strictEqual(fs.readFileSync(box.at("folder", "inside"), "utf8"), "kept");
            assert.deepStrictEqual(fs.readdirSync(box.at("into")), []);
            assert.strictEqual(Undo.summary(entry, counts, box.home, "/nowhere"), `${ODD.length + 1} files moved back`);
            assert.strictEqual(Undo.summary(entry, counts, box.at("into"), "/nowhere"), `${ODD.length + 1} files moved back to home`);
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

            const blocked = Undo.outcome(entry, box.run(Undo.command(entry, [])));
            assert.deepStrictEqual([blocked.ok, blocked.taken], [0, 1]);
            assert.strictEqual(fs.readFileSync(box.at("draft.txt"), "utf8"), "newer");
            assert.strictEqual(fs.readFileSync(box.at("final.txt"), "utf8"), "mine");
            assert.strictEqual(Undo.summary(entry, blocked, box.home, "/nowhere"), "draft.txt not brought back, the name is taken");

            fs.unlinkSync(box.at("draft.txt"));
            const counts = Undo.outcome(entry, box.run(Undo.command(entry, [])));
            assert.strictEqual(counts.ok, 1);
            assert.strictEqual(fs.readFileSync(box.at("draft.txt"), "utf8"), "mine");
            assert.strictEqual(Undo.summary(entry, counts, box.home, "/nowhere"), "Renamed back to draft.txt");
        } finally {
            box.done();
        }
    });

    test.it("says the file is gone when a moved file was deleted since", () => {
        const box = sandbox();
        try {
            const entry = Undo.moved([{ from: box.at("a"), to: box.at("b") }]);
            const counts = Undo.outcome(entry, box.run(Undo.command(entry, [])));
            assert.deepStrictEqual([counts.ok, counts.gone], [0, 1]);
            assert.strictEqual(Undo.summary(entry, counts, box.home, "/nowhere"), "a is no longer where it was moved");
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
            const entry = Undo.fresh(Undo.copied(pairs), Undo.existing(targets, box.run(Undo.existsCommand(targets))));
            box.run(["sh", "-c", 'd=$1; shift; cp -rn -- "$@" "$d"', "sh", box.at("to"), ...sources]);

            const counts = Undo.outcome(entry, box.run(Undo.command(entry, [])));
            assert.strictEqual(counts.ok, 2);
            assert.deepStrictEqual(fs.readdirSync(box.at("to")), ["old"]);
            assert.strictEqual(fs.readFileSync(box.at("to", "old"), "utf8"), "was here first");
            assert.deepStrictEqual(fs.readdirSync(box.at("from")).sort(), ["old", "one", "two words"]);
            assert.strictEqual(GioTrash.trashed(box.trash).length, 2);
            assert.strictEqual(Undo.summary(entry, counts, box.at("to"), "/nowhere"), "Copies of one and two words moved to the trash");
        } finally {
            box.done();
        }
    });

    test.it("picks the trash item deleted by this very delete, not an older or later one", () => {
        const notes = "/home/user/Documents/notes.txt";
        const items = [
            { dir: "/t", name: "notes.txt", path: notes, deleted: wall(2026, 10, 25, 22, 34, 34) },
            { dir: "/t", name: "notes.2.txt", path: notes, deleted: wall(2026, 10, 25, 22, 40, 2) },
            { dir: "/t", name: "Old", path: "/home/user/Documents/My Old Notes", deleted: wall(2026, 10, 20, 9, 0, 0) }
        ];
        const first = Undo.trashed([notes], local(2026, 10, 25, 22, 34, 33) + 0.4);
        const second = Undo.trashed([notes], local(2026, 10, 25, 22, 40, 1) + 0.8);
        assert.deepStrictEqual(Undo.pick(items, first), [items[0]]);
        assert.deepStrictEqual(Undo.pick(items, second), [items[1]]);
        assert.deepStrictEqual(Undo.pick(items, Undo.trashed([notes, notes], local(2026, 10, 25, 22, 34, 34))), [items[0], items[1]]);
        const fallBack = [{ dir: "/t", name: "late", path: "/h/late", deleted: wall(2026, 10, 25, 2, 30, 5) }];
        const repeated = local(2026, 10, 25, 2, 30, 4) + 3600;
        assert.strictEqual(new Date(repeated * 1000).getHours(), 2);
        assert.deepStrictEqual(Undo.pick(fallBack, Undo.trashed(["/h/late"], repeated)), [fallBack[0]]);
        const later = Undo.trashed(["/home/user/Documents/My Old Notes", "/home/user/missing"], local(2026, 10, 25, 22, 0, 0));
        assert.deepStrictEqual(Undo.pick(items, later), [null, null]);
    });

    test.it("restores trashed files from the trash folder and counts what came back", () => {
        const box = sandbox();
        try {
            for (const name of ODD)
                fs.writeFileSync(box.at(name), name);
            const paths = ODD.map(name => box.at(name));
            const entry = Undo.trashed(paths, Date.now() / 1000);
            box.run(["sh", "-c", 'gio trash -- "$@"', "sh", ...paths]);
            assert.deepStrictEqual(fs.readdirSync(box.home), []);
            fs.writeFileSync(box.at(ODD[0]), "made again");
            fs.rmSync(path.join(box.trash, "files", ODD[ODD.length - 1]));

            const counts = Undo.outcome(entry, box.undo(entry));
            assert.deepStrictEqual(counts, { ok: ODD.length - 2, gone: 1, taken: 1, failed: 0, done: paths.slice(1, -1) });
            assert.strictEqual(fs.readFileSync(box.at(ODD[0]), "utf8"), "made again");
            for (const name of ODD.slice(1, -1))
                assert.strictEqual(fs.readFileSync(box.at(name), "utf8"), name);
            assert.deepStrictEqual(GioTrash.trashed(box.trash).map(item => item.path).sort(), [ODD[0], ODD[ODD.length - 1]].map(name => box.at(name)).sort());
            assert.strictEqual(Undo.summary(entry, counts, box.home, "/nowhere"), `${ODD.length - 2} files restored, 2 could not be`);
        } finally {
            box.done();
        }
    });

    test.it("restores a file trashed again under the trash name a restore just freed", () => {
        const box = sandbox();
        try {
            for (const body of ["one", "two", "three"]) {
                fs.writeFileSync(box.at("a.txt"), body);
                const entry = Undo.trashed([box.at("a.txt")], Date.now() / 1000);
                box.run(["sh", "-c", 'gio trash -- "$@"', "sh", box.at("a.txt")]);
                assert.deepStrictEqual(GioTrash.trashed(box.trash).map(item => item.name), ["a.txt"]);
                assert.strictEqual(Undo.outcome(entry, box.undo(entry)).ok, 1);
                assert.strictEqual(fs.readFileSync(box.at("a.txt"), "utf8"), body);
                assert.deepStrictEqual(GioTrash.trashed(box.trash), []);
            }
        } finally {
            box.done();
        }
    });

    test.it("names one or two things that came back, and counts past that", () => {
        const back = (entry, done) => ({ ok: done.length, gone: 0, taken: 0, failed: 0, done });
        const one = Undo.trashed(["/h/Documents/notes.txt"], 0);
        const two = Undo.trashed(["/h/Documents/notes.txt", "/h/Documents/plan.md"], 0);
        const three = Undo.trashed(["/h/Documents/a", "/h/Documents/b", "/h/Documents/c"], 0);
        assert.strictEqual(Undo.summary(one, back(one, one.paths), "/h/Documents", "/h"), "notes.txt restored");
        assert.strictEqual(Undo.summary(two, back(two, two.paths), "/h/Documents", "/h"), "notes.txt and plan.md restored");
        assert.strictEqual(Undo.summary(three, back(three, three.paths), "/h/Documents", "/h"), "3 files restored");
        assert.strictEqual(Undo.summary(three, back(three, ["/h/Documents/a"]), "/h/Documents", "/h"), "a restored, 2 could not be");
        const moved = Undo.moved(Undo.into(["/h/a", "/h/b"], "/h/d"));
        assert.strictEqual(Undo.summary(moved, back(moved, ["/h/a", "/h/b"]), "/h", "/h"), "a and b moved back");
        assert.strictEqual(Undo.summary(Undo.copied(Undo.into(["/h/a"], "/h/d")), back(null, ["/h/d/a"]), "/h/d", "/h"), "Copy of a moved to the trash");
    });

    test.it("says which folder things came back to when it is not the one open", () => {
        const back = done => ({ ok: done.length, gone: 0, taken: 0, failed: 0, done });
        const one = Undo.trashed(["/h/Documents/notes.txt"], 0);
        assert.strictEqual(Undo.summary(one, back(one.paths), "/h/Pictures", "/h"), "notes.txt restored to Documents");
        const home = Undo.trashed(["/h/notes.txt"], 0);
        assert.strictEqual(Undo.summary(home, back(home.paths), "/h/Pictures", "/h"), "notes.txt restored to Home");
        const spread = Undo.trashed(["/h/a/x", "/h/b/y"], 0);
        assert.strictEqual(Undo.summary(spread, back(spread.paths), "/h", "/h"), "x and y restored to 2 folders");
        const renamed = Undo.renamed("/h/Documents/draft.md", "/h/Documents/final.md");
        assert.strictEqual(Undo.summary(renamed, back(["/h/Documents/draft.md"]), "/h", "/h"), "Renamed back to draft.md in Documents");
        const moved = Undo.moved([{ from: "/h/Documents/notes.txt", to: "/h/Archive/notes.txt" }]);
        assert.strictEqual(Undo.summary(moved, back(["/h/Documents/notes.txt"]), "/h/Archive", "/h"), "notes.txt moved back to Documents");
    });

    test.it("says why nothing came back in a few words", () => {
        const none = (gone, taken) => ({ ok: 0, gone, taken, failed: 0, done: [] });
        const one = Undo.trashed(["/h/report.pdf"], 0);
        const three = Undo.trashed(["/h/a", "/h/b", "/h/c"], 0);
        assert.strictEqual(Undo.summary(three, none(3, 0), "/h", "/h"), "Nothing restored, no longer in the trash");
        assert.strictEqual(Undo.summary(one, none(1, 0), "/h", "/h"), "report.pdf is no longer in the trash");
        assert.strictEqual(Undo.summary(one, none(0, 1), "/h", "/h"), "report.pdf not brought back, the name is taken");
        assert.strictEqual(Undo.summary(three, none(0, 0), "/h", "/h"), "Nothing could be brought back");
    });
});
