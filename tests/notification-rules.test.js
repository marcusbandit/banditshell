const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-rules.js"), "utf8");
const Rules = new Function(src + "\nreturn { ruleFor, keyFor, withRule, fromList, candidates };")();

test("an app with no rule pops, sounds and keeps its body off the lock screen", () => {
    assert.deepStrictEqual(Rules.ruleFor({}, "firefox"), { pop: true, snd: true, lock: false });
    assert.deepStrictEqual(Rules.ruleFor(undefined, "firefox"), { pop: true, snd: true, lock: false });
    assert.deepStrictEqual(Rules.ruleFor({ firefox: { pop: false } }, ""), { pop: true, snd: true, lock: false });
});

test("a rule overrides what it names and keeps the default for the rest", () => {
    const rules = { signal: { pop: true, snd: false, lock: true }, steam: { pop: false, snd: "yes" } };
    assert.deepStrictEqual(Rules.ruleFor(rules, "signal"), { pop: true, snd: false, lock: true });
    assert.deepStrictEqual(Rules.ruleFor(rules, "steam"), { pop: false, snd: true, lock: false });
    assert.deepStrictEqual(Rules.ruleFor(rules, "constructor"), { pop: true, snd: true, lock: false });
});

test("the key is the desktop entry the app resolves to, then what it called itself", () => {
    assert.strictEqual(Rules.keyFor("Signal", "signal-desktop", "signal-desktop.desktop"), "signal-desktop.desktop");
    assert.strictEqual(Rules.keyFor("Signal", "signal-desktop", ""), "signal-desktop");
    assert.strictEqual(Rules.keyFor("notify-send", "", ""), "notify-send");
    assert.strictEqual(Rules.keyFor("Banditshell", undefined, ""), "banditshell");
});

test("changing one switch leaves the other two and the other apps alone", () => {
    const before = { a: { pop: true, snd: true, lock: true } };
    const after = Rules.withRule(before, "b", { snd: false });
    assert.deepStrictEqual(after, { a: { pop: true, snd: true, lock: true }, b: { pop: true, snd: false, lock: false } });
    assert.deepStrictEqual(before, { a: { pop: true, snd: true, lock: true } });
    assert.deepStrictEqual(Rules.withRule(after, "a", { lock: false }).a, { pop: true, snd: true, lock: false });
});

test("the old planned list becomes the keyed object", () => {
    const list = [{ id: "discord", name: "Discord", pop: true, snd: true, lock: false }, { id: "steam", name: "Steam", pop: false, snd: false, lock: false }, { name: "nobody" }];
    assert.deepStrictEqual(Rules.fromList(list), { discord: { pop: true, snd: true, lock: false }, steam: { pop: false, snd: false, lock: false } });
    assert.deepStrictEqual(Rules.fromList(undefined), {});
});

test("candidates are the apps that sent, once each, without a rule yet", () => {
    const keys = ["signal", "", "firefox", "signal", "steam", "mail"];
    assert.deepStrictEqual(Rules.candidates(keys, { steam: {} }, 10), ["signal", "firefox", "mail"]);
    assert.deepStrictEqual(Rules.candidates(keys, {}, 2), ["signal", "firefox"]);
});
