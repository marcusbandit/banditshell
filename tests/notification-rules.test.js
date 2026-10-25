const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-rules.js"), "utf8");
const Rules = new Function(src + "\nreturn { ruleFor, keyFor, withRule, fromList, candidates, restored };")();

test("an app with no rule pops, sounds and keeps its body off the lock screen", () => {
    assert.deepStrictEqual(Rules.ruleFor({}, "firefox"), { pop: true, snd: true, lock: false, muteUntil: 0 });
    assert.deepStrictEqual(Rules.ruleFor(undefined, "firefox"), { pop: true, snd: true, lock: false, muteUntil: 0 });
    assert.deepStrictEqual(Rules.ruleFor({ firefox: { pop: false } }, ""), { pop: true, snd: true, lock: false, muteUntil: 0 });
});

test("a rule overrides what it names and keeps the default for the rest", () => {
    const rules = { signal: { pop: true, snd: false, lock: true, muteUntil: 0 }, steam: { pop: false, snd: "yes" } };
    assert.deepStrictEqual(Rules.ruleFor(rules, "signal"), { pop: true, snd: false, lock: true, muteUntil: 0 });
    assert.deepStrictEqual(Rules.ruleFor(rules, "steam"), { pop: false, snd: true, lock: false, muteUntil: 0 });
    assert.deepStrictEqual(Rules.ruleFor(rules, "constructor"), { pop: true, snd: true, lock: false, muteUntil: 0 });
});

test("the key is the desktop entry the app resolves to, then what it called itself", () => {
    assert.strictEqual(Rules.keyFor("Signal", "signal-desktop", "signal-desktop.desktop"), "signal-desktop.desktop");
    assert.strictEqual(Rules.keyFor("Signal", "signal-desktop", ""), "signal-desktop");
    assert.strictEqual(Rules.keyFor("notify-send", "", ""), "notify-send");
    assert.strictEqual(Rules.keyFor("Banditshell", undefined, ""), "banditshell");
});

test("changing one switch leaves the other two and the other apps alone", () => {
    const before = { a: { pop: true, snd: true, lock: true, muteUntil: 0 } };
    const after = Rules.withRule(before, "b", { snd: false });
    assert.deepStrictEqual(after, { a: { pop: true, snd: true, lock: true, muteUntil: 0 }, b: { pop: true, snd: false, lock: false, muteUntil: 0 } });
    assert.deepStrictEqual(before, { a: { pop: true, snd: true, lock: true, muteUntil: 0 } });
    assert.deepStrictEqual(Rules.withRule(after, "a", { lock: false, muteUntil: 0 }).a, { pop: true, snd: true, lock: false, muteUntil: 0 });
});

test("the old planned list becomes the keyed object", () => {
    const list = [{ id: "discord", name: "Discord", pop: true, snd: true, lock: false, muteUntil: 0 }, { id: "steam", name: "Steam", pop: false, snd: false, lock: false, muteUntil: 0 }, { name: "nobody" }];
    assert.deepStrictEqual(Rules.fromList(list), { discord: { pop: true, snd: true, lock: false, muteUntil: 0 }, steam: { pop: false, snd: false, lock: false, muteUntil: 0 } });
    assert.deepStrictEqual(Rules.fromList(undefined), {});
});

test("candidates are the apps that sent, once each, without a rule yet", () => {
    const keys = ["signal", "", "firefox", "signal", "steam", "mail"];
    assert.deepStrictEqual(Rules.candidates(keys, { steam: {} }, 10), ["signal", "firefox", "mail"]);
    assert.deepStrictEqual(Rules.candidates(keys, {}, 2), ["signal", "firefox"]);
});

test("a mute deadline is kept as a number and nothing else is", () => {
    const rules = { a: { muteUntil: 5000 }, b: { muteUntil: "soon" }, c: { muteUntil: -1 }, d: { muteUntil: Infinity } };
    assert.strictEqual(Rules.ruleFor(rules, "a").muteUntil, 5000);
    assert.strictEqual(Rules.ruleFor(rules, "b").muteUntil, 0);
    assert.strictEqual(Rules.ruleFor(rules, "c").muteUntil, 0);
    assert.strictEqual(Rules.ruleFor(rules, "d").muteUntil, 0);
});

test("muting for a while and unmuting go through the same rule", () => {
    const muted = Rules.withRule({}, "signal", { muteUntil: 9000 });
    assert.deepStrictEqual(muted.signal, { pop: true, snd: true, lock: false, muteUntil: 9000 });
    const back = Rules.withRule(muted, "signal", { pop: true, snd: true, muteUntil: 0 });
    assert.deepStrictEqual(back.signal, { pop: true, snd: true, lock: false, muteUntil: 0 });
});

test("undoing a mute puts the rule back exactly, or removes one that was not there", () => {
    const rules = { signal: { pop: true, snd: false, lock: true, muteUntil: 0 } };
    const muted = Rules.withRule(Rules.withRule(rules, "signal", { muteUntil: 9000 }), "steam", { pop: false, snd: false });
    assert.deepStrictEqual(Rules.restored(Rules.restored(muted, "steam", undefined), "signal", rules.signal), rules);
    assert.ok(!("steam" in Rules.restored(muted, "steam", undefined)));
});
