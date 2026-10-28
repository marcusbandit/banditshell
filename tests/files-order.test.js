const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Order = lib("services/files-order.js", ["SORTS", "SORT_WORDS", "orderWords", "foldersNote", "ordered", "merged", "trashOrder"]);
const Catalogue = lib("modules/settings/catalogue.js", ["ROW_BY_KEY", "PAGE_BY_ID", "options", "filesSortOrder", "filesFoldersNote"]);
const Configuration = lib("config/configuration.js", ["merge", "upgrade"]);

function defaults() {
    const text = fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8");
    const start = text.indexOf("{", text.indexOf("readonly property var defaults:"));
    let depth = 0;
    for (let i = start; ; i++) {
        depth += text[i] === "{" ? 1 : text[i] === "}" ? -1 : 0;
        if (depth === 0)
            return new Function("UserFolders", `return (${text.slice(start, i + 1)});`)({ picturesAtStart: "~/Pictures" });
    }
}

const entries = [
    {name: "b.txt", kind: "file", class: "text", size: 10, mtime: 300},
    {name: "a.png", kind: "file", class: "image", size: 900, mtime: 100},
    {name: "c.md", kind: "file", class: "markdown", size: 50, mtime: 200},
    {name: "zdir", kind: "dir", class: "folder", size: 0, mtime: 50}
];

const names = (key, reversed) => Order.ordered(entries, key, reversed).map(e => e.name);

const sorted = [
    {name: "b.txt", kind: "file", class: "text", size: 10, mtime: 300},
    {name: "a.png", kind: "file", class: "image", size: 900, mtime: 100},
    {name: "c.md", kind: "file", class: "markdown", size: 50, mtime: 200},
    {name: "d.png", kind: "file", class: "image", size: 900, mtime: 100},
    {name: "adir", kind: "dir", class: "folder", size: 0, mtime: 10},
    {name: "zdir", kind: "dir", class: "folder", size: 0, mtime: 50}
];

