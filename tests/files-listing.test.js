const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/files-listing.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Listing = new Function(`${src}\nreturn { table, same, reuse, changed, steps, stale, rereadIn, MOST_STEPS, REREAD_GAP };`)();

function play(before, steps, after) {
    const keys = before.slice();
    for (const step of steps) {
        if ("remove" in step)
            keys.splice(step.remove, step.count);
        else if ("move" in step)
            keys.splice(step.to, 0, keys.splice(step.move, 1)[0]);
        else
            keys.splice(step.insert, 0, ...after.slice(step.insert, step.insert + step.count));
    }
    return keys;
}

function check(before, after) {
    const steps = Listing.steps(before, after);
    assert.notStrictEqual(steps, null);
    assert.deepStrictEqual(play(before, steps, after), after);
    return steps;
}

test.describe("files listing", () => {
    test.it("an unchanged listing needs no steps", () => {
        assert.deepStrictEqual(check(["a", "b", "c"], ["a", "b", "c"]), []);
    });

    test.it("one new file is one insert", () => {
        assert.deepStrictEqual(check(["a", "c", "d"], ["a", "b", "c", "d"]), [{insert: 1, count: 1}]);
    });

    test.it("a run of new files is one insert", () => {
        assert.deepStrictEqual(check(["a", "d"], ["a", "b", "c", "d"]), [{insert: 1, count: 2}]);
    });

    test.it("removed files leave in runs, from the end", () => {
        assert.deepStrictEqual(check(["a", "b", "c", "d", "e"], ["a", "d"]), [{remove: 4, count: 1}, {remove: 1, count: 2}]);
    });

    test.it("a rename is a remove and an insert", () => {
        check(["photo-1", "photo-2", "photo-3"], ["photo-2", "photo-3", "zzz"]);
    });

    test.it("a file that moves to the top under date order is one move", () => {
        assert.deepStrictEqual(check(["a", "b", "c", "d"], ["c", "a", "b", "d"]), [{move: 2, to: 0}]);
    });

    test.it("a file that moves to the end is one move", () => {
        assert.deepStrictEqual(check(["a", "b", "c", "d", "e"], ["b", "c", "d", "e", "a"]), [{move: 0, to: 4}]);
        const many = Array.from({length: 200}, (_, i) => `f${i}`);
        assert.strictEqual(check(many, many.slice(1).concat(["f0"])).length, 1);
    });

    test.it("a file that moves down to the middle takes at most two moves", () => {
        assert.ok(check(["a", "b", "c", "d", "e"], ["b", "c", "a", "d", "e"]).length <= 2);
    });

    test.it("shuffled lists still land on the new order", () => {
        let seed = 7;
        const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
        for (let round = 0; round < 200; round++) {
            const before = Array.from({length: 12}, (_, i) => `k${i}`).filter(() => random() > 0.2);
            const after = Array.from({length: 14}, (_, i) => `k${i}`).filter(() => random() > 0.2).sort(() => random() - 0.5);
            const steps = Listing.steps(before, after);
            if (steps)
                assert.deepStrictEqual(play(before, steps, after), after);
        }
    });

    test.it("mixed changes land on the new order", () => {
        check(["a", "b", "c", "d", "e", "f"], ["new", "f", "b", "d", "x", "y", "a"]);
        check([], ["a", "b"]);
        check(["a", "b"], []);
    });

    test.it("too many steps asks for a rebuild", () => {
        const before = Array.from({length: 400}, (_, i) => `f${i}`);
        assert.strictEqual(Listing.steps(before, before.slice().reverse()), null);
        assert.strictEqual(Listing.steps(before, before.filter((_, i) => i % 2 === 0)), null);
    });

    test.it("duplicate keys ask for a rebuild", () => {
        assert.strictEqual(Listing.steps(["a", "b"], ["a", "a"]), null);
    });

    test.it("an unchanged entry keeps the object it had", () => {
        const old = [{name: "a", size: 1, mtime: 5}, {name: "b", size: 2, mtime: 5, trash: {path: "/x"}}];
        const fresh = [{name: "b", size: 2, mtime: 5, trash: {path: "/x"}}, {name: "a", size: 9, mtime: 6}, {name: "c", size: 0, mtime: 1}];
        const out = Listing.reuse(old, fresh, e => e.name);
        assert.strictEqual(out[0], old[1]);
        assert.strictEqual(out[1], fresh[1]);
        assert.strictEqual(out[2], fresh[2]);
    });

    test.it("only entries that changed in place need a redraw", () => {
        const a = {name: "a"}, b = {name: "b"}, c = {name: "c"};
        const after = [{name: "new"}, a, {name: "b"}, c];
        assert.deepStrictEqual(Listing.changed([a, b, c], after, Listing.table(["a", "b", "c"]), after.map(e => e.name)), [2]);
    });

    test.it("a name like a built-in property is still a key", () => {
        check(["__proto__", "constructor"], ["constructor", "toString", "__proto__"]);
    });

    test.it("a changed trash record is a changed entry", () => {
        assert.ok(!Listing.same({name: "a", trash: {path: "/x"}}, {name: "a", trash: {path: "/y"}}));
        assert.ok(!Listing.same({name: "a"}, {name: "a", link: true}));
        assert.ok(!Listing.same({name: "a", link: true}, {name: "a"}));
    });

    test.it("a preview is stale when its file's size or time moved", () => {
        const seen = {name: "log", size: 10, mtime: 100};
        assert.ok(!Listing.stale(seen, {name: "log", size: 10, mtime: 100}));
        assert.ok(Listing.stale(seen, {name: "log", size: 11, mtime: 100}));
        assert.ok(Listing.stale(seen, {name: "log", size: 10, mtime: 101}));
        assert.ok(!Listing.stale(null, seen));
    });

    test.it("a preview reads again at most once a second", () => {
        assert.strictEqual(Listing.rereadIn(10000, 8000), 0);
        assert.strictEqual(Listing.rereadIn(10000, 9000), 0);
        assert.strictEqual(Listing.rereadIn(10000, 9700), 700);
    });
});
