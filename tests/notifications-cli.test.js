const test = require("node:test");
const assert = require("node:assert");
const { cleanup, cli } = require("./fixtures/cli-stubs.js");

test.after(cleanup);

const dry = (...args) => {
    const run = cli(args, { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(run.code, 0, `${args.join(" ")}: ${run.err}`);
    assert.deepStrictEqual(run.calls, [], "a dry run reaches no tool");
    return run.out.trim().split("\n").map(line => line.trimEnd());
};

test("bare, it says what is waiting and whether quiet", () => {
    assert.deepStrictEqual(dry("notifications"), ["ipc notifications status", "ipc quiet status"]);
});

test("list takes a filter and an app in either order", () => {
    assert.deepStrictEqual(dry("notifications", "list"), ["ipc notifications list"]);
    assert.deepStrictEqual(dry("notifications", "list", "unread"), ["ipc notifications list unread"]);
    assert.deepStrictEqual(dry("notifications", "list", "signal", "held"), ["ipc notifications list held signal"]);
});

test("open hands the query to the launcher on the history", () => {
    assert.deepStrictEqual(dry("notifications", "open"), ["ipc notifications search"]);
    assert.deepStrictEqual(dry("notifications", "open", "unread", "from", "signal"), ["ipc notifications search unread from signal"]);
});

test("the launcher takes a query too", () => {
    assert.deepStrictEqual(dry("panel", "launcher", "open", "notifications", "held"), ["ipc launcher open notifications held"]);
    assert.deepStrictEqual(dry("panel", "launcher", "open"), ["ipc launcher open"]);
});

test("the alert verbs go to the notifications handler", () => {
    assert.deepStrictEqual(dry("notifications", "act"), ["ipc notifications act"]);
    assert.deepStrictEqual(dry("notifications", "dismiss"), ["ipc notifications dismiss front"]);
    assert.deepStrictEqual(dry("notifications", "dismiss", "all"), ["ipc notifications dismiss all"]);
    assert.deepStrictEqual(dry("notifications", "reply", "on", "my", "way"), ["ipc notifications reply on my way"]);
    assert.deepStrictEqual(dry("notifications", "snooze", "1h"), ["ipc notifications snooze 1h"]);
    assert.deepStrictEqual(dry("notifications", "clear"), ["ipc notifications clear"]);
});

test("mute and unmute name an app and a length", () => {
    assert.deepStrictEqual(dry("notifications", "mute", "signal", "day"), ["ipc notifications mute signal day"]);
    assert.deepStrictEqual(dry("notifications", "mute", "signal"), ["ipc notifications mute signal"]);
    assert.deepStrictEqual(dry("notifications", "unmute", "signal"), ["ipc notifications unmute signal"]);
});

test("a verb that needs a word refuses without it, and an unknown verb is a usage error", () => {
    for (const args of [["notifications", "reply"], ["notifications", "mute"], ["notifications", "unmute"]]) {
        const run = cli(args, { env: { BANDITSHELL_DRY: "1" } });
        assert.strictEqual(run.code, 2, args.join(" "));
        assert.match(run.err, /usage: banditshell notifications/);
    }
    const bad = cli(["notifications", "explode"], { env: { BANDITSHELL_DRY: "1" } });
    assert.strictEqual(bad.code, 2);
});

test("the old panel verbs still reach the notifications handler", () => {
    assert.deepStrictEqual(dry("panel", "notifications", "open"), ["ipc notifications open"]);
    assert.deepStrictEqual(dry("panel", "notifications", "toggle"), ["ipc notifications toggle"]);
    assert.deepStrictEqual(dry("panel", "notifications", "close"), ["ipc notifications close"]);
    assert.deepStrictEqual(dry("panel", "notifications", "clear"), ["ipc notifications clear"]);
});
