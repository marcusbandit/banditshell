const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/wheel-pass.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Wheel = new Function(`${src}\nreturn { passes, scrollerAbove };`)();

function flick(contentHeight, height, extra = {}) {
    return { contentY: 0, contentHeight, height, interactive: true, topMargin: 0, bottomMargin: 0, ...extra };
}

function inside(...ancestors) {
    const item = {};
    let child = item;
    for (const a of ancestors) {
        child.parent = a;
        child = a;
    }
    child.parent = null;
    return item;
}

test.describe("wheel over a value control", () => {
    test.it("passes to a page that has room to scroll", () => {
        const slider = inside({}, flick(2000, 600), {});
        assert.strictEqual(Wheel.passes(slider, false, false), true);
    });

    test.it("keeps the wheel when nothing above it scrolls", () => {
        assert.strictEqual(Wheel.passes(inside({}, {}), false, false), false);
        assert.strictEqual(Wheel.passes(inside({}, flick(400, 600)), false, false), false);
    });

    test.it("keeps the wheel while it has focus or is held", () => {
        const slider = inside(flick(2000, 600));
        assert.strictEqual(Wheel.passes(slider, true, false), false);
        assert.strictEqual(Wheel.passes(slider, false, true), false);
    });

    test.it("skips a scroller that is switched off or full and finds the one above", () => {
        const outer = flick(3000, 800);
        assert.strictEqual(Wheel.scrollerAbove(inside(flick(2000, 600, { interactive: false }), outer)), outer);
        assert.strictEqual(Wheel.scrollerAbove(inside(flick(500, 600), outer)), outer);
    });

    test.it("counts the scroller's margins as room", () => {
        assert.strictEqual(Wheel.passes(inside(flick(560, 600, { bottomMargin: 80 })), false, false), true);
    });
});
