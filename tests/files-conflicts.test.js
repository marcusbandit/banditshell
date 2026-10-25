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

const Conflicts = lib("services/files-conflicts.js", [
    "numbered", "items", "loops", "placeable", "loopRefusal", "probeCommand", "probed", "choices", "answer", "next", "waiting",
    "operations", "command", "results", "leftover", "reason", "failure", "notice", "renameRefusal"
]);
const Undo = lib("services/files-undo.js", ["moved", "copied", "trashed", "batch", "command", "report", "remember"]);

const ODD = ["two words", "it's \"quoted\"", "-leading-dash", "new\nline", "tab\there", "$(touch pwned)"];

function which(tool) {
    return spawnSync("sh", ["-c", `command -v ${tool}`], { encoding: "utf8" }).stdout.trim();
}

function sandbox({ trashFails = false } = {}) {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), "files-conflicts-"));
    const bin = path.join(dir, "bin");
    const trash = path.join(dir, "trash");
    const home = path.join(dir, "home");
    for (const made of [bin, trash, home])
        fs.mkdirSync(made);
    for (const tool of ["mv", "cp", "cat", "realpath", "dirname"])
        fs.symlinkSync(which(tool), path.join(bin, tool));
    fs.writeFileSync(path.join(bin, "gio"), `#!/bin/sh
${trashFails ? "exit 1" : ""}
if [ "$1 $2" = "trash --restore" ]; then
    shift 3
    [ -e "${trash}/$1" ] || exit 1
    [ -e "$(cat "${trash}/$1.origin")" ] && exit 1
    mv -- "${trash}/$1" "$(cat "${trash}/$1.origin")"
    exit
fi
[ "$1 $2" = "trash --" ] || exit 2
shift 2
for p; do
    n=$(cat "${dir}/count" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "${dir}/count"
    mv -- "$p" "${trash}/$n" && printf %s "$p" > "${trash}/$n.origin"
done
`);
    fs.chmodSync(path.join(bin, "gio"), 0o755);
    const run = argv => spawnSync("/bin/sh", argv.slice(1), { env: { PATH: bin }, cwd: dir, encoding: "utf8" }).stdout;
    return {
        home,
        trash,
        at: (...parts) => path.join(home, ...parts),
        run,
        trashed: () => fs.readdirSync(trash).filter(name => !name.endsWith(".origin")).map(uri => ({ uri, path: fs.readFileSync(path.join(trash, `${uri}.origin`), "utf8"), body: fs.statSync(path.join(trash, uri)).isFile() ? fs.readFileSync(path.join(trash, uri), "utf8") : null })),
        paste: (paths, dir, cut, answers) => {
            const list = Conflicts.probed(Conflicts.items(paths, dir, cut), run(Conflicts.probeCommand(Conflicts.items(paths, dir, cut))));
            let chosen = Conflicts.choices(list);
            for (const [choice, all] of answers ?? [])
                chosen = Conflicts.answer(list, chosen, Conflicts.next(chosen), choice, all);
            assert.strictEqual(Conflicts.next(chosen), -1);
            const ops = Conflicts.operations(list, chosen);
            return { list, ops, outcome: Conflicts.results(ops, run(Conflicts.command(ops, cut))) };
        },
        sandboxed: () => !fs.existsSync(path.join(dir, "pwned")) && !fs.existsSync(path.join(process.cwd(), "pwned")),
        done: () => fs.rmSync(dir, { recursive: true, force: true })
    };
}

function write(file, body) {
    fs.mkdirSync(path.dirname(file), { recursive: true });
    fs.writeFileSync(file, body);
}

