const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/notification-search.js"), "utf8");
const Search = new Function(src + "\nreturn { age, threads, threadKey, ask, find, apps, line, appMatches, byApp };")();

const NOW = new Date(2026, 9, 17, 14, 30, 0).getTime();
const ago = ms => NOW - ms;
const MIN = 60 * 1000;
const HOUR = 60 * MIN;

test("under a minute draws nothing", () => {
    assert.strictEqual(Search.age(ago(0), NOW), "");
    assert.strictEqual(Search.age(ago(59 * 1000), NOW), "");
    assert.strictEqual(Search.age(NOW + 5000, NOW), "");
    assert.strictEqual(Search.age(0, NOW), "");
    assert.strictEqual(Search.age(undefined, NOW), "");
});

test("minutes then hours on the same day", () => {
    assert.strictEqual(Search.age(ago(MIN), NOW), "1m");
    assert.strictEqual(Search.age(ago(2 * MIN + 30000), NOW), "2m");
    assert.strictEqual(Search.age(ago(59 * MIN), NOW), "59m");
    assert.strictEqual(Search.age(ago(HOUR), NOW), "1h");
    assert.strictEqual(Search.age(ago(5 * HOUR + 59 * MIN), NOW), "5h");
});

test("a few hours that cross midnight still read as hours", () => {
    const late = new Date(2026, 9, 17, 1, 10, 0).getTime();
    const before = new Date(2026, 9, 16, 22, 40, 0).getTime();
    assert.strictEqual(Search.age(before, late), "2h");
});

test("the day before names the clock time", () => {
    const evening = new Date(2026, 9, 16, 21, 4, 0).getTime();
    assert.strictEqual(Search.age(evening, NOW), "yesterday 21:04");
    const morning = new Date(2026, 9, 16, 9, 5, 0).getTime();
    assert.strictEqual(Search.age(morning, NOW), "yesterday 09:05");
});

test("within a week it names the weekday, beyond it the date", () => {
    const tuesday = new Date(2026, 9, 13, 8, 0, 0).getTime();
    assert.strictEqual(Search.age(tuesday, NOW), "Tue 08:00");
    const earlier = new Date(2026, 9, 3, 8, 0, 0).getTime();
    assert.strictEqual(Search.age(earlier, NOW), "3 Oct");
    const lastYear = new Date(2025, 11, 24, 8, 0, 0).getTime();
    assert.strictEqual(Search.age(lastYear, NOW), "24 Dec 2025");
});

const note = (app, summary, minutesAgo, extra = {}) => Object.assign({ appName: app, summary, time: ago(minutesAgo * MIN), category: "" }, extra);

test("a chat burst from one sender is one thread, newest first", () => {
    const burst = [note("Signal", "Ida", 1), note("Signal", "Ida", 2), note("Signal", "Ida", 3), note("Signal", "Ida", 4)];
    const groups = Search.threads(burst);
    assert.strictEqual(groups.length, 1);
    assert.strictEqual(groups[0].entries.length, 4);
    assert.strictEqual(groups[0].newest, burst[0]);
    assert.strictEqual(groups[0].app, "signal");
});

test("the input order does not decide the thread order, time does", () => {
    const a = note("Signal", "Ida", 5);
    const b = note("Mail", "Invoice", 1);
    const c = note("Signal", "Ida", 2);
    const groups = Search.threads([a, b, c]);
    assert.deepStrictEqual(groups.map(g => g.entries.length), [1, 2]);
    assert.strictEqual(groups[0].newest, b);
    assert.strictEqual(groups[1].newest, c);
});

test("one app is one group whatever it says, newest first inside", () => {
    const groups = Search.byApp([note("qBittorrent", "Download completed", 1), note("qBittorrent", "Torrent added", 9), note("qBittorrent", "Download completed", 300)]);
    assert.strictEqual(groups.length, 1);
    assert.deepStrictEqual(groups[0].entries.map(e => e.summary), ["Download completed", "Torrent added", "Download completed"]);
});

test("the app that spoke last is on top, however many it sent before", () => {
    const torrent = [note("qBittorrent", "Download completed", 1), note("qBittorrent", "Download completed", 40)];
    const chat = note("Discord", "marcus", 5);
    const groups = Search.byApp([chat, ...torrent]);
    assert.deepStrictEqual(groups.map(g => g.entries[0]), [torrent[0], chat]);
    assert.strictEqual(groups[0].entries[1], torrent[1]);
});

