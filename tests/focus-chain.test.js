const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "components/focus-chain.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Chain = new Function(src + "\nreturn { arrange, move, last, first, page, group, reveal, cut, nearest };")();

const box = (x, y, w, h) => ({ x, y, w, h });

const LINE = 42;

const arranged = rects => Chain.arrange(rects, LINE);
const walk = (lines, from, direction) => {
    const seen = [from];
    for (let at = Chain.move(lines, from, direction); at >= 0; at = Chain.move(lines, at, direction))
        seen.push(at);
    return seen;
};

test.describe("arrange", () => {
    test.it("puts a row before the switch and chevron on its line, then the next row", () => {
        const rects = [box(0, 52, 352, 52), box(300, 60, 36, 36), box(0, 0, 352, 52), box(250, 14, 48, 24), box(300, 8, 36, 36)];
        assert.deepStrictEqual(arranged(rects).order, [2, 3, 4, 0, 1]);
        assert.deepStrictEqual(arranged(rects).lines, [0, 0, 0, 1, 1]);
    });

    test.it("keeps the editor of an open card on its own lines below the card's head", () => {
        const rects = [box(0, 0, 352, 236), box(290, 20, 48, 24), box(12, 90, 59, 48), box(100, 90, 59, 48), box(12, 148, 40, 40), box(60, 148, 40, 40)];
        const { order, lines } = arranged(rects);
        assert.deepStrictEqual(order, [0, 1, 2, 3, 4, 5]);
        assert.deepStrictEqual(lines, [0, 0, 1, 1, 2, 2]);
    });

    test.it("reads a button a few pixels lower as part of the same line", () => {
        const rects = [box(200, 4, 100, 40), box(0, 0, 59, 48), box(97, 0, 59, 48), box(352, 1, 86, 40), box(86, 2, 266, 37)];
        const { order, lines } = arranged(rects);
        assert.deepStrictEqual(order, [1, 4, 2, 0, 3]);
        assert.ok(lines.every(n => n === 0));
    });
});

test.describe("move", () => {
    const { lines } = arranged([box(0, 0, 352, 52), box(250, 14, 48, 24), box(300, 8, 36, 36), box(0, 52, 352, 52), box(300, 60, 36, 36)]);

    test.it("steps through every control down, and back up the same way", () => {
        assert.deepStrictEqual(walk(lines, 0, "down"), [0, 1, 2, 3, 4]);
        assert.deepStrictEqual(walk(lines, 4, "up"), [4, 3, 2, 1, 0]);
    });

    test.it("moves sideways only within a line", () => {
        assert.strictEqual(Chain.move(lines, 0, "right"), 1);
        assert.strictEqual(Chain.move(lines, 2, "right"), -1);
        assert.strictEqual(Chain.move(lines, 3, "left"), -1);
        assert.strictEqual(Chain.move(lines, 4, "left"), 3);
    });

    test.it("does nothing from a position that is not in the chain", () => {
        assert.strictEqual(Chain.move(lines, -1, "down"), -1);
        assert.strictEqual(Chain.move(lines, 9, "up"), -1);
    });
});

test.describe("every menu's chain", () => {
    const chains = JSON.parse(fs.readFileSync(path.join(ROOT, "tests/fixtures/menu-chains.json"), "utf8"));

    for (const [menu, { controls, walk: live }] of Object.entries(chains)) {
        test.it(`${menu}: arrows reach every control in the order the live menu walked, and come back the same way`, () => {
            const { order, lines } = arranged(controls);
            const down = walk(lines, 0, "down").map(at => order[at]);
            const up = walk(lines, order.length - 1, "up").map(at => order[at]);
            assert.deepStrictEqual(down, live);
            assert.deepStrictEqual(up, [...down].reverse());
            assert.strictEqual(new Set(down).size, controls.length);
        });
    }

    const named = menu => {
        const { order } = arranged(chains[menu].controls);
        return order.map(i => chains[menu].controls[i].name);
    };
    const following = (list, name, count) => list.slice(list.indexOf(name) + 1, list.indexOf(name) + 1 + count);

    test.it("clock: Down from Add a place reaches both timers, then hours, minutes and seconds", () => {
        const clock = named("clock");
        assert.deepStrictEqual(following(clock, "Button:Add a place", 5), ["ClockCard:of 25:00", "ClockCard:of 1:30", "ClockScrubField:0", "ClockScrubField:0", "ClockScrubField:0"]);
        assert.strictEqual(clock.filter(n => n.startsWith("Button:") && /^Button:\d+m$/.test(n)).length, 4);
    });

    test.it("clock: an open alarm walks its switch, then hours and minutes, then every day and the action", () => {
        const clock = named("clock");
        assert.deepStrictEqual(following(clock, "ClockCard:07:30", 11), ["Toggle:", "ClockScrubField:7", "ClockScrubField:30", "Button:1", "Button:2", "Button:3", "Button:4", "Button:5", "Button:6", "Button:7", "Segments:"]);
    });

    test.it("sound: every mute button, slider and device is a stop", () => {
        const sound = named("audio");
        assert.strictEqual(sound.filter(n => n.startsWith("Slider:")).length, 3);
        assert.ok(sound.indexOf("Icon:mic") < sound.indexOf("Slider:0"));
        assert.deepStrictEqual(sound.slice(-3), ["MenuRow:Rig speakers", "MenuRow:Rig headphones", "MenuRow:Rig microphone"]);
    });

    test.it("tray: a check entry's row comes before its switch, and a branch before its chevron", () => {
        const tray = named("tray");
        assert.deepStrictEqual(following(tray, "MenuRow:Start at login", 1), ["Toggle:"]);
        assert.deepStrictEqual(following(tray, "MenuRow:More options", 1), ["Expander:"]);
    });

    test.it("a menu opened from the keyboard starts on its first full width control, never a stray icon", () => {
        const start = menu => {
            const { order } = arranged(chains[menu].controls);
            const rects = order.map(i => chains[menu].controls[i]);
            return rects[Chain.first(rects, 352)].name;
        };
        assert.strictEqual(start("network"), "MenuRow:Wi-Fi");
        assert.strictEqual(start("bluetooth"), "MenuRow:Bluetooth");
        assert.strictEqual(start("tray"), "MenuRow:Show it");
        assert.match(start("clock"), /^ClockCard/);
    });
});

