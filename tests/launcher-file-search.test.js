const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync } = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Logic = lib("services/file-search.js", ["findCommands", "grepCommands", "configSearched"]);

const OPTIONS = { fd: "fd", ignoring: false, hidden: "all", home: "/srv/example", configDir: "/srv/example/.config", limit: 600 };

function has(tool) {
    try {
        execFileSync("sh", ["-c", `command -v ${tool}`]);
        return true;
    } catch (e) {
        return false;
    }
}

test.describe("file search command lines", () => {
    test.it("content search reads what was typed from stdin, never from its arguments", () => {
        for (const command of Logic.grepCommands(OPTIONS, null).concat(Logic.grepCommands(OPTIONS, ["/srv/example/a.md"]))) {
            const at = command.indexOf("--file");
            assert.ok(at > 0 && command[at + 1] === "-", command.join(" "));
            assert.strictEqual(command[command.indexOf("--") + 1].indexOf("/srv/example"), 0);
        }
        assert.strictEqual(Logic.grepCommands(OPTIONS, null).length, 2);
        assert.strictEqual(Logic.grepCommands(Object.assign({}, OPTIONS, { hidden: "none" }), null).length, 1);
    });

    test.it("finds the typed words inside a file through stdin", { skip: !has("rg") }, () => {
        const dir = fs.mkdtempSync(path.join(os.tmpdir(), "file-search-"));
        fs.writeFileSync(path.join(dir, "plan.md"), "Book the --ferry ticket\n");
        fs.writeFileSync(path.join(dir, "other.md"), "nothing\n");
        const command = Logic.grepCommands(Object.assign({}, OPTIONS, { home: dir, hidden: "none" }), null)[0];
        let out = "";
        try {
            out = execFileSync(command[0], command.slice(1), { encoding: "utf8", input: "--ferry" });
        } catch (e) {
            out = e.stdout || "";
        }
        assert.deepStrictEqual(out.trim().split("\n"), [`${path.join(dir, "plan.md")}:1:Book the --ferry ticket`]);
    });

    test.it("file name search passes the name after --, so it is never read as a flag", () => {
        const [home, config] = Logic.findCommands(Object.assign({}, OPTIONS, { hidden: ".config" }), "-rf notes");
        assert.deepStrictEqual(home.slice(-3), ["--", "-rf notes", "/srv/example"]);
        assert.deepStrictEqual(config.slice(-3), ["--", "-rf notes", "/srv/example/.config"]);
        assert.ok(Logic.findCommands(OPTIONS, "a/b")[0].includes("--full-path"));
    });
});