test("the same moment keeps the order it came in", () => {
    const a = note("Signal", "Ida", 0);
    const b = note("Mail", "Invoice", 0);
    assert.deepStrictEqual(Search.byApp([a, b]).map(g => g.entries[0]), [a, b]);
});

test("another sender or another app is another thread", () => {
    const groups = Search.threads([note("Signal", "Ida", 1), note("Signal", "Jonas", 2), note("Telegram", "Ida", 3)]);
    assert.strictEqual(groups.length, 3);
});

test("a gap longer than ten minutes starts a new thread", () => {
    const groups = Search.threads([note("Signal", "Ida", 1), note("Signal", "Ida", 5), note("Signal", "Ida", 30), note("Signal", "Ida", 34)]);
    assert.deepStrictEqual(groups.map(g => g.entries.length), [2, 2]);
});

test("the desktop id outranks the name an app calls itself", () => {
    const one = note("Signal", "Ida", 1, { appId: "signal-desktop.desktop" });
    const two = note("signal", "Ida", 2, { appId: "signal-desktop.desktop" });
    assert.strictEqual(Search.threads([one, two]).length, 1);
});

test("a notification with no summary threads by its category", () => {
    const groups = Search.threads([note("App", "", 1, { category: "x" }), note("App", "", 2, { category: "x" }), note("App", "", 3, { category: "y" })]);
    assert.deepStrictEqual(groups.map(g => g.entries.length), [2, 1]);
});

test("nothing in, nothing out", () => {
    assert.deepStrictEqual(Search.threads([]), []);
    assert.deepStrictEqual(Search.threads(undefined), []);
});

test("a thread keeps its id when a newer message joins it", () => {
    const before = Search.threads([note("Signal", "Ida", 5), note("Signal", "Ida", 6)]);
    const after = Search.threads([note("Signal", "Ida", 1), note("Signal", "Ida", 5), note("Signal", "Ida", 6)]);
    assert.strictEqual(before[0].id, after[0].id);
});

test("two threads of one sender have different ids", () => {
    const groups = Search.threads([note("Signal", "Ida", 1), note("Signal", "Ida", 60)]);
    assert.strictEqual(groups.length, 2);
    assert.notStrictEqual(groups[0].id, groups[1].id);
});

test("a bare query is not a notification query", () => {
    const asked = Search.ask("signal");
    assert.strictEqual(asked.explicit, false);
    assert.strictEqual(asked.term, "signal");
    assert.strictEqual(Search.ask("").explicit, false);
    assert.strictEqual(Search.ask("  ").term, "");
});

test("the head words open the history, with or without a rest", () => {
    for (const head of ["notifications", "notification", "notifs", "notif", "Notifications  "]) {
        const asked = Search.ask(head);
        assert.strictEqual(asked.explicit, true, head);
        assert.strictEqual(asked.term, "");
        assert.strictEqual(asked.unread, false);
    }
});

test("unread and held qualify, in any order and as the first word", () => {
    assert.deepStrictEqual(pick(Search.ask("notifications unread")), { explicit: true, unread: true, held: false, app: "", term: "" });
    assert.deepStrictEqual(pick(Search.ask("held")), { explicit: true, unread: false, held: true, app: "", term: "" });
    assert.deepStrictEqual(pick(Search.ask("unread held")), { explicit: true, unread: true, held: true, app: "", term: "" });
    assert.deepStrictEqual(pick(Search.ask("notif held unread")), { explicit: true, unread: true, held: true, app: "", term: "" });
});

test("from takes one word as the app and the rest is free text", () => {
    assert.deepStrictEqual(pick(Search.ask("notifications from signal")), { explicit: true, unread: false, held: false, app: "signal", term: "" });
    assert.deepStrictEqual(pick(Search.ask("notifications from signal ida tonight")), { explicit: true, unread: false, held: false, app: "signal", term: "ida tonight" });
    assert.deepStrictEqual(pick(Search.ask("unread from mail")), { explicit: true, unread: true, held: false, app: "mail", term: "" });
});

