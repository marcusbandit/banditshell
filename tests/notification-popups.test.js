const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-popups.js"), "utf8");
const Popups = new Function(src + "\nreturn { fit, delivery, textChanged };")();

const urgent = e => e.critical;
const names = list => list.map(e => e.name);

test("an ordinary notification over the limit goes to the history", () => {
    const list = [{ name: "d" }, { name: "c" }, { name: "b" }, { name: "a" }];
    const out = Popups.fit(list, 2, urgent);
    assert.deepStrictEqual(names(out.shown), ["d", "c"]);
    assert.deepStrictEqual(names(out.dropped), ["b", "a"]);
});

test("with the limit at 1 a critical alert stays when an ordinary one arrives", () => {
    const out = Popups.fit([{ name: "chat" }, { name: "timer", critical: true }], 1, urgent);
    assert.deepStrictEqual(names(out.shown), ["timer"]);
    assert.deepStrictEqual(names(out.dropped), ["chat"]);
});

test("critical alerts take slots first and keep their order", () => {
    const list = [{ name: "a" }, { name: "x", critical: true }, { name: "b" }, { name: "y", critical: true }, { name: "c" }];
    const out = Popups.fit(list, 3, urgent);
    assert.deepStrictEqual(names(out.shown), ["a", "x", "y"]);
    assert.deepStrictEqual(names(out.dropped), ["b", "c"]);
});

test("critical alerts are never dropped, even past the limit", () => {
    const list = [{ name: "x", critical: true }, { name: "y", critical: true }, { name: "z", critical: true }];
    const out = Popups.fit(list, 1, urgent);
    assert.deepStrictEqual(names(out.shown), ["x", "y", "z"]);
    assert.deepStrictEqual(out.dropped, []);
});

test("an empty list fits", () => {
    assert.deepStrictEqual(Popups.fit([], 4, urgent), { shown: [], dropped: [] });
});

const allowed = { pop: true, snd: true };

test("a free notification pops up and plays its sound", () => {
    assert.deepStrictEqual(Popups.delivery(false, allowed, false, false), { popup: true, sound: true, waiting: false });
});

test("quiet mode shows nothing and plays nothing", () => {
    assert.deepStrictEqual(Popups.delivery(true, allowed, false, false), { popup: false, sound: false, waiting: false });
});

test("a muted app shows nothing and plays nothing", () => {
    assert.deepStrictEqual(Popups.delivery(false, allowed, true, false), { popup: false, sound: false, waiting: false });
});

test("an app with popups off still plays its sound", () => {
    assert.deepStrictEqual(Popups.delivery(false, { pop: false, snd: true }, false, false), { popup: false, sound: true, waiting: false });
});

test("an app with sound off still pops up", () => {
    assert.deepStrictEqual(Popups.delivery(false, { pop: true, snd: false }, false, false), { popup: true, sound: false, waiting: false });
});

test("under a fullscreen window the popup waits and the sound still plays", () => {
    assert.deepStrictEqual(Popups.delivery(false, allowed, false, true), { popup: false, sound: true, waiting: true });
});

test("an app that never pops up leaves nothing waiting under fullscreen", () => {
    assert.strictEqual(Popups.delivery(false, { pop: false, snd: true }, false, true).waiting, false);
});

test("only a new summary or body counts as news", () => {
    const before = { summary: "Chat", body: "first" };
    assert.strictEqual(Popups.textChanged(before, { summary: "Chat", body: "first" }), false);
    assert.strictEqual(Popups.textChanged(before, { summary: "Chat", body: "second message" }), true);
    assert.strictEqual(Popups.textChanged(before, { summary: "Other", body: "first" }), true);
});
