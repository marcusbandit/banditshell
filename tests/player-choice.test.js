const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/player-choice.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { shown } = new Function(src + "\nreturn { shown };")();

const player = (name, isPlaying, rank = 2) => ({ name, isPlaying, rank });
const rank = p => p.rank;

test("an idle tab is never shown, even when it is the only player", () => {
    const tab = player("zen", false);
    assert.strictEqual(shown([tab], null, null, rank), null);
});

test("the song you paused stays, the idle tab does not take its place", () => {
    const tab = player("zen", false);
    const song = player("spotify", false);
    assert.strictEqual(shown([tab, song], null, song, rank), song);
});

test("what is playing wins over what you paused", () => {
    const paused = player("spotify", false);
    const video = player("zen", true);
    assert.strictEqual(shown([paused, video], null, paused, rank), video);
});

test("of two playing, the one that started last is shown", () => {
    const first = player("spotify", true);
    const last = player("zen", true);
    assert.strictEqual(shown([first, last], null, last, rank), last);
    assert.strictEqual(shown([first, last], null, null, rank), first);
});

test("a hover preview neither plays over nor stands in for anything", () => {
    const preview = player("zen", true, 1);
    assert.strictEqual(shown([preview], null, null, rank), null);
    const song = player("spotify", false);
    assert.strictEqual(shown([preview, song], null, song, rank), song);
});

test("a player that quit or lost its track is not shown", () => {
    const tab = player("zen", false);
    const gone = player("spotify", false);
    assert.strictEqual(shown([tab], null, gone, rank), null);
    const empty = player("anibeam", false, 0);
    assert.strictEqual(shown([tab, empty], null, empty, rank), null);
});

test("a player you picked is shown whatever it is doing", () => {
    const tab = player("zen", false);
    const song = player("spotify", true);
    assert.strictEqual(shown([tab, song], tab, song, rank), tab);
    assert.strictEqual(shown([song], tab, song, rank), song);
});
