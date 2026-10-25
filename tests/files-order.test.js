const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Order = lib("services/files-order.js", ["SORTS", "ordered", "merged"]);
const Catalogue = lib("modules/settings/catalogue.js", ["ROW_BY_KEY", "PAGE_BY_ID", "options", "filesSortOrder"]);

const entries = [
    {name: "b.txt", kind: "file", class: "text", size: 10, mtime: 300},
    {name: "a.png", kind: "file", class: "image", size: 900, mtime: 100},
    {name: "c.md", kind: "file", class: "markdown", size: 50, mtime: 200},
    {name: "zdir", kind: "dir", class: "folder", size: 0, mtime: 50}
];

const names = key => Order.ordered(entries, key).map(e => e.name);

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
            "a to z": ["zdir", "a.png", "b.txt", "c.md"],
            newest: ["zdir", "b.txt", "c.md", "a.png"],
            biggest: ["zdir", "a.png", "c.md", "b.txt"],
            type: ["zdir", "a.png", "c.md", "b.txt"]
        });
    });

    test.it("the Settings summary says which way the sort runs", () => {
        const values = {filesView: "list", filesSort: "mtime", filesHidden: false};
        assert.strictEqual(Catalogue.PAGE_BY_ID.files.status({v: k => values[k]}), "list · newest first");
        const said = Catalogue.options(Catalogue.ROW_BY_KEY.filesSort, {}).map(([v]) => Catalogue.filesSortOrder(v));
        assert.deepStrictEqual(said, ["a to z", "newest first", "biggest first", "grouped by type"]);
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