test.describe("files paste conflicts", () => {
    test.it("numbers a kept copy before the extension, and after the whole name for folders and dotfiles", () => {
        assert.strictEqual(Conflicts.numbered("photo.png", false, 2), "photo (2).png");
        assert.strictEqual(Conflicts.numbered("archive.tar.gz", false, 3), "archive.tar (3).gz");
        assert.strictEqual(Conflicts.numbered(".bashrc", false, 2), ".bashrc (2)");
        assert.strictEqual(Conflicts.numbered("trailing.", false, 2), "trailing. (2)");
        assert.strictEqual(Conflicts.numbered("v1.2 notes", true, 2), "v1.2 notes (2)");
    });

    test.it("keeps both on a copy into its own folder, and drops a move into its own folder", () => {
        const copy = Conflicts.items(["/h/a.txt", "/h/sub/"], "/h", false);
        assert.deepStrictEqual(copy.map(item => [item.from, item.to, item.self]), [["/h/a.txt", "/h/a.txt", true], ["/h/sub", "/h/sub", true]]);
        assert.deepStrictEqual(Conflicts.choices(copy), ["both", "both"]);
        assert.deepStrictEqual(Conflicts.items(["/h/a.txt"], "/h", true), []);
        assert.deepStrictEqual(Conflicts.items(["/a"], "/", false).map(item => item.to), ["/a"]);
    });

    test.it("finds the taken names and the folders, odd names and dangling links included", () => {
        const box = sandbox();
        try {
            const sources = [...ODD, "folder", "dangling"].map(name => box.at("from", name));
            for (const name of ODD)
                write(box.at("from", name), name);
            fs.mkdirSync(box.at("from", "folder"));
            fs.symlinkSync(box.at("nowhere"), box.at("from", "dangling"));
            write(box.at("to", ODD[1]), "there");
            write(box.at("to", ODD[3]), "there");
            fs.symlinkSync(box.at("nowhere"), box.at("to", "dangling"));

            const list = Conflicts.items(sources, box.at("to"), false);
            const found = Conflicts.probed(list, box.run(Conflicts.probeCommand(list)));
            assert.deepStrictEqual(found.filter(item => item.taken).map(item => item.name), [ODD[1], ODD[3], "dangling"]);
            assert.deepStrictEqual(found.filter(item => item.folder).map(item => item.name), ["folder"]);
            assert.ok(box.sandboxed());
        } finally {
            box.done();
        }
    });

    test.it("asks about each taken name, and apply to all answers only the ones still asked", () => {
        const list = Conflicts.probed(Conflicts.items(["/a/1", "/a/2", "/a/3", "/b/3", "/a/4"], "/t", false), "t1\nt2\nt4\nt5\n");
        let chosen = Conflicts.choices(list);
        assert.deepStrictEqual(chosen, [null, null, "fresh", "both", null]);
        assert.strictEqual(Conflicts.waiting(list, chosen), 3);
        chosen = Conflicts.answer(list, chosen, Conflicts.next(chosen), "skip", false);
        assert.deepStrictEqual(chosen, ["skip", null, "fresh", "both", null]);
        assert.strictEqual(Conflicts.waiting(list, chosen), 2);
        chosen = Conflicts.answer(list, chosen, Conflicts.next(chosen), "replace", true);
        assert.deepStrictEqual(chosen, ["skip", "replace", "fresh", "both", "replace"]);
        assert.strictEqual(Conflicts.next(chosen), -1);
        assert.deepStrictEqual(Conflicts.operations(list, chosen).map(op => [op.mode, op.from]), [["replace", "/a/2"], ["fresh", "/a/3"], ["both", "/b/3"], ["replace", "/a/4"]]);
    });

    test.it("never replaces a folder that holds what is being pasted", () => {
        const list = Conflicts.probed(Conflicts.items(["/h/Docs/Docs"], "/h", true), "t1\nd1\n");
        assert.strictEqual(list[0].holds, true);
        assert.deepStrictEqual(Conflicts.answer(list, Conflicts.choices(list), 0, "replace", false), ["both"]);
    });

    test.it("refuses to paste a folder inside itself", () => {
        const list = Conflicts.items(["/h/b", "/h/c.txt"], "/h/b", false);
        assert.deepStrictEqual(Conflicts.loops(list).map(item => item.name), ["b"]);
        assert.deepStrictEqual(Conflicts.placeable(list).map(item => item.name), ["c.txt"]);
        assert.strictEqual(Conflicts.loopRefusal(Conflicts.loops(list)), "b cannot go inside itself");
        assert.deepStrictEqual(Conflicts.loops(Conflicts.items(["/h/b"], "/h/bb", true)), []);
    });

    test.it("sees the same file and a holding folder through a symlink", () => {
        const box = sandbox();
        try {
            write(box.at("real", "x.txt"), "only copy");
            fs.symlinkSync(box.at("real"), box.at("link"));
            write(box.at("Docs", "Docs", "plan.txt"), "inner");
            fs.symlinkSync(box.at("Docs"), box.at("short"));
            const list = Conflicts.items([box.at("link", "x.txt"), box.at("short", "Docs")], box.at("real"), false);
            list[1].to = box.at("Docs");
            const found = Conflicts.probed(list, box.run(Conflicts.probeCommand(list)));
            assert.deepStrictEqual(found.map(item => [item.self, item.holds]), [[true, false], [false, true]]);
            assert.deepStrictEqual(Conflicts.choices(found), ["both", null]);
            assert.deepStrictEqual(Conflicts.choices(found.map(item => Object.assign({}, item, { cut: true })))[0], "skip");

            box.paste([box.at("link", "x.txt")], box.at("real"), false, []);
            assert.deepStrictEqual(fs.readdirSync(box.at("real")).sort(), ["x (2).txt", "x.txt"]);
            assert.strictEqual(fs.readFileSync(box.at("real", "x.txt"), "utf8"), "only copy");
            assert.deepStrictEqual(box.trashed(), []);
        } finally {
            box.done();
        }
    });

    test.it("skips a second file of the same name when the first was skipped", () => {
        const list = Conflicts.probed(Conflicts.items(["/a/x", "/b/x"], "/t", false), "t1\nt2\n");
        const skipped = Conflicts.answer(list, Conflicts.choices(list), 0, "skip", false);
        assert.deepStrictEqual(Conflicts.operations(list, skipped), []);
        const kept = Conflicts.answer(list, Conflicts.choices(list), 0, "replace", false);
        assert.deepStrictEqual(Conflicts.operations(list, kept).map(op => [op.mode, op.from]), [["replace", "/a/x"], ["both", "/b/x"]]);
    });

    test.it("replaces, skips and keeps both for real, and the replaced file goes to the trash", () => {
        const box = sandbox();
        try {
            const names = ["keep.txt", "skip.txt", "both.txt", "fresh.txt", ...ODD];
            for (const name of names)
                write(box.at("from", name), `new ${name}`);
            for (const name of ["keep.txt", "skip.txt", "both.txt", "both (2).txt", ...ODD])
                write(box.at("to", name), `old ${name}`);
            const answers = [["replace", false], ["skip", false], ["both", false], ["replace", true]];

            const { outcome } = box.paste(names.map(name => box.at("from", name)), box.at("to"), false, answers);

            assert.strictEqual(fs.readFileSync(box.at("to", "keep.txt"), "utf8"), "new keep.txt");
            assert.strictEqual(fs.readFileSync(box.at("to", "skip.txt"), "utf8"), "old skip.txt");
            assert.strictEqual(fs.readFileSync(box.at("to", "both.txt"), "utf8"), "old both.txt");
            assert.strictEqual(fs.readFileSync(box.at("to", "both (2).txt"), "utf8"), "old both (2).txt");
            assert.strictEqual(fs.readFileSync(box.at("to", "both (3).txt"), "utf8"), "new both.txt");
            assert.strictEqual(fs.readFileSync(box.at("to", "fresh.txt"), "utf8"), "new fresh.txt");
            for (const name of ODD)
                assert.strictEqual(fs.readFileSync(box.at("to", name), "utf8"), `new ${name}`);
            assert.deepStrictEqual(box.trashed().map(item => [item.path, item.body]).sort(), ["keep.txt", ...ODD].map(name => [box.at("to", name), `old ${name}`]).sort());
            assert.deepStrictEqual(fs.readdirSync(box.at("from")).sort(), names.slice().sort());
            assert.deepStrictEqual(outcome.replaced.sort(), ["keep.txt", ...ODD].map(name => box.at("to", name)).sort());
            assert.deepStrictEqual(outcome.kept, ["both (3).txt"]);
            assert.strictEqual(outcome.pairs.length, names.length - 1);
            assert.deepStrictEqual(outcome.failed, []);
            assert.strictEqual(Conflicts.notice(outcome), "Kept both, the new one is both (3).txt");
            assert.ok(box.sandboxed());
        } finally {
            box.done();
        }
    });

    test.it("replaces a folder whole instead of merging into it", () => {
        const box = sandbox();
        try {
            write(box.at("from", "site", "index.html"), "new");
            write(box.at("to", "site", "old.html"), "old");
            box.paste([box.at("from", "site")], box.at("to"), false, [["replace", false]]);
            assert.deepStrictEqual(fs.readdirSync(box.at("to", "site")), ["index.html"]);
            assert.strictEqual(box.trashed()[0].path, box.at("to", "site"));
        } finally {
            box.done();
        }
    });

    test.it("copies a folder into its own folder as a numbered copy", () => {
        const box = sandbox();
        try {
            write(box.at("site", "index.html"), "x");
            write(box.at("notes.md"), "y");
            box.paste([box.at("site"), box.at("notes.md")], box.home, false, []);
            assert.deepStrictEqual(fs.readdirSync(box.home).sort(), ["notes (2).md", "notes.md", "site", "site (2)"]);
            assert.deepStrictEqual(fs.readdirSync(box.at("site (2)")), ["index.html"]);
        } finally {
            box.done();
        }
    });

    test.it("leaves the target alone when it cannot be trashed", () => {
        const box = sandbox({ trashFails: true });
        try {
            write(box.at("from", "a.txt"), "new");
            write(box.at("to", "a.txt"), "old");
            const { outcome, ops } = box.paste([box.at("from", "a.txt")], box.at("to"), true, [["replace", false]]);
            assert.strictEqual(fs.readFileSync(box.at("to", "a.txt"), "utf8"), "old");
            assert.strictEqual(fs.readFileSync(box.at("from", "a.txt"), "utf8"), "new");
            assert.deepStrictEqual(outcome.pairs, []);
            assert.strictEqual(Conflicts.failure(outcome, true, ops.length), "a.txt could not be moved");
        } finally {
            box.done();
        }
    });

    test.it("says the old file is in the trash when its replacement could not be copied", () => {
        const box = sandbox();
        try {
            write(box.at("from", "a.txt"), "new");
            fs.chmodSync(box.at("from", "a.txt"), 0o000);
            write(box.at("to", "a.txt"), "old");
            const { outcome, ops } = box.paste([box.at("from", "a.txt")], box.at("to"), false, [["replace", false]]);
            fs.chmodSync(box.at("from", "a.txt"), 0o644);
            assert.deepStrictEqual(fs.readdirSync(box.at("to")), []);
            assert.deepStrictEqual(outcome.replaced, [box.at("to", "a.txt")]);
            assert.deepStrictEqual(box.trashed().map(item => item.body), ["old"]);
            assert.strictEqual(Conflicts.failure(outcome, false, ops.length, "cp: cannot open 'a.txt' for reading: Permission denied\n"), "a.txt could not be copied: Permission denied, the old one is in the trash");
        } finally {
            box.done();
        }
    });

    test.it("keeps a cut on the clipboard until it has moved, so skipped and failed files stay", () => {
        const box = sandbox();
        try {
            for (const name of ["moved", "skipped", "replaced"])
                write(box.at("from", name), name);
            write(box.at("to", "skipped"), "there");
            write(box.at("to", "replaced"), "there");
            const clipboard = ["moved", "skipped", "replaced", "vanished"].map(name => box.at("from", name));
            const { outcome } = box.paste(clipboard, box.at("to"), true, [["skip", false], ["replace", false]]);
            assert.deepStrictEqual(fs.readdirSync(box.at("from")), ["skipped"]);
            assert.strictEqual(fs.readFileSync(box.at("to", "replaced"), "utf8"), "replaced");
            assert.deepStrictEqual(Conflicts.leftover(clipboard, outcome), [box.at("from", "skipped")]);
            assert.deepStrictEqual(Conflicts.leftover(clipboard, { done: [], gone: [] }), clipboard);
        } finally {
            box.done();
        }
    });

    test.it("undoes a replace in one step: the paste goes back and the replaced file returns", () => {
        for (const cut of [false, true]) {
            const box = sandbox();
            try {
                write(box.at("from", "a.txt"), "new");
                write(box.at("from", "b.txt"), "new b");
                write(box.at("to", "a.txt"), "old");
                const { outcome } = box.paste([box.at("from", "a.txt"), box.at("from", "b.txt")], box.at("to"), cut, [["replace", false]]);
                const entry = Undo.batch([cut ? Undo.moved(outcome.pairs) : Undo.copied(outcome.pairs), Undo.trashed(outcome.replaced, 0)]);
                assert.strictEqual(entry.kind, "batch");
                assert.strictEqual(Undo.remember([], entry).length, 1);

                const first = box.run(Undo.command(entry.parts[0], []));
                const uri = box.trashed().find(item => item.path === box.at("to", "a.txt") && item.body === "old").uri;
                const second = box.run(Undo.command(entry.parts[1], [uri]));

                assert.deepStrictEqual(fs.readdirSync(box.at("to")), ["a.txt"]);
                assert.strictEqual(fs.readFileSync(box.at("to", "a.txt"), "utf8"), "old");
                assert.deepStrictEqual(fs.readdirSync(box.at("from")).sort(), ["a.txt", "b.txt"]);
                const told = Undo.report(entry, [first, second], box.at("to"), box.home);
                assert.strictEqual(told.ok, true);
                assert.strictEqual(told.text, cut ? "a.txt and b.txt moved back to from, a.txt restored" : "Copies of a.txt and b.txt moved to the trash, a.txt restored");
                assert.deepStrictEqual(told.shown, cut ? [box.at("from", "a.txt"), box.at("from", "b.txt"), box.at("to", "a.txt")] : [box.at("to", "a.txt")]);
            } finally {
                box.done();
            }
        }
    });

    test.it("records a plain paste as a plain entry and an empty one as nothing", () => {
        assert.strictEqual(Undo.batch([Undo.copied([{ from: "/a", to: "/b/a" }]), Undo.trashed([], 0)]).kind, "copy");
        assert.deepStrictEqual(Undo.remember([], Undo.batch([Undo.moved([]), Undo.trashed([], 0)])), []);
        const told = Undo.report(Undo.batch([Undo.copied([{ from: "/a", to: "/b/a" }]), Undo.trashed(["/b/a"], 0)]), ["failed\n", "gone\n"], "/b", "/h");
        assert.deepStrictEqual(told, { ok: false, text: "a could not be brought back", shown: [] });
    });

    test.it("refuses a rename onto a name already in the folder", () => {
        const names = ["draft.md", "final.md", "Notes"];
        assert.strictEqual(Conflicts.renameRefusal("final.md", "draft.md", names), "final.md is already here");
        assert.strictEqual(Conflicts.renameRefusal("Notes", "draft.md", names), "Notes is already here");
        assert.strictEqual(Conflicts.renameRefusal("draft.md", "draft.md", names), "");
        assert.strictEqual(Conflicts.renameRefusal("notes", "draft.md", names), "");
        assert.strictEqual(Conflicts.renameRefusal("report.md", "draft.md", names), "");
    });

    test.it("says what went wrong in one short line", () => {
        const failed = names => ({ failed: names, half: [], kept: [] });
        assert.strictEqual(Conflicts.failure(failed([]), false, 3), "");
        assert.strictEqual(Conflicts.failure(failed(["a.txt"]), false, 3), "a.txt could not be copied");
        assert.strictEqual(Conflicts.failure(failed(["a", "b"]), true, 3), "2 of 3 could not be moved");
        assert.strictEqual(Conflicts.failure(failed(["a"]), true, 1, "mv: cannot move 'a' to 'b/a': No space left on device\n"), "a could not be moved: No space left on device");
        assert.strictEqual(Conflicts.reason("\n"), "");
        assert.strictEqual(Conflicts.notice({ kept: ["a (2)", "b (2)"] }), "Kept both for 2 files, the new ones are numbered");
        assert.strictEqual(Conflicts.notice({ kept: [] }), "");
    });
});
