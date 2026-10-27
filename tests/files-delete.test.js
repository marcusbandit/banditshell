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

const Deletion = lib("modules/files/deletion.js", ["question", "approved"]);

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

    test.it("asks by naming what goes, and where a trashed item came from", () => {
        assert.strictEqual(Deletion.question([{ name: "a.txt", origin: "~/Documents" }]), 'Delete a.txt from ~/Documents permanently? Type "delete" to confirm');
        assert.strictEqual(Deletion.question([{ name: "plan.md", origin: "" }]), 'Delete plan.md permanently? Type "delete" to confirm');
        assert.strictEqual(Deletion.question([{ name: "a.txt", origin: "~/Music" }, { name: "a.txt", origin: "~/Documents" }]), 'Delete a.txt from ~/Music and a.txt from ~/Documents permanently? Type "delete" to confirm');
        assert.strictEqual(Deletion.question([{ name: "a", origin: "" }, { name: "b", origin: "" }, { name: "c", origin: "" }, { name: "d", origin: "" }]), 'Delete a, b and 2 more permanently? Type "delete" to confirm');
    });

    test.it("every permanent delete in the shell goes through that answer", () => {
        const calls = [];
        for (const file of qmlFiles(ROOT)) {
            const text = fs.readFileSync(file, "utf8");
            for (const match of text.matchAll(/deleteForever\(/g)) {
                if (text.slice(Math.max(0, match.index - 9), match.index) === "function ")
                    continue;
                calls.push([path.relative(ROOT, file), text.slice(match.index, match.index + 40)]);
            }
        }
        assert.ok(calls.length > 0);
        for (const [file, call] of calls)
            assert.ok(call.startsWith("deleteForever(Deletion.approved("), `${file}: ${call}`);
    });
});
