const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "..", "services/workspace-key.js"), "utf8").replace(/^\.pragma .*$/m, "");
const { keyOf, shownKeys, visibleKey, specialNames } = new Function(`${src}\nreturn { keyOf, shownKeys, visibleKey, specialNames };`)();

const fixture = name => JSON.parse(fs.readFileSync(path.join(__dirname, "fixtures", "hyprctl", name), "utf8"));
const clients = fixture("hyprland-0.57-clients.json");
const workspaces = fixture("hyprland-0.57-workspaces.json");
const monitors = fixture("hyprland-0.57-monitors.json");

test.describe("workspace keys on Hyprland 0.57", () => {
    test.it("keys a special workspace by its name when the id is missing", () => {
        assert.strictEqual(keyOf({ address: "special:music", type: "special", name: "special:music" }), "special:music");
    });

    test.it("keys a normal workspace by its id", () => {
        assert.strictEqual(keyOf({ id: 2, type: "normal", name: "2" }), "2");
    });

    test.it("keeps older Hyprland, where a special has a negative id and a name", () => {
        assert.strictEqual(keyOf({ id: -98, name: "special:music" }), "special:music");
    });

    test.it("falls back to the negative id when an old special has no name", () => {
        assert.strictEqual(keyOf({ id: -98 }), "special#-98");
    });

    test.it("gives nothing for a missing or unplaced workspace", () => {
        assert.strictEqual(keyOf(undefined), "");
        assert.strictEqual(keyOf({ id: 0 }), "");
    });

    test.it("puts each window on its own special workspace", () => {
        const grouped = {};
        for (const c of clients)
            (grouped[keyOf(c.workspace)] = grouped[keyOf(c.workspace)] || []).push(c);
        const classes = key => grouped[key].map(c => c.class).sort();
        assert.deepStrictEqual(classes("special:music"), ["Spotify"]);
        assert.deepStrictEqual(classes("special:torrents"), ["org.qbittorrent.qBittorrent"]);
        assert.deepStrictEqual(classes("special:communication"), ["Beeper", "vesktop"]);
        assert.deepStrictEqual(classes("1"), ["com.t3tools.T3Code", "foot", "zen"]);
        assert.deepStrictEqual(classes("2"), ["com.marcusrosado.AniBeam"]);
    });

    test.it("lists every special once, from workspaces, windows and monitors together", () => {
        assert.deepStrictEqual(specialNames(workspaces, clients, monitors).sort(), ["special:communication", "special:music", "special:torrents"]);
        assert.deepStrictEqual(specialNames([], clients, []).sort(), ["special:communication", "special:music", "special:torrents"]);
    });

    test.it("reports a special as shown only for the monitor that has it open", () => {
        assert.deepStrictEqual(shownKeys(1, ""), ["1"]);
        assert.deepStrictEqual(shownKeys(1, "special:music"), ["1", "special:music"]);
        assert.deepStrictEqual(shownKeys(undefined, ""), []);
    });

    test.it("shows the special over the workspace beneath it", () => {
        assert.strictEqual(visibleKey(1, "special:music"), "special:music");
        assert.strictEqual(visibleKey(1, ""), "1");
        assert.strictEqual(visibleKey(undefined, ""), "");
    });
});