test.describe("files order", () => {
    test.it("every sort Settings writes is one the file manager knows", () => {
        const row = Catalogue.ROW_BY_KEY.filesSort;
        assert.strictEqual(row.cfg, "files.sort");
        for (const [value] of Catalogue.options(row, {}))
            assert.ok(Order.SORTS.includes(value), `Settings writes ${value}`);
    });

    test.it("each Settings label sorts the way it reads", () => {
        const row = Catalogue.ROW_BY_KEY.filesSort;
        const byLabel = Object.fromEntries(Catalogue.options(row, {}).map(([v, l]) => [l, names(v)]));
        assert.deepStrictEqual(byLabel, {
            name: ["zdir", "a.png", "b.txt", "c.md"],
            date: ["zdir", "b.txt", "c.md", "a.png"],
            size: ["zdir", "a.png", "c.md", "b.txt"],
            type: ["zdir", "a.png", "c.md", "b.txt"]
        });
    });

    test.it("sort words are the same in Settings and the file manager", () => {
        const row = Catalogue.ROW_BY_KEY.filesSort;
        for (const [value, label] of Catalogue.options(row, {}))
            assert.strictEqual(label, Order.SORT_WORDS[value]);
    });

    test.it("order words are the same in Settings and the file manager, for the sort chosen", () => {
        const row = Catalogue.ROW_BY_KEY.filesReversed;
        assert.strictEqual(row.cfg, "files.reversed");
        for (const sort of Order.SORTS) {
            assert.strictEqual(Catalogue.filesFoldersNote(sort), Order.foldersNote(sort));
            const said = Catalogue.options(row, {v: () => sort});
            assert.deepStrictEqual(said, [[false, Order.orderWords(sort)[0]], [true, Order.orderWords(sort)[1]]]);
        }
    });

    test.it("each sort runs both ways with folders first", () => {
        const run = key => Order.ordered(sorted, key, false).map(e => e.name).join(" ");
        const back = key => Order.ordered(sorted, key, true).map(e => e.name).join(" ");
        assert.deepStrictEqual([run("name"), back("name")], ["adir zdir a.png b.txt c.md d.png", "zdir adir d.png c.md b.txt a.png"]);
        assert.deepStrictEqual([run("mtime"), back("mtime")], ["zdir adir b.txt c.md a.png d.png", "adir zdir a.png d.png c.md b.txt"]);
        assert.deepStrictEqual([run("size"), back("size")], ["adir zdir a.png d.png c.md b.txt", "adir zdir b.txt c.md a.png d.png"]);
        assert.deepStrictEqual([run("kind"), back("kind")], ["adir zdir a.png d.png c.md b.txt", "adir zdir b.txt c.md a.png d.png"]);
    });

    test.it("the trash lists the newest trashed first, folders among files, unless sorted by size or type", () => {
        const trashed = entries.map((e, i) => Object.assign({}, e, {trashed: [100, 400, 200, 300][i]}));
        const listed = how => Order.ordered(trashed, how.key, how.reversed).map(e => e.name);
        assert.deepStrictEqual(listed(Order.trashOrder("name", false)), ["a.png", "zdir", "c.md", "b.txt"]);
        assert.deepStrictEqual(listed(Order.trashOrder("name", true)), ["a.png", "zdir", "c.md", "b.txt"]);
        assert.deepStrictEqual(listed(Order.trashOrder("mtime", true)), ["b.txt", "c.md", "zdir", "a.png"]);
        assert.deepStrictEqual(Order.trashOrder("size", true), {key: "size", reversed: true});
        assert.deepStrictEqual(Order.trashOrder("kind", false), {key: "kind", reversed: false});
    });

    test.it("an unknown sort runs by name, and Z to A turns it round", () => {
        assert.deepStrictEqual(names("bogus", false), names("name", false));
        assert.deepStrictEqual(names("bogus", true), names("name", true));
    });

    test.it("a config saved before the order setting keeps the order it had", () => {
        const saved = Configuration.upgrade({files: {sort: "mtime", view: "list"}});
        const config = fs.readFileSync(path.join(ROOT, "config/Config.qml"), "utf8");
        const opaque = JSON.parse(/readonly property var opaque: (\[[^\]]*\])/.exec(config)[1]);
        const files = Configuration.merge(defaults(), saved, "", opaque).files;
        assert.strictEqual(files.reversed, false);
        assert.deepStrictEqual(names(files.sort, files.reversed), ["zdir", "b.txt", "c.md", "a.png"]);
    });

    test.it("the Settings summary says which way the sort runs", () => {
        const status = (sort, reversed) => Catalogue.PAGE_BY_ID.files.status({v: k => ({filesView: "list", filesSort: sort, filesReversed: reversed, filesHidden: false})[k]});
        assert.strictEqual(status("mtime", false), "list · newest first");
        assert.strictEqual(status("mtime", true), "list · oldest first");
        const said = Catalogue.options(Catalogue.ROW_BY_KEY.filesSort, {}).map(([v]) => [Catalogue.filesSortOrder(v, false), Catalogue.filesSortOrder(v, true)]);
        assert.deepStrictEqual(said, [["a to z", "z to a"], ["newest first", "oldest first"], ["biggest first", "smallest first"], ["types a to z", "types z to a"]]);
    });

    test.it("Markdown source in Settings writes raw, the value the file manager shows as source", () => {
        const row = Catalogue.ROW_BY_KEY.filesMarkdown;
        assert.strictEqual(row.cfg, "files.markdown");
        assert.deepStrictEqual(Catalogue.options(row, {}), [["rendered", "rendered"], ["raw", "source"]]);
    });

    test.it("a big folder listed in an awkward order still sorts in n log n comparisons", () => {
        const name = (prefix, i) => ({name: `${prefix}-${String(i).padStart(5, "0")}`, kind: "file"});
        const listed = [];
        for (let i = 4499; i >= 0; i--)
            listed.push(name("new", i));
        for (let i = 0; i < 30000; i++)
            listed.push(name("old", i));
        let calls = 0;
        const sorted = Order.merged(listed, (a, b) => (calls++, a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
        assert.ok(calls < listed.length * Math.log2(listed.length), `${calls} comparisons`);
        assert.deepStrictEqual([sorted[0].name, sorted[4499].name, sorted[4500].name, sorted.at(-1).name], ["new-00000", "new-04499", "old-00000", "old-29999"]);
    });

    test.it("keeps equal names in the order they were listed", () => {
        const same = [{name: "A", kind: "file", tag: 1}, {name: "a", kind: "file", tag: 2}, {name: "A", kind: "file", tag: 3}];
        assert.deepStrictEqual(Order.ordered(same, "name").map(e => e.tag), [1, 2, 3]);
    });

    test.it("does not reorder the list it was given", () => {
        Order.ordered(entries, "size");
        assert.deepStrictEqual(entries.map(e => e.name), ["b.txt", "a.png", "c.md", "zdir"]);
    });
});
