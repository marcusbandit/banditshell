const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/launcher/shellcli.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Cli = new Function(`${src}\nreturn { parseHelp, nextWords, usageFor, ask, detached, tokensOf };`)();
const help = Cli.parseHelp(fs.readFileSync(path.join(ROOT, "cli/banditshell"), "utf8"));
const next = line => Cli.nextWords(help, line).words.map(w => w.word);

test.describe("the CLI's own help, read by the launcher", () => {
    test.it("finds every usage with its description, and the panel names", () => {
        assert.ok(help.usages.length > 60);
        const restart = help.usages.find(u => u.usage === "restart");
        assert.match(restart.about, /stop it and start it again/);
        assert.ok(help.values.panel.includes("launcher") && help.values.panel.includes("wallpaper"));
    });

    test.it("tells a choice from a placeholder", () => {
        assert.deepStrictEqual(Cli.tokensOf("wallpaper [next|prev|clear] [<screen>|all]").map(t => t.kind), ["word", "choice", "slot"]);
        assert.deepStrictEqual(Cli.tokensOf("panel <panel> [screen]").map(t => t.kind), ["word", "slot", "slot"]);
        assert.deepStrictEqual(Cli.tokensOf("screenshot save [--freeze]").map(t => t.kind), ["word", "word", "choice"]);
    });

    test.it("offers the next word the way tab completion in a terminal does", () => {
        assert.ok(next("").includes("restart") && next("").includes("wallpaper"));
        assert.deepStrictEqual(next("re"), ["restart"]);
        assert.deepStrictEqual(next("wallpaper n"), ["next"]);
        assert.ok(next("panel ").includes("launcher") && next("panel ").includes("close"));
        assert.deepStrictEqual(next("panel launcher ").sort(), ["close", "open", "run", "status", "toggle"]);
        assert.deepStrictEqual(next("dev try "), []);
        assert.deepStrictEqual(next("wallpaper nonsense "), []);
        assert.deepStrictEqual(next("restart"), []);
    });

    test.it("keeps a description shared by a group of usages off the single choices", () => {
        const on = Cli.nextWords(help, "wallpaper ").words.find(w => w.word === "on");
        assert.strictEqual(on.about, "");
        const restart = Cli.nextWords(help, "re").words.find(w => w.word === "restart");
        assert.match(restart.about, /start it again/);
    });

    test.it("knows when a line is a whole command", () => {
        assert.strictEqual(Cli.usageFor(help, "restart").usage, "restart");
        assert.strictEqual(Cli.usageFor(help, "wallpaper next").usage, "wallpaper [next|prev|clear] [<screen>|all]");
        assert.strictEqual(Cli.usageFor(help, "panel la"), null);
    });

    test.it("hears banditshell, bandit shell and bandit, and runs the shell's own lifecycle apart", () => {
        assert.strictEqual(Cli.ask("bandit restart"), "restart");
        assert.strictEqual(Cli.ask("banditshell wallpaper next"), "wallpaper next");
        assert.strictEqual(Cli.ask("bandit shell status"), "status");
        assert.strictEqual(Cli.ask("bandit"), "");
        assert.strictEqual(Cli.ask("bandits"), null);
        assert.ok(Cli.detached("restart") && Cli.detached("dev try smart") && !Cli.detached("wallpaper next"));
    });
});
