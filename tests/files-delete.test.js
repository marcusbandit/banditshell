const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const SKIPPED = new Set([".git", ".scratch", "node_modules", "tests"]);

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Deletion = lib("modules/files/deletion.js", ["question", "what", "approved", "emptying", "emptied"]);

function qmlFiles(dir) {
    const found = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (SKIPPED.has(entry.name))
            continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory())
            found.push(...qmlFiles(full));
        else if (entry.name.endsWith(".qml"))
            found.push(full);
    }
    return found;
}

test.describe("files permanent delete", () => {
    test.it("deletes nothing unless the answer is the word delete", () => {
        const paths = ["/h/.local/share/Trash/files/a.txt", "/h/Documents/b.txt"];
        for (const answer of ["", " ", "d", "del", "yes", "y", "ok", "deleted", "delete it", "remove", "delete\nnow", undefined, null, 1, true])
            assert.deepStrictEqual(Deletion.approved(answer, paths), [], JSON.stringify(answer));
        for (const answer of ["delete", "DELETE", " Delete "]) {
            const kept = Deletion.approved(answer, paths);
            assert.deepStrictEqual(kept, paths);
            assert.notStrictEqual(kept, paths);
        }
    });

    test.it("asks in one sentence that names what goes, where a trashed item came from, and that it cannot come back", () => {
        assert.strictEqual(Deletion.question([{ name: "a.txt", origin: "~/Documents" }]), "a.txt from ~/Documents will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.question([{ name: "plan.md", origin: "" }]), "plan.md will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.what([{ name: "a.txt", origin: "~/Music" }, { name: "a.txt", origin: "~/Documents" }]), "a.txt from ~/Music and a.txt from ~/Documents");
        assert.strictEqual(Deletion.what([{ name: "a", origin: "" }, { name: "b", origin: "" }, { name: "c", origin: "" }, { name: "d", origin: "" }]), "a, b and 2 more");
    });

    test.it("empties the trash only on the word empty", () => {
        const items = [{ dir: "/h/.local/share/Trash", name: "a.txt" }];
        for (const answer of ["", "e", "yes", "delete", "emptied", "empty it", undefined, null, true])
            assert.deepStrictEqual(Deletion.emptied(answer, items), [], JSON.stringify(answer));
        for (const answer of ["empty", "EMPTY", " Empty "]) {
            const kept = Deletion.emptied(answer, items);
            assert.deepStrictEqual(kept, items);
            assert.notStrictEqual(kept, items);
        }
    });

    test.it("says how many items an empty trash takes, how many are hidden and how many sit on other drives", () => {
        assert.strictEqual(Deletion.emptying(1, 0, 0), "1 item will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(12, 0, 0), "12 items will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(1, 1, 0), "1 item, from another drive, will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(1, 0, 1), "1 item, hidden, will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(12, 1, 0), "12 items, 1 from another drive, will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(12, 3, 0), "12 items, 3 from other drives, will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(2, 2, 0), "2 items, all from other drives, will be deleted and cannot be brought back.");
        assert.strictEqual(Deletion.emptying(8, 1, 2), "8 items, 2 hidden and 1 from another drive, will be deleted and cannot be brought back.");
    });

    for (const [verb, gate] of [["deleteForever", "Deletion.approved("], ["emptyTrash", "Deletion.emptied("]])
        test.it(`every ${verb} call in the shell goes through its answer`, () => {
            const calls = [];
            for (const file of qmlFiles(ROOT)) {
                const text = fs.readFileSync(file, "utf8");
                for (const match of text.matchAll(new RegExp(`${verb}\\(`, "g"))) {
                    if (text.slice(Math.max(0, match.index - 9), match.index) === "function ")
                        continue;
                    calls.push([path.relative(ROOT, file), text.slice(match.index, match.index + 40)]);
                }
            }
            assert.ok(calls.length > 0);
            for (const [file, call] of calls)
                assert.ok(call.startsWith(`${verb}(${gate}`), `${file}: ${call}`);
        });
});
