const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Search = lib("modules/launcher/search.js", ["streamVolumeAsk", "mixerAsk", "awakeAsk", "volumeAsk"]);

test.describe("an app's volume", () => {
    test.it("reads the app and the level in the usual word orders", () => {
        for (const text of ["volume spotify 30", "spotify volume 30", "set spotify volume to 30%", "spotify 30%", "volume of spotify to 30"])
            assert.deepStrictEqual(Search.streamVolumeAsk(text), { name: "spotify", level: 30 }, text);
    });

    test.it("leaves the main volume and plain numbers alone", () => {
        for (const text of ["volume 50", "volume to 50", "spotify 30", "the 30%", "100%", "firefox 200%"])
            assert.strictEqual(Search.streamVolumeAsk(text), null, text);
        assert.strictEqual(Search.volumeAsk("volume to 50"), 50);
    });

    test.it("knows when every app's volume is wanted", () => {
        assert.ok(Search.mixerAsk("volume"));
        assert.ok(Search.mixerAsk("Mixer"));
        assert.ok(!Search.mixerAsk("volume 5"));
    });
});

test.describe("keep awake for a while", () => {
    test.it("reads a length after keep awake, awake or coffee", () => {
        assert.strictEqual(Search.awakeAsk("keep awake 1h"), 3600);
        assert.strictEqual(Search.awakeAsk("awake for 30 min"), 1800);
        assert.strictEqual(Search.awakeAsk("coffee 2h"), 7200);
        assert.strictEqual(Search.awakeAsk("keep awake 90"), 5400);
    });

    test.it("leaves the plain toggle and stray words alone", () => {
        for (const text of ["keep awake", "awake", "keep awake 1h tea"])
            assert.strictEqual(Search.awakeAsk(text), 0, text);
    });
});
