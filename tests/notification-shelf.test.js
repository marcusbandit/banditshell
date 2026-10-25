const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-shelf.js"), "utf8");
const Shelf = new Function(src + "\nreturn { shelve, restored, placed, homes, hushedPopups };")();

const at = time => ({ time });

test("undo puts cards back where they were, newest first", () => {
    const [a, b, c, d] = [at(40), at(30), at(20), at(10)];
    assert.deepStrictEqual(Shelf.restored([a, d], [c, b]), [a, b, c, d]);
});

test("undo leaves cards that arrived meanwhile in their place", () => {
    const [fresh, old, older] = [at(50), at(20), at(10)];
    assert.deepStrictEqual(Shelf.restored([fresh, older], [old]), [fresh, old, older]);
});

test("a card already back is not doubled", () => {
    const a = at(10);
    assert.deepStrictEqual(Shelf.restored([a], [a]), [a]);
});

test("a second dismiss inside the window joins the first", () => {
    const [a, b] = [at(2), at(1)];
    const shelf = Shelf.shelve(Shelf.shelve([], [{ entry: a }]), [{ entry: b }, { entry: a }]);
    assert.deepStrictEqual(shelf.map(r => r.entry), [a, b]);
});

test("undone popups take back their places in the stack, not their time order", () => {
    const [woken, a, b, c] = [at(1), at(40), at(30), at(20)];
    assert.deepStrictEqual(Shelf.placed([woken, c], [{ entry: a, at: 1 }]), [woken, a, c]);
    assert.deepStrictEqual(Shelf.placed([], [{ entry: c, at: 2 }, { entry: b, at: 1 }, { entry: a, at: 0 }]), [a, b, c]);
});

test("two swipes off the top come back in their old order", () => {
    const [a, b, c] = [at(3), at(2), at(1)];
    assert.deepStrictEqual(Shelf.placed([c], [{ entry: a, at: 0 }, { entry: b, at: 0 }]), [a, b, c]);
});

test("a popup the app closed meanwhile comes back to the history only", () => {
    const [open, closed] = [at(2), at(1)];
    const homes = Shelf.homes([
        { entry: open, listed: true, popup: 0, live: true },
        { entry: closed, listed: true, popup: 1, live: false }
    ]);
    assert.deepStrictEqual(homes.history, [open, closed]);
    assert.deepStrictEqual(homes.popups, [{ entry: open, at: 0 }]);
    assert.deepStrictEqual(homes.gone, []);
});

test("a transient card with nowhere to go is let go for real", () => {
    const [shown, closed] = [at(2), at(1)];
    const homes = Shelf.homes([
        { entry: shown, listed: false, popup: 0, live: true },
        { entry: closed, listed: false, popup: 0, live: false }
    ]);
    assert.deepStrictEqual(homes.history, []);
    assert.deepStrictEqual(homes.popups, [{ entry: shown, at: 0 }]);
    assert.deepStrictEqual(homes.gone, [closed]);
});

test("a snooze puts away its own card, a mute every card from that app, in place", () => {
    const [a, b, c] = [{ n: "a" }, { n: "b" }, { n: "c" }];
    const keys = ["discord", "signal", "discord"];
    assert.deepStrictEqual(Shelf.hushedPopups([a, b, c], keys, c, "discord", "snooze"), [{ entry: c, at: 2 }]);
    assert.deepStrictEqual(Shelf.hushedPopups([a, b, c], keys, a, "discord", "mute"), [{ entry: a, at: 0 }, { entry: c, at: 2 }]);
    assert.deepStrictEqual(Shelf.hushedPopups([a, b, c], keys, a, "discord", "unmute"), []);
});
