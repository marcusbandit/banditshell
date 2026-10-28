const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "config/files-zoom.js"), "utf8").replace(/^\.pragma .*$/m, "");
const FilesZoom = new Function(`${src}\nreturn { SMALLEST, LARGEST, clamp };`)();

test.describe("files zoom: one range for the keys, the buttons and the slider", () => {
    test.it("keeps a saved zoom inside the range when reading it", () => {
        assert.strictEqual(FilesZoom.clamp(0.6), FilesZoom.SMALLEST);
        assert.strictEqual(FilesZoom.clamp(3), FilesZoom.LARGEST);
        assert.strictEqual(FilesZoom.clamp(1.4), 1.4);
    });

    test.it("reads a missing or broken zoom as 100%", () => {
        for (const bad of [undefined, null, "big", NaN, 0, -1])
            assert.strictEqual(FilesZoom.clamp(bad), 1);
    });
});
