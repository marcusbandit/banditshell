const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const FIXTURES = path.join(__dirname, "fixtures/apps");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8");
const Entries = new Function(read("services/desktop-entries.js") + "\nreturn { parseBundle, indexEntries };")();
const Defaults = new Function(read("services/default-apps.js") + "\nreturn { GROUPS, allTypes, typeMatches, handledTypes, offers, parseDefaults, groupValue, strays, terminalListFirst, terminalListSet, terminalListEntries, terminalListNames, effectiveTerminalList, terminalWrites };")();

const applications = fs.readdirSync(path.join(FIXTURES, "applications")).sort().map(f => `@@@${f}\n${fs.readFileSync(path.join(FIXTURES, "applications", f), "utf8")}`).join("");
const entries = Entries.indexEntries(Entries.parseBundle(applications));

test("every group names the types it reads and writes", () => {
    assert.deepStrictEqual(Object.keys(Defaults.GROUPS), ["defBrowser", "defFiles", "defTerm", "defMail", "defImages", "defVideo"]);
    assert.ok(Defaults.allTypes().includes("x-scheme-handler/https"));
    assert.strictEqual(new Set(Defaults.allTypes()).size, Defaults.allTypes().length);
});

test("a wildcard in a desktop entry covers the types under it", () => {
    assert.ok(Defaults.typeMatches("image/*", "image/webp"));
    assert.ok(!Defaults.typeMatches("image/*", "video/mp4"));
    assert.ok(Defaults.typeMatches("image/png", "image/png"));
});

test("browsers are the entries that handle web links", () => {
    const offered = Defaults.offers(entries, Defaults.GROUPS.defBrowser, "");
    assert.deepStrictEqual(offered, [["firefox.desktop", "Firefox"]]);
});

test("pictures list viewers by how many of the types they cover, handlers hidden from menus included", () => {
    const offered = Defaults.offers(entries, Defaults.GROUPS.defImages, "");
    assert.deepStrictEqual(offered.map(o => o[0]), ["imv.desktop", "feh.desktop"]);
});

test("an app that covers fewer than half of a group's types is left out", () => {
    const narrow = entries.concat([{ id: "krita_png.desktop", name: "Krita", type: "Application", noDisplay: false, categories: [], mimeTypes: ["image/png"] }]);
    assert.ok(!Defaults.offers(narrow, Defaults.GROUPS.defImages, "").some(o => o[0] === "krita_png.desktop"));
    assert.ok(Defaults.offers(narrow, Defaults.GROUPS.defImages, "krita_png.desktop").some(o => o[0] === "krita_png.desktop"));
});

test("a hidden entry is not a terminal choice unless it is the current one", () => {
    const hidden = entries.concat([{ id: "server.desktop", name: "Server", type: "Application", noDisplay: true, categories: ["TerminalEmulator"], mimeTypes: [] }]);
    assert.ok(!Defaults.offers(hidden, Defaults.GROUPS.defTerm, "").some(o => o[0] === "server.desktop"));
    assert.ok(Defaults.offers(hidden, Defaults.GROUPS.defTerm, "server.desktop").some(o => o[0] === "server.desktop"));
});

test("terminals are the entries in the terminal emulator category", () => {
    const offered = Defaults.offers(entries, Defaults.GROUPS.defTerm, "");
    assert.deepStrictEqual(offered, [["foot.desktop", "foot"], ["kitty.desktop", "kitty"]]);
});

test("a current default that no entry explains is still offered by its id", () => {
    assert.deepStrictEqual(Defaults.offers(entries, Defaults.GROUPS.defMail, "geary.desktop"), [["geary.desktop", "geary"]]);
});

test("xdg-mime answers are read per type, taking the first app of a list", () => {
    const answers = Defaults.parseDefaults("x-scheme-handler/http=zen.desktop\nx-scheme-handler/https=zen.desktop;firefox.desktop\ninode/directory=\nbroken\n");
    assert.deepStrictEqual(answers, { "x-scheme-handler/http": "zen.desktop", "x-scheme-handler/https": "zen.desktop", "inode/directory": "" });
});

