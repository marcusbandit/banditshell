const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/keyring-windows.js"), "utf8").replace(/^\.pragma .*$/m, "");
const KeyringWindows = new Function(src + "\nreturn { windowsToBring };")();
const CLIENTS = fs.readFileSync(path.join(ROOT, "tests/fixtures/keyring/hyprctl-clients.json"), "utf8");
const GCR = 81234;
const QBITTORRENT = 5177;

test.describe("windowsToBring", () => {
    test.it("moves the prompter's window from another workspace to the focused one", () => {
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, GCR, "", 2, []), [{ address: "0x5556ad0e4a10", move: true }]);
    });

    test.it("only focuses a window already on the focused workspace", () => {
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, GCR, "", 7, []), [{ address: "0x5556ad0e4a10", move: false }]);
    });

    test.it("brings the window into an open special workspace, and leaves one already there", () => {
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, GCR, "special:torrents", 7, []), [{ address: "0x5556ad0e4a10", move: true }]);
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, QBITTORRENT, "special:torrents", 2, []), [{ address: "0x5556acc69c00", move: false }]);
    });

    test.it("leaves a window alone once it was brought, so the user can move it away", () => {
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, GCR, "", 2, ["0x5556ad0e4a10"]), []);
    });

    test.it("touches nothing without the prompter's process or a readable list", () => {
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, 0, "", 2, []), []);
        assert.deepStrictEqual(KeyringWindows.windowsToBring(CLIENTS, 999, "", 2, []), []);
        assert.deepStrictEqual(KeyringWindows.windowsToBring("ok", GCR, "", 2, []), []);
    });
});