test("from with nothing after it is just a word", () => {
    assert.strictEqual(Search.ask("notifications from").app, "");
    assert.strictEqual(Search.ask("notifications from").term, "from");
});

test("from at the start is not a notification query", () => {
    assert.strictEqual(Search.ask("from signal").explicit, false);
});

const seen = (entry, flags) => Object.assign(entry, flags);
const stock = () => [
    seen(note("Signal", "Ida", 1, { id: "1", body: "are you coming?", appId: "signal-desktop" }), { seen: false }),
    seen(note("Signal", "Ida", 2, { id: "2", body: "the film starts at eight", appId: "signal-desktop" }), { seen: true }),
    seen(note("Mail", "Invoice ready", 30, { id: "3", body: "from the landlord", appId: "org.mozilla.Thunderbird" }), { seen: true, withheld: true }),
    seen(note("Steam", "Download finished", 90, { id: "4", body: "Hades II" }), { seen: false, withheld: true })
];

test("find with no filter gives one row per thread, newest first", () => {
    const rows = Search.find(stock(), Search.ask("notifications"));
    assert.deepStrictEqual(rows.map(r => r.entries.length), [2, 1, 1]);
    assert.deepStrictEqual(rows.map(r => r.newest.id), ["1", "3", "4"]);
});

test("unread keeps only what has not been seen", () => {
    const rows = Search.find(stock(), Search.ask("notifications unread"));
    assert.deepStrictEqual(rows.map(r => r.newest.id), ["1", "4"]);
    assert.strictEqual(rows[0].entries.length, 1);
});

test("held keeps only what arrived while quiet", () => {
    const rows = Search.find(stock(), Search.ask("held"));
    assert.deepStrictEqual(rows.map(r => r.newest.id), ["3", "4"]);
});

test("from matches the name or the desktop id", () => {
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications from signal")).map(r => r.newest.id), ["1"]);
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications from thunder")).map(r => r.newest.id), ["3"]);
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications from nothing")), []);
});

test("free text searches the app, summary and body and lists messages, not threads", () => {
    const rows = Search.find(stock(), Search.ask("notifications ida"));
    assert.deepStrictEqual(rows.map(r => r.newest.id), ["1", "2"]);
    assert.ok(rows.every(r => r.entries.length === 1));
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications landlord")).map(r => r.newest.id), ["3"]);
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications hades")).map(r => r.newest.id), ["4"]);
});

test("every free word has to appear, in any order", () => {
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications eight film")).map(r => r.newest.id), ["2"]);
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications eight hades")), []);
});

test("filters and text combine", () => {
    assert.deepStrictEqual(Search.find(stock(), Search.ask("notifications unread from signal ida")).map(r => r.newest.id), ["1"]);
});

test("an entry already on its way out is not listed", () => {
    const list = stock();
    list[0].leaving = true;
    assert.deepStrictEqual(Search.find(list, Search.ask("notifications from signal")).map(r => r.newest.id), ["2"]);
});

test("a plain query finds messages by its words", () => {
    assert.deepStrictEqual(Search.find(stock(), Search.ask("landlord")).map(r => r.newest.id), ["3"]);
});

test("nothing in, nothing out", () => {
    assert.deepStrictEqual(Search.find(undefined, Search.ask("notifications")), []);
});

test("the app words to complete are the recent single-word apps, once each", () => {
    assert.deepStrictEqual(Search.apps(stock(), 8), ["signal", "mail", "steam"]);
    assert.deepStrictEqual(Search.apps(stock(), 2), ["signal", "mail"]);
    assert.deepStrictEqual(Search.apps([note("Visual Studio", "x", 1)], 8), []);
});

test("the row detail names who, how many and how long ago", () => {
    assert.strictEqual(Search.line(note("Signal", "Ida", 4), 1, NOW), "Signal \u00b7 4m");
    assert.strictEqual(Search.line(note("Signal", "Ida", 4), 4, NOW), "Signal \u00b7 4 \u00b7 4m");
    assert.strictEqual(Search.line(note("Signal", "Ida", 0), 1, NOW), "Signal");
});

function pick(asked) {
    return { explicit: asked.explicit, unread: asked.unread, held: asked.held, app: asked.app, term: asked.term };
}
