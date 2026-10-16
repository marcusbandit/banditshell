const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Search = lib("modules/launcher/search.js", ["usableArea", "cellRect", "TILES", "workspaceAsk", "focusWorkspaceAsk", "layoutLabel", "luaLayouts"]);

const WIDE = { x: 1200, y: 240, width: 5120, height: 1440, scale: 1, transform: 0, reserved: [62, 10, 10, 10] };
const TURNED = { x: 0, y: 0, width: 1920, height: 1200, scale: 1, transform: 1, reserved: [62, 10, 10, 10] };
const tile = id => Search.TILES.find(t => t.id === id);

test.describe("where a window snaps", () => {
    test.it("takes the shell's reserved edges and a turned monitor into account", () => {
        assert.deepStrictEqual(Search.usableArea(WIDE), { x: 1262, y: 250, w: 5048, h: 1420 });
        assert.deepStrictEqual(Search.usableArea(TURNED), { x: 62, y: 10, w: 1128, h: 1900 });
        assert.deepStrictEqual(Search.usableArea({ x: 0, y: 0, width: 3840, height: 2160, scale: 2, transform: 0 }), { x: 0, y: 0, w: 1920, h: 1080 });
    });

    test.it("splits the area with the outer gap at the edges and twice the inner gap between", () => {
        const area = { x: 0, y: 0, w: 1000, h: 500 };
        assert.deepStrictEqual(Search.cellRect(area, 10, 5, tile("left-half")), { x: 10, y: 10, w: 485, h: 480 });
        assert.deepStrictEqual(Search.cellRect(area, 10, 5, tile("right-half")), { x: 505, y: 10, w: 485, h: 480 });
        const two = Search.cellRect(area, 10, 5, tile("first-two-thirds"));
        const last = Search.cellRect(area, 10, 5, tile("last-third"));
        assert.strictEqual(two.x + two.w + 10, last.x);
        assert.strictEqual(last.x + last.w, 990);
    });

    test.it("fills the area exactly, whatever the grid", () => {
        const area = { x: 100, y: 50, w: 1700, h: 900 };
        for (const t of Search.TILES) {
            const r = Search.cellRect(area, 10, 5, t);
            assert.ok(r.x >= 110 && r.y >= 60 && r.x + r.w <= 1790 && r.y + r.h <= 940, t.id);
        }
    });

    test.it("has every snap Raycast offers", () => {
        const ids = Search.TILES.map(t => t.id);
        for (const id of ["left-half", "right-half", "top-half", "bottom-half", "first-third", "center-third", "last-third", "first-two-thirds", "last-two-thirds", "top-left-quarter", "bottom-right-quarter", "top-center-sixth", "bottom-left-sixth"])
            assert.ok(ids.includes(id), id);
        assert.strictEqual(new Set(ids).size, ids.length);
    });
});

test.describe("moving and layouts", () => {
    test.it("reads move to workspace", () => {
        assert.strictEqual(Search.workspaceAsk("move to workspace 3"), 3);
        assert.strictEqual(Search.workspaceAsk("move window to 7"), 7);
        assert.strictEqual(Search.workspaceAsk("send to ws 12"), 12);
        assert.strictEqual(Search.workspaceAsk("move to"), 0);
    });

    test.it("reads focus workspace, and keeps it apart from moving a window there", () => {
        for (const text of ["focus workspace 2", "workspace 2", "go to workspace 2", "switch to ws 2", "ws 2"])
            assert.strictEqual(Search.focusWorkspaceAsk(text), 2, text);
        assert.strictEqual(Search.focusWorkspaceAsk("move to workspace 2"), 0);
        assert.strictEqual(Search.workspaceAsk("focus workspace 2"), 0);
    });

    test.it("finds layouts registered in the Lua config and names them", () => {
        assert.deepStrictEqual(Search.luaLayouts(['hl.layout.register("stage", { recalculate = r })', "hl.layout.register('grid', {})\nhl.layout.register(\"stage\", {})"]), ["lua:stage", "lua:grid"]);
        assert.strictEqual(Search.layoutLabel("lua:stage"), "Stage");
        assert.strictEqual(Search.layoutLabel("dwindle"), "Dwindle");
    });
});
