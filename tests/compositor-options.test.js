const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/compositor-options.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Options = new Function(src + "\nreturn { batch, readOptions };")();

const captured = fs.readFileSync(path.join(ROOT, "tests/fixtures/hyprctl/getoption-batch.txt"), "utf8");

function fakeHyprctl(batch, missing) {
    const answers = new Map(captured.split("\n").filter(line => line.startsWith("{")).map(line => [JSON.parse(line).option, line]));
    return batch.split(";").map(part => part.trim().replace(/^getoption\s+/, ""))
        .map(name => name === missing || !answers.has(name) ? "no such option" : answers.get(name))
        .join("\n\n\n") + "\n";
}

const EVERY = {
    rounding: 30,
    roundingPower: 4,
    gapsOut: 10,
    gapsIn: 5,
    borderSize: 2,
    naturalScrollMouse: false,
    naturalScrollTouchpad: true
};

test("reads every option from a real hyprctl batch", () => {
    assert.deepStrictEqual(Options.readOptions(captured), EVERY);
});

test("the batch asks for every option it reads", () => {
    assert.deepStrictEqual(Options.readOptions(fakeHyprctl(Options.batch())), EVERY);
});

test("an option Hyprland lacks reads as null and moves nothing after it", () => {
    const got = Options.readOptions(fakeHyprctl(Options.batch(), "decoration:rounding_power"));
    assert.deepStrictEqual(got, Object.assign({}, EVERY, { roundingPower: null }));
});

test("each option can go missing on its own", () => {
    for (const name of Options.batch().split(";").map(part => part.trim().replace(/^getoption\s+/, ""))) {
        const got = Options.readOptions(fakeHyprctl(Options.batch(), name));
        assert.strictEqual(Object.values(got).filter(v => v === null).length, 1, name);
    }
});

test("output with no answers reads as all null", () => {
    assert.ok(Object.values(Options.readOptions("")).every(v => v === null));
    assert.ok(Object.values(Options.readOptions("HYPRLAND_INSTANCE_SIGNATURE not set!\n")).every(v => v === null));
});
