const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Search = lib("modules/launcher/search.js", ["parentQuery", "sectioned", "aliasTarget", "aliasesById"]);
const Chords = lib("services/chords.js", ["hotkeyCommand", "toggleStep", "sameChord"]);
const Protocol = lib("services/plugin-protocol.js", ["withoutCommands", "commandOf"]);

test.describe("parentQuery", () => {
    test.it("steps from a folder to the one above it", () => {
        assert.strictEqual(Search.parentQuery("~/Projects/banditshell/", "/home/u"), "~/Projects/");
        assert.strictEqual(Search.parentQuery("/etc/systemd/", "/home/u"), "/etc/");
    });

    test.it("treats a half-typed name as its folder", () => {
        assert.strictEqual(Search.parentQuery("~/Projects/ban", "/home/u"), "~/");
    });

    test.it("stops at the root and leaves the home folder for the one above", () => {
        assert.strictEqual(Search.parentQuery("/", "/home/u"), "/");
        assert.strictEqual(Search.parentQuery("/etc/", "/home/u"), "/");
        assert.strictEqual(Search.parentQuery("~/", "/home/u"), "/home/");
    });

    test.it("does nothing outside path mode", () => {
        assert.strictEqual(Search.parentQuery("firefox", "/home/u"), "");
    });
});

test.describe("sectioned", () => {
    test.it("groups actions under Open, Favorites, Shortcuts and Manage without reordering inside a group", () => {
        const out = Search.sectioned([
            { label: "Open" },
            { label: "Pin", section: "Favorites" },
            { label: "Quit" },
            { label: "Add alias", section: "Shortcuts", tucked: true },
            { label: "Force quit", tucked: true },
            { label: "Uninstall", alarm: true }
        ]);
        assert.deepStrictEqual(out.map(a => a.label), ["Open", "Quit", "Pin", "Add alias", "Force quit", "Uninstall"]);
        assert.deepStrictEqual(out.map(a => a.section), ["Open", "Open", "Favorites", "Shortcuts", "Manage", "Manage"]);
    });

    test.it("leaves a single group flat with no headings", () => {
        const flat = [{ label: "Open" }, { label: "Copy" }];
        assert.deepStrictEqual(Search.sectioned(flat), flat);
    });
});

test.describe("disabled aliases", () => {
    const aliases = { ff: { id: "app:firefox", label: "Firefox" }, tm: { id: "app:term", label: "Term", off: true } };

    test.it("do not resolve when typed", () => {
        assert.strictEqual(Search.aliasTarget(aliases, "ff"), "app:firefox");
        assert.strictEqual(Search.aliasTarget(aliases, "tm"), "");
    });

    test.it("are not shown as the alias of their row", () => {
        assert.deepStrictEqual(Search.aliasesById(aliases), { "app:firefox": "ff" });
    });
});

test.describe("app hotkey toggle", () => {
    const here = { address: "0x1", workspace: "2" };
    const away = { address: "0x2", workspace: "special:hidden" };

    test.it("launches when the app has no window", () => {
        assert.strictEqual(Chords.toggleStep([], "0x9").step, "launch");
    });

    test.it("hides every window when one has focus", () => {
        assert.deepStrictEqual(Chords.toggleStep([here, away], "0x1"), { step: "hide", addresses: ["0x1", "0x2"] });
    });

    test.it("brings a hidden window back before focusing", () => {
        assert.deepStrictEqual(Chords.toggleStep([here, away], "0x9"), { step: "bring", addresses: ["0x2"] });
    });

    test.it("focuses a visible window that is not focused", () => {
        assert.deepStrictEqual(Chords.toggleStep([here], "0x9"), { step: "focus", addresses: ["0x1"] });
    });

    test.it("adds the toggle word to the bound command only when asked", () => {
        assert.strictEqual(Chords.hotkeyCommand("app:x", false), "banditshell action launcher.run 'app:x'");
        assert.strictEqual(Chords.hotkeyCommand("app:x", true), "banditshell action launcher.run 'app:x' toggle");
    });
});

test.describe("withoutCommands", () => {
    const plugin = {
        prefix: ["note", "todo"],
        commands: [{ word: "note", arguments: [] }, { word: "todo", arguments: [] }]
    };

    test.it("drops a switched-off command and its prefix word", () => {
        const live = Protocol.withoutCommands(plugin, "p", ["p:todo"]);
        assert.deepStrictEqual(live.commands.map(c => c.word), ["note"]);
        assert.deepStrictEqual(live.prefix, ["note"]);
        assert.strictEqual(Protocol.commandOf(live, "todo buy milk"), null);
    });

    test.it("keeps the plugin as it is when nothing of it is off", () => {
        assert.strictEqual(Protocol.withoutCommands(plugin, "p", ["other:todo"]), plugin);
    });
});
