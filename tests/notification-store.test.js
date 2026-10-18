const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = name => fs.readFileSync(path.join(ROOT, "services", name), "utf8");
const Search = new Function(read("notification-search.js") + "\nreturn { threads };")();
const Store = new Function(read("notification-store.js") + "\nreturn { serialise, restore, trim, isTemporary, isBorrowed, pictureNames };")();

const DIR = "/state/pictures";

const entry = (id, time, extra = {}) => Object.assign({
    durable: true,
    id,
    time,
    appName: "Signal",
    summary: "Ida",
    body: "hello",
    appIcon: "",
    desktopEntry: "signal-desktop",
    category: "",
    urgency: 1,
    progress: -1,
    image: "",
    cached: "",
    pinned: false,
    seen: false
}, extra);

test("an entry survives a round trip through the file", () => {
    const original = entry("a", 5000, { urgency: 2, progress: 40, pinned: true, seen: true, cached: `${DIR}/a.png` });
    const raw = JSON.stringify(Store.serialise([original], 10));
    const [back] = Store.restore(raw, 50, [], DIR);
    assert.strictEqual(back.id, "a");
    assert.strictEqual(back.urgency, 2);
    assert.strictEqual(back.progress, 40);
    assert.strictEqual(back.pinned, true);
    assert.strictEqual(back.seen, true);
    assert.strictEqual(back.cached, `${DIR}/a.png`);
    assert.strictEqual(back.summary, "Ida");
});

test("an entry held back while quiet is still held back after a restart", () => {
    const raw = JSON.stringify(Store.serialise([entry("a", 5000, { withheld: true }), entry("b", 4000)], 10));
    const back = Store.restore(raw, 50, [], DIR);
    assert.deepStrictEqual(back.map(e => e.withheld), [true, false]);
});

test("only durable entries are written, so a preview never reaches the file", () => {
    const saved = Store.serialise([entry("a", 1000), entry("b", 2000, { durable: false })], 10);
    assert.deepStrictEqual(saved.entries.map(e => e.id), ["a"]);
});

test("an entry on its way out for good is not written", () => {
    const saved = Store.serialise([entry("a", 1000, { leaving: true, forget: true }), entry("b", 2000, { leaving: true, forget: false })], 10);
    assert.deepStrictEqual(saved.entries.map(e => e.id), ["b"]);
});

test("restore is idempotent: ids already in memory are skipped", () => {
    const raw = JSON.stringify(Store.serialise([entry("a", 1000), entry("b", 2000)], 10));
    const first = Store.restore(raw, 50, [], DIR);
    assert.strictEqual(first.length, 2);
    const again = Store.restore(raw, 50, first.map(e => e.id), DIR);
    assert.strictEqual(again.length, 0);
});

test("restore returns newest first and honours the limit", () => {
    const raw = JSON.stringify(Store.serialise([entry("a", 1000), entry("b", 3000), entry("c", 2000)], 10));
    assert.deepStrictEqual(Store.restore(raw, 50, [], DIR).map(e => e.id), ["b", "c", "a"]);
    assert.deepStrictEqual(Store.restore(raw, 2, [], DIR).map(e => e.id), ["b", "c"]);
    assert.deepStrictEqual(Store.restore(raw, 0, [], DIR), []);
});

test("duplicate ids inside the file count once", () => {
    const raw = JSON.stringify({ version: 1, entries: [entry("a", 1000), entry("a", 2000)] });
    assert.strictEqual(Store.restore(raw, 50, [], DIR).length, 1);
});

test("garbage restores to nothing instead of throwing", () => {
    assert.deepStrictEqual(Store.restore("not json", 50, [], DIR), []);
    assert.deepStrictEqual(Store.restore("", 50, [], DIR), []);
    assert.deepStrictEqual(Store.restore("null", 50, [], DIR), []);
    assert.deepStrictEqual(Store.restore({ entries: "x" }, 50, [], DIR), []);
    assert.deepStrictEqual(Store.restore({ entries: [null, 3, "x", {}, { id: "a" }, { time: 5 }] }, 50, [], DIR), []);
});

