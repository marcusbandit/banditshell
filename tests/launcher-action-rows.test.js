const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Ranking = lib("services/ranking.js", ["place"]);

const Actions = lib("services/shell-actions.js", ["ask", "panelNames", "argumentsOf", "labelOf", "parseTable", "matching", "ambient", "argv"]);

const TABLE = [
    "# api 1",
    "# id\tstatus\tsince\targv\tdescription",
    "launcher.toggle\tstable\t1\tpanel launcher toggle\tOpen or close the launcher",
    "launcher.run\tstable\t1\tpanel launcher run\tRun an app or a launcher row (argument: app or row id)",
    "panel.*.toggle\tstable\t1\tpanel $1 toggle\tOpen or close a panel or menu (optional argument: screen)",
    "panel.*.status\tstable\t1\tpanel $1 status\tSay whether a panel or menu is open",
    "panel.clipboard.clear\tstable\t1\tpanel clipboard clear\tEmpty the clipboard history",
    "panel.clipboard.list\tstable\t1\tpanel clipboard list\tList the clipboard history",
    "screen.brightness.set\tstable\t1\tscreen brightness\tSet brightness (argument: percent, +n or -n)",
    "screen.brightness.up\tstable\t1\tscreen brightness +\tBrighter by 10 percent",
    "tablet.pen.area\tstable\t1\ttablet pen area\tMap the pen to a rectangle (arguments: x y width height)",
    "wallpaper.set\tstable\t1\twallpaper set\tWear a file (arguments: file, optional screen or all)",
    "wallpaper.next\tstable\t1\twallpaper next\tNext wallpaper (optional argument: screen or all)",
    "config.get\tstable\t1\tconfig get\tRead a setting (argument: dotted key)",
    "shell.restart\tstable\t1\trestart\tRestart the shell",
    "old.thing\tdeprecated=new.thing\t1\told thing\tAn old verb",
    "broken line"
].join("\n");

const COMMANDS = "verb\tpanel\tthe launcher\nrule\tpanel\nvalues\tpanel\tlauncher clipboard calculator settings\nverb\toutput\tx";

test.describe("asking for an action", () => {
    test.it("answers to action and actions, with words to narrow by", () => {
        assert.deepStrictEqual(Actions.ask("action"), { words: "" });
        assert.deepStrictEqual(Actions.ask("Actions next wallpaper"), { words: "next wallpaper" });
        for (const text of ["activate", "actionable", "reaction", ""])
            assert.strictEqual(Actions.ask(text), null, text);
    });
});

test.describe("reading the action table", () => {
    const panels = Actions.panelNames(COMMANDS);
    const rows = Actions.parseTable(TABLE, panels);
    const ids = rows.map(r => r.id);

    test.it("reads the panel names but never the launcher", () => {
        assert.deepStrictEqual(panels, ["clipboard", "calculator", "settings"]);
        assert.deepStrictEqual(Actions.panelNames("nothing here"), []);
    });

    test.it("leaves out the launcher, the shell, anything that only prints and anything not stable", () => {
        for (const id of ["launcher.toggle", "launcher.run", "panel.clipboard.list", "config.get", "shell.restart", "old.thing", "panel.clipboard.status"])
            assert.ok(!ids.includes(id), id);
    });

    test.it("turns a wildcard id into one row per panel, naming the panel", () => {
        const toggles = rows.filter(r => r.id.endsWith(".toggle"));
        assert.deepStrictEqual(toggles.map(r => r.id), ["panel.clipboard.toggle", "panel.calculator.toggle", "panel.settings.toggle"]);
        assert.strictEqual(toggles[0].label, "Open or close the clipboard");
        assert.strictEqual(toggles[0].args.required, false);
    });

    test.it("takes the label from the description without its argument note", () => {
        assert.strictEqual(rows.find(r => r.id === "screen.brightness.up").label, "Brighter by 10 percent");
        assert.strictEqual(rows.find(r => r.id === "screen.brightness.set").label, "Set brightness");
        assert.strictEqual(Actions.labelOf("open the thing"), "Open the thing");
    });

    test.it("tells required arguments from optional ones", () => {
        const by = id => rows.find(r => r.id === id).args;
        assert.deepStrictEqual(by("screen.brightness.set"), { required: true, plural: false, prompt: "Argument: percent" });
        assert.deepStrictEqual(by("tablet.pen.area"), { required: true, plural: true, prompt: "Arguments: x y width height" });
        assert.deepStrictEqual(by("wallpaper.set"), { required: true, plural: true, prompt: "Arguments: file" });
        assert.strictEqual(by("wallpaper.next").required, false);
        assert.strictEqual(by("screen.brightness.up"), null);
    });

    test.it("marks the ones that empty something", () => {
        assert.strictEqual(rows.find(r => r.id === "panel.clipboard.clear").destructive, true);
        assert.strictEqual(rows.find(r => r.id === "wallpaper.next").destructive, false);
    });
});

test.describe("finding an action", () => {
    const rows = Actions.parseTable(TABLE, Actions.panelNames(COMMANDS));
    const find = words => Actions.matching(rows, words, Ranking.place, 10).map(r => r.id);

    test.it("lists everything for a bare ask and respects the limit", () => {
        assert.strictEqual(find("").length, rows.length);
        assert.strictEqual(Actions.matching(rows, "", Ranking.place, 3).length, 3);
    });

    test.it("matches the description and the id words, every word needed", () => {
        assert.deepStrictEqual(find("empty clipboard"), ["panel.clipboard.clear"]);
        assert.deepStrictEqual(find("wallpaper next"), ["wallpaper.next"]);
        assert.deepStrictEqual(find("brighter"), ["screen.brightness.up"]);
        assert.deepStrictEqual(find("nothing like it"), []);
    });

    test.it("puts the closer label first", () => {
        assert.strictEqual(find("brightness")[0], "screen.brightness.set");
    });
});

test.describe("an action named on its own", () => {
    const rows = Actions.parseTable(TABLE, Actions.panelNames(COMMANDS));

    test.it("scores below half so apps and settings win", () => {
        const found = Actions.ambient(rows, "wallpaper", Ranking.place, 3);
        assert.ok(found.length > 0);
        for (const f of found)
            assert.ok(f.score > 0 && f.score < 0.5, String(f.score));
    });

    test.it("stays quiet for short words and words in the middle of a label", () => {
        assert.deepStrictEqual(Actions.ambient(rows, "wa", Ranking.place, 3), []);
        assert.deepStrictEqual(Actions.ambient(rows, "paper", Ranking.place, 3), []);
    });
});

test.describe("the command an action runs", () => {
    const rows = Actions.parseTable(TABLE, Actions.panelNames(COMMANDS));
    const row = id => rows.find(r => r.id === id);

    test.it("is banditshell action with the id", () => {
        assert.deepStrictEqual(Actions.argv(row("wallpaper.next"), ""), ["action", "wallpaper.next"]);
    });

    test.it("passes one argument whole and several split on spaces", () => {
        assert.deepStrictEqual(Actions.argv(row("screen.brightness.set"), "+10"), ["action", "screen.brightness.set", "+10"]);
        assert.deepStrictEqual(Actions.argv(row("tablet.pen.area"), "0 0 100 200"), ["action", "tablet.pen.area", "0", "0", "100", "200"]);
        assert.deepStrictEqual(Actions.argv(row("wallpaper.next"), "all"), ["action", "wallpaper.next", "all"]);
    });
});