test.describe("last", () => {
    test.it("ends on the first control of the last line", () => {
        assert.strictEqual(Chain.last([0, 1, 1, 2, 2, 2]), 3);
        assert.strictEqual(Chain.last([0]), 0);
    });
});

test.describe("page", () => {
    const rows = [];
    for (let i = 0; i < 20; i++)
        rows.push(box(0, i * 40, 300, 40));

    test.it("goes as far as a page reaches", () => {
        assert.strictEqual(Chain.page(rows, 0, true, 200), 5);
        assert.strictEqual(Chain.page(rows, 10, false, 200), 5);
    });

    test.it("still moves one when the next row is more than a page away", () => {
        const sparse = [box(0, 0, 300, 40), box(0, 500, 300, 40)];
        assert.strictEqual(Chain.page(sparse, 0, true, 200), 1);
    });

    test.it("stays put at the end", () => {
        assert.strictEqual(Chain.page(rows, 19, true, 200), -1);
    });
});

test.describe("group", () => {
    const groups = ["output", "output", "input", "input", "devices", "devices", "devices"];

    test.it("tabs to the first item of the next group and wraps", () => {
        assert.strictEqual(Chain.group(groups, 0, true), 2);
        assert.strictEqual(Chain.group(groups, 3, true), 4);
        assert.strictEqual(Chain.group(groups, 6, true), 0);
    });

    test.it("shift tabs to the first item of the previous group and wraps", () => {
        assert.strictEqual(Chain.group(groups, 5, false), 2);
        assert.strictEqual(Chain.group(groups, 3, false), 0);
        assert.strictEqual(Chain.group(groups, 1, false), 4);
    });

    test.it("starts at the first or last group when nothing has focus", () => {
        assert.strictEqual(Chain.group(groups, -1, true), 0);
        assert.strictEqual(Chain.group(groups, -1, false), 4);
    });

    test.it("treats every ungrouped item as a group of its own", () => {
        const loose = ["", "", "list", "list", ""];
        assert.strictEqual(Chain.group(loose, 0, true), 1);
        assert.strictEqual(Chain.group(loose, 1, true), 2);
        assert.strictEqual(Chain.group(loose, 2, true), 4);
        assert.strictEqual(Chain.group(loose, 4, true), 0);
    });

    test.it("finds nothing in an empty menu", () => {
        assert.strictEqual(Chain.group([], -1, true), -1);
    });
});

test.describe("reveal", () => {
    test.it("leaves the view alone while the item is inside it", () => {
        assert.strictEqual(Chain.reveal(100, 300, 150, 190, 8), 100);
    });

    test.it("scrolls up just enough to show an item above", () => {
        assert.strictEqual(Chain.reveal(100, 300, 60, 100, 8), 52);
    });

    test.it("scrolls down just enough to show an item below", () => {
        assert.strictEqual(Chain.reveal(100, 300, 380, 420, 8), 128);
    });

    test.it("leaves a long item alone while part of it is in view", () => {
        assert.strictEqual(Chain.reveal(0, 300, 200, 13000, 8), 0);
        assert.strictEqual(Chain.reveal(12900, 300, 0, 13000, 8), 12900);
    });

    test.it("brings the near end of a long item into view", () => {
        assert.strictEqual(Chain.reveal(0, 300, 400, 1400, 8), 392);
        assert.strictEqual(Chain.reveal(2000, 300, 400, 1400, 8), 1108);
    });
});

test.describe("cut", () => {
    test.it("keeps the part of a control a clipping parent still shows", () => {
        assert.deepStrictEqual(Chain.cut(box(0, 0, 300, 100), box(0, 80, 300, 44)), box(0, 80, 300, 20));
    });

    test.it("leaves nothing of a control inside a folded layer", () => {
        const left = Chain.cut(box(0, 120, 300, 0), box(10, 120, 290, 44));
        assert.strictEqual(left.w * left.h, 0);
    });

    test.it("passes a control through when nothing clips it", () => {
        assert.deepStrictEqual(Chain.cut(null, box(1, 2, 3, 4)), box(1, 2, 3, 4));
    });
});

test.describe("nearest", () => {
    test.it("finds the control that took the place of one rebuilt under the keys", () => {
        const rects = [box(0, 0, 300, 40), box(0, 44, 300, 80), box(0, 128, 300, 40)];
        assert.strictEqual(Chain.nearest(rects, box(0, 46, 300, 80)), 1);
    });

    test.it("falls back to a neighbour when the control is gone for good", () => {
        const rects = [box(0, 0, 300, 40), box(250, 44, 50, 40), box(0, 140, 300, 40)];
        assert.strictEqual(Chain.nearest(rects, box(0, 100, 300, 40)), 2);
        assert.strictEqual(Chain.nearest([], box(0, 0, 1, 1)), -1);
    });
});

