const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "modules/files/marks.js"), "utf8");
const Marks = new Function(src + "\nreturn { iconFor };")();

const HOME = "/home/bandit";

function dir(p, home) {
    return Marks.iconFor(p, p.slice(p.lastIndexOf("/") + 1), true, home === undefined ? HOME : home);
}

function file(name) {
    return Marks.iconFor("/some/where/" + name, name, false, HOME);
}

test.describe("marks: the fixed points of a filesystem", () => {
    test.it("names the system directories by absolute path", () => {
        assert.strictEqual(dir("/"), "hard_drive_2");
        assert.strictEqual(dir("/etc"), "tune");
        assert.strictEqual(dir("/home"), "group");
        assert.strictEqual(dir("/usr"), "apps");
        assert.strictEqual(dir("/var"), "database");
        assert.strictEqual(dir("/root"), "admin_panel_settings");
    });

    test.it("does not mistake a folder that merely shares the name", () => {
        assert.strictEqual(dir("/opt/thing/etc"), "");
        assert.strictEqual(dir("/home/bandit/projects/x/var"), "");
    });
});

test.describe("marks: under $HOME", () => {
    test.it("gives the home directory itself a house", () => {
        assert.strictEqual(dir(HOME), "home");
    });

    test.it("gives the XDG directories their own glyphs", () => {
        assert.strictEqual(dir(HOME + "/Downloads"), "download");
        assert.strictEqual(dir(HOME + "/Documents"), "description");
        assert.strictEqual(dir(HOME + "/Pictures"), "image");
        assert.strictEqual(dir(HOME + "/Music"), "music_note");
        assert.strictEqual(dir(HOME + "/Videos"), "movie");
        assert.strictEqual(dir(HOME + "/Desktop"), "desktop_windows");
    });

    test.it("only counts them at the top of the home directory", () => {
        assert.strictEqual(dir(HOME + "/work/Pictures"), "");
        assert.strictEqual(dir(HOME + "/work/Documents"), "");
    });

    test.it("counts nothing as XDG when there is no home to compare against", () => {
        assert.strictEqual(dir("/home/bandit/Pictures", ""), "");
        assert.strictEqual(dir("/home/bandit/Documents", null), "");
    });

    test.it("does not take a home-shaped prefix for the home directory", () => {

        assert.strictEqual(dir("/home/banditbox"), "");
        assert.strictEqual(Marks.iconFor("/home/banditbox/Pictures", "Pictures", true, HOME), "");
    });

    test.it("gives a Downloads outside $HOME no XDG mark", () => {
        assert.strictEqual(dir("/somewhere/else/Downloads"), "");
    });
});

test.describe("marks: folders that mean the same thing anywhere", () => {
    test.it("recognises the furniture of a project", () => {
        assert.strictEqual(dir("/anywhere/at/all/.git"), "history");
        assert.strictEqual(dir(HOME + "/.git"), "history");
        assert.strictEqual(dir("/x/.github"), "integration_instructions");
        assert.strictEqual(dir("/x/node_modules"), "inventory_2");
        assert.strictEqual(dir("/x/src"), "code");
        assert.strictEqual(dir("/x/tests"), "science");
        assert.strictEqual(dir("/x/.ssh"), "key");
    });

    test.it("falls back to the lowercase name", () => {
        assert.strictEqual(dir("/x/SRC"), "code");
        assert.strictEqual(dir("/x/Build"), "construction");
    });

    test.it("says nothing about a folder that is nothing in particular", () => {
        assert.strictEqual(dir("/x/y/whatever"), "");
        assert.strictEqual(dir(HOME + "/notathing"), "");
    });

    test.it("prefers the path over the name", () => {

        assert.strictEqual(dir(HOME + "/.config"), "tune");
        assert.strictEqual(dir("/x/config"), "tune");
    });
});

test.describe("marks: files", () => {
    test.it("says nothing about a plain file", () => {
        assert.strictEqual(file("notes.txt"), "");
        assert.strictEqual(file("main.c"), "");
        assert.strictEqual(file("vt.js"), "");
    });

    test.it("knows a README whatever case it is written in", () => {
        assert.strictEqual(file("README.md"), "menu_book");
        assert.strictEqual(file("readme.md"), "menu_book");
        assert.strictEqual(file("ReAdMe.Md"), "menu_book");
        assert.strictEqual(file("README"), "menu_book");
        assert.strictEqual(file("README.txt"), "menu_book");
    });

    test.it("knows the other conventions by exact name", () => {
        assert.strictEqual(file("LICENSE"), "balance");
        assert.strictEqual(file("COPYING"), "balance");
        assert.strictEqual(file("Makefile"), "construction");
        assert.strictEqual(file("Dockerfile"), "deployed_code");
        assert.strictEqual(file("package.json"), "inventory_2");
        assert.strictEqual(file("Cargo.toml"), "inventory_2");
        assert.strictEqual(file(".gitignore"), "history");
        assert.strictEqual(file(".env"), "key");
        assert.strictEqual(file("shell.qml"), "widgets");
        assert.strictEqual(file("CLAUDE.md"), "smart_toy");
        assert.strictEqual(file("AGENTS.md"), "smart_toy");
    });

    test.it("does not give a file a folder's mark", () => {
        assert.strictEqual(Marks.iconFor("/x/src", "src", false, HOME), "");
        assert.strictEqual(Marks.iconFor("/etc", "etc", false, HOME), "");
    });

    test.it("does not give a folder a file's mark", () => {
        assert.strictEqual(Marks.iconFor("/x/README.md", "README.md", true, HOME), "");
    });
});
