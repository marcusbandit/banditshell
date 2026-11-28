const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "../modules/island/notification-sections.js"), "utf8");
const S = new Function(src + "\nreturn { sectionOf, split, newest, seen };")();

const note = (appName, extra) => Object.assign({ appName, urgency: 1, time: 0 }, extra || {});
const group = (key, ...entries) => ({ key, entries });

test.describe("notification sections", () => {
    test.it("chats are messages, quiet ones are silent, the rest are apps", () => {
        assert.strictEqual(S.sectionOf(note("Discord")), "messages");
        assert.strictEqual(S.sectionOf(note("Mail", { category: "im.received" })), "messages");
        assert.strictEqual(S.sectionOf(note("Discord", { urgency: 0 })), "silent");
        assert.strictEqual(S.sectionOf(note("Firefox")), "apps");
        assert.strictEqual(S.sectionOf(note("Sessions")), "apps");
    });

    test.it("keeps the Messages, Apps, Silent order and drops empty ones", () => {
        const out = S.split([group("ff", note("Firefox")), group("dc", note("Discord")), group("st", note("Steam", { urgency: 0 }))], 0);
        assert.deepStrictEqual(out.map(s => [s.key, s.groups.map(g => g.key)]), [["messages", ["dc"]], ["apps", ["ff"]], ["silent", ["st"]]]);
        assert.deepStrictEqual(S.split([group("ff", note("Firefox"))], 0).map(s => s.key), ["apps"]);
        assert.deepStrictEqual(S.split([group("ff", note("Firefox"))], 1).map(s => s.key), ["apps", "silent"]);
    });

    test.it("the newest standing entry is the one left open", () => {
        const old = note("Firefox", { time: 1 });
        const fresh = note("Discord", { time: 5 });
        const going = note("Steam", { time: 9, leaving: true });
        assert.strictEqual(S.newest([group("a", old), group("b", fresh, going)]), fresh);
    });

    test.it("a card counts as seen by how much of it is above the view's bottom", () => {
        assert.strictEqual(S.seen(0, 100, 0, 300), 1);
        assert.strictEqual(S.seen(250, 100, 0, 300), 0.5);
        assert.strictEqual(S.seen(400, 100, 0, 300), 0);
    });
});
