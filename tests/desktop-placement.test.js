const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Place = lib("modules/desktop/placement.js", ["topLeft", "placeAt", "stacked", "sizeUp", "validSize", "isPlace", "badgeSide"]);
const Facts = lib("modules/desktop/weather-facts.js", ["facts", "hours"]);

const area = { x: 40, y: 30, width: 1000, height: 600 };

test("a widget dropped right of centre anchors to the right edge and keeps that gap", () => {
    const place = Place.placeAt(800, 100, 200, 100, area);
    assert.deepStrictEqual(place, { side: "right", edge: "top", x: 40, y: 70 });
    assert.deepStrictEqual(Place.topLeft(place, 200, 100, area), { x: 800, y: 100 });
});

test("a right-anchored widget grows to the left when it gets wider", () => {
    const place = { side: "right", edge: "top", x: 40, y: 70 };
    assert.strictEqual(Place.topLeft(place, 400, 100, area).x, 600);
});

test("a bottom-anchored widget grows upwards", () => {
    const place = Place.placeAt(100, 500, 200, 100, area);
    assert.strictEqual(place.edge, "bottom");
    assert.strictEqual(Place.topLeft(place, 200, 300, area).y, 300);
});

test("a widget dropped past the edge is pulled back inside the area", () => {
    const place = Place.placeAt(-500, 900, 200, 100, area);
    assert.deepStrictEqual(place, { side: "left", edge: "bottom", x: 0, y: 0 });
    assert.deepStrictEqual(Place.topLeft(place, 200, 100, area), { x: 40, y: 530 });
});

test("a widget too big for its spot is shifted to stay on screen", () => {
    const place = { side: "left", edge: "top", x: 900, y: 550 };
    assert.deepStrictEqual(Place.topLeft(place, 300, 200, area), { x: 740, y: 430 });
});

test("unplaced widgets stack in their column, skipping hidden ones", () => {
    const heights = { clock: 200, weather: 0, media: 80, system: 120 };
    assert.deepStrictEqual(Place.stacked("clock", heights, 10), { side: "right", edge: "top", x: 0, y: 0 });
    assert.deepStrictEqual(Place.stacked("media", heights, 10), { side: "right", edge: "top", x: 0, y: 210 });
    assert.deepStrictEqual(Place.stacked("limits", heights, 10), { side: "left", edge: "top", x: 0, y: 130 });
});

test("hover peeks a small widget up to medium and leaves bigger ones alone", () => {
    assert.strictEqual(Place.sizeUp("small"), "medium");
    assert.strictEqual(Place.sizeUp("medium"), "medium");
    assert.strictEqual(Place.sizeUp("large"), "large");
    assert.strictEqual(Place.validSize("huge", "medium"), "medium");
});

test("a saved place must name its edges and offsets", () => {
    assert.ok(Place.isPlace({ side: "left", edge: "bottom", x: 1, y: 2 }));
    assert.ok(!Place.isPlace({ side: "middle", edge: "top", x: 1, y: 2 }));
    assert.ok(!Place.isPlace({ side: "left", edge: "top", x: "a", y: 2 }));
    assert.ok(!Place.isPlace({ side: "left", edge: "top", x: "12", y: 0 }));
    assert.ok(!Place.isPlace(null));
});

test("the pin sits on the corner facing away from the anchored edge", () => {
    assert.strictEqual(Place.badgeSide({ side: "right" }), "left");
    assert.strictEqual(Place.badgeSide({ side: "left" }), "right");
});

test("weather facts read feels-like, wind and humidity in the chosen units", () => {
    const now = { FeelsLikeC: "-1", FeelsLikeF: "30", windspeedKmph: "9", windspeedMiles: "6", winddir16Point: "ESE", humidity: "82" };
    assert.deepStrictEqual(Facts.facts(now, false), { feels: "-1°", wind: "9 km/h ESE", humidity: "82%" });
    assert.deepStrictEqual(Facts.facts(now, true), { feels: "30°", wind: "6 mph ESE", humidity: "82%" });
    assert.deepStrictEqual(Facts.facts({ FeelsLikeC: "-0.4" }, false), { feels: "0°", wind: "", humidity: "" });
    assert.strictEqual(Facts.facts(null, false), null);
});

const day = (date, temps) => ({ date, hourly: temps.map((t, i) => ({ time: String(i * 300), tempC: String(t), weatherCode: "113", chanceofrain: String(i * 10) })) });
const twoDays = { weather: [day("2026-03-04", [1, 2, 3, 4, 5, 6, 7, 8]), day("2026-03-05", [9, 10, 11, 12, 13, 14, 15, 16])] };

test("hourly slots start at the current three-hour block until it ends, then run into tomorrow", () => {
    const at = (h, m) => new Date(2026, 2, 4, h, m).getTime();
    assert.deepStrictEqual(Facts.hours(twoDays, at(19, 30), false, 4).map(s => [s.hour, s.temp]), [[18, 7], [21, 8], [0, 9], [3, 10]]);
    assert.deepStrictEqual(Facts.hours(twoDays, at(20, 59), false, 2).map(s => s.hour), [18, 21]);
    assert.deepStrictEqual(Facts.hours(twoDays, at(21, 0), false, 2).map(s => s.hour), [21, 0]);
    assert.strictEqual(Facts.hours(twoDays, at(19, 30), false, 1)[0].rain, 60);
    assert.deepStrictEqual(Facts.hours({}, at(19, 30), false, 4), []);
});

test("hourly slots follow the clock of the weather's place, not the machine's", () => {
    const place = Object.assign({ current_condition: [{ localObsDateTime: "2026-03-04 01:30 PM", observation_time: "06:30 PM" }] }, twoDays);
    const now = Date.UTC(2026, 2, 4, 18, 30);
    assert.deepStrictEqual(Facts.hours(place, now, false, 3).map(s => s.hour), [12, 15, 18]);
});