test("a group shows the app most of its types agree on, and names the strays", () => {
    const answers = { "image/png": "imv.desktop", "image/jpeg": "imv.desktop", "image/webp": "zen.desktop", "image/gif": "feh.desktop" };
    const group = Defaults.GROUPS.defImages;
    const chosen = Defaults.groupValue(group, answers);
    assert.strictEqual(chosen, "imv.desktop");
    assert.deepStrictEqual(Defaults.strays(group, answers, chosen), [{ id: "zen.desktop", types: ["webp"] }, { id: "feh.desktop", types: ["gif"] }]);
    assert.strictEqual(Defaults.groupValue(group, {}), "");
    assert.deepStrictEqual(Defaults.strays(group, { "image/png": "imv.desktop" }, "imv.desktop"), []);
});

test("the terminal list reads its first entry, skipping comments and actions", () => {
    const text = fs.readFileSync(path.join(FIXTURES, "terminals.list"), "utf8");
    assert.strictEqual(Defaults.terminalListFirst(text), "org.gnome.Terminal.desktop");
    assert.strictEqual(Defaults.terminalListFirst(""), "");
    assert.deepStrictEqual(Defaults.terminalListEntries(text), ["org.gnome.Terminal.desktop", "foot.desktop:new-window"]);
});

test("choosing a terminal moves it to the top of the list and keeps the rest", () => {
    const text = fs.readFileSync(path.join(FIXTURES, "terminals.list"), "utf8");
    assert.strictEqual(Defaults.terminalListSet(text, "foot.desktop"), "foot.desktop\n# preferred first\norg.gnome.Terminal.desktop\n");
    assert.strictEqual(Defaults.terminalListSet("", "kitty.desktop"), "kitty.desktop\n");
    assert.strictEqual(Defaults.terminalListSet("kitty.desktop\n", "kitty.desktop"), "kitty.desktop\n");
});

test("the lists xdg-terminal-exec reads are the desktop ones first, in both cases, then the plain one", () => {
    assert.deepStrictEqual(Defaults.terminalListNames("Hyprland"), ["Hyprland-xdg-terminals.list", "hyprland-xdg-terminals.list", "xdg-terminals.list"]);
    assert.deepStrictEqual(Defaults.terminalListNames("niri:GNOME"), ["niri-xdg-terminals.list", "GNOME-xdg-terminals.list", "gnome-xdg-terminals.list", "xdg-terminals.list"]);
    assert.deepStrictEqual(Defaults.terminalListNames(""), ["xdg-terminals.list"]);
    assert.deepStrictEqual(Defaults.terminalListNames(undefined), ["xdg-terminals.list"]);
    assert.deepStrictEqual(Defaults.terminalListNames("../evil"), ["xdg-terminals.list"]);
});

test("the list in effect is the first existing one that names a terminal", () => {
    const lists = [
        { name: "Hyprland-xdg-terminals.list", text: "", exists: false, readable: true },
        { name: "hyprland-xdg-terminals.list", text: "# nothing yet\n", exists: true, readable: true },
        { name: "xdg-terminals.list", text: "foot.desktop\n", exists: true, readable: true }
    ];
    assert.strictEqual(Defaults.effectiveTerminalList(lists), "foot.desktop\n");
    assert.strictEqual(Defaults.effectiveTerminalList(lists.slice(0, 2)), "");
    assert.strictEqual(Defaults.effectiveTerminalList([Object.assign({}, lists[2], { text: "kitty.desktop\n" }), lists[2]]), "kitty.desktop\n");
});

test("a choice goes into every list that exists and the plain one, and never into one that could not be read", () => {
    const lists = [
        { name: "Hyprland-xdg-terminals.list", text: "kitty.desktop\n# mine\n", exists: true, readable: true },
        { name: "hyprland-xdg-terminals.list", text: "", exists: false, readable: true },
        { name: "locked-xdg-terminals.list", text: "", exists: true, readable: false },
        { name: "xdg-terminals.list", text: "", exists: false, readable: true }
    ];
    assert.deepStrictEqual(Defaults.terminalWrites(lists, "foot.desktop"), [
        { name: "Hyprland-xdg-terminals.list", text: "foot.desktop\nkitty.desktop\n# mine\n" },
        { name: "xdg-terminals.list", text: "foot.desktop\n" }
    ]);
    assert.deepStrictEqual(Defaults.terminalWrites([{ name: "xdg-terminals.list", text: "", exists: true, readable: false }], "foot.desktop"), []);
});