test("fields of the wrong type are replaced, not trusted", () => {
    const raw = { entries: [{ id: "a", time: 5, summary: 7, body: null, urgency: 9, progress: 400, pinned: "yes", seen: 0 }] };
    const [e] = Store.restore(raw, 50, [], DIR);
    assert.strictEqual(e.summary, "");
    assert.strictEqual(e.body, "");
    assert.strictEqual(e.urgency, 1);
    assert.strictEqual(e.progress, -1);
    assert.strictEqual(e.pinned, true);
    assert.strictEqual(e.seen, false);
});

test("a picture name that tries to leave the folder is refused", () => {
    for (const bad of ["../a.png", "/etc/passwd", "a/b.png", "a.jpg", ""]) {
        const [e] = Store.restore({ entries: [{ id: "a", time: 5, picture: bad }] }, 50, [], DIR);
        assert.strictEqual(e.cached, "", bad);
    }
});

test("temporary pictures are never written down", () => {
    assert.ok(Store.isTemporary("/tmp/a.png"));
    assert.ok(Store.isTemporary("file:///tmp/a.png"));
    assert.ok(Store.isTemporary("/run/user/1000/a.png"));
    assert.ok(!Store.isTemporary("/home/me/a.png"));
    assert.ok(Store.isBorrowed("image://qsimage/12"));
    assert.ok(!Store.isBorrowed("image://icon/mail"));
    const saved = Store.serialise([entry("a", 1, { image: "image://qsimage/1" }), entry("b", 2, { image: "/tmp/x.png" }), entry("c", 3, { image: "/home/me/x.png" })], 10);
    assert.deepStrictEqual(saved.entries.map(e => e.image), ["", "", "/home/me/x.png"]);
    const [back] = Store.restore({ entries: [{ id: "a", time: 5, image: "/tmp/x.png" }] }, 50, [], DIR);
    assert.strictEqual(back.image, "");
});

test("only the newest entries keep their copied picture, so the folder stays bounded", () => {
    const list = [];
    for (let i = 0; i < 10; i++)
        list.push(entry(`e${i}`, 10000 - i, { cached: `${DIR}/e${i}.png` }));
    const saved = Store.serialise(list, 3);
    assert.deepStrictEqual(Store.pictureNames(saved), ["e0.png", "e1.png", "e2.png"]);
    assert.strictEqual(saved.entries.length, 10);
});

const burst = (app, summary, count, from) => Array.from({ length: count }, (_, i) => ({ appName: app, summary, time: from - i * 1000, id: `${app}${summary}${i}` }));

test("a chat burst evicts its own old messages before unrelated history", () => {
    const history = [...burst("Signal", "Ida", 8, 900000), ...burst("Mail", "Invoice", 1, 500000), ...burst("Steam", "Sale", 1, 400000), ...burst("Git", "Pushed", 1, 300000)];
    const gone = Store.trim(Search.threads(history), 8);
    assert.strictEqual(gone.length, 3);
    assert.ok(gone.every(e => e.appName === "Signal"));
    assert.deepStrictEqual(gone.map(e => e.time), [900000 - 7000, 900000 - 6000, 900000 - 5000].sort((a, b) => a - b));
});

test("with no thread over its share, the oldest entry goes", () => {
    const history = [...burst("A", "a", 1, 5000), ...burst("B", "b", 1, 4000), ...burst("C", "c", 1, 3000)];
    const gone = Store.trim(Search.threads(history), 2);
    assert.deepStrictEqual(gone.map(e => e.appName), ["C"]);
});

test("under the limit nothing is evicted", () => {
    assert.deepStrictEqual(Store.trim(Search.threads(burst("A", "a", 5, 5000)), 5), []);
    assert.deepStrictEqual(Store.trim([], 5), []);
});

test("a thread's three newest are safe while older material is over its share", () => {
    const history = [...burst("Signal", "Ida", 6, 900000), ...burst("Mail", "Invoice", 2, 100000)];
    const gone = Store.trim(Search.threads(history), 5);
    assert.strictEqual(gone.length, 3);
    assert.ok(gone.every(e => e.appName === "Signal"));
});
