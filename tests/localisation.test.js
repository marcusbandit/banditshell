const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/localisation.js"), "utf8");
const Localisation = new Function(src + "\nreturn { LANGUAGES, FORMATS, parseZoneTable, distanceKm, nearestZone, placeOfZone, parseWhereAmI, parseLocaleStatus, parseLocales, hasLocale, languageOf, formatsOf, choices, currentChoice, labelOf, localeArguments, zoneChoices };")();

const TABLE = [
    "# comment line",
    "DK\t+5540+01235\tEurope/Copenhagen",
    "DE,DK,NO,SE,SJ\t+5230+01322\tEurope/Berlin\tmost of Germany",
    "GB,GG,IM,JE\t+513030-0000731\tEurope/London",
    "US\t+404251-0740023\tAmerica/New_York\tEastern (most areas)",
    "AU\t-3352+15113\tAustralia/Sydney\tNew South Wales (most areas)",
    "broken line",
    "XX\tnot-coordinates\tNowhere/Land"
].join("\n");

test("the zone table reads degrees and minutes, with or without seconds, and skips what it cannot read", () => {
    const rows = Localisation.parseZoneTable(TABLE);
    assert.deepStrictEqual(rows.map(r => r.zone), ["Europe/Copenhagen", "Europe/Berlin", "Europe/London", "America/New_York", "Australia/Sydney"]);
    const cph = rows[0];
    assert.ok(Math.abs(cph.lat - 55.6667) < 0.001 && Math.abs(cph.lon - 12.5833) < 0.001);
    const london = rows[2];
    assert.ok(Math.abs(london.lat - 51.5083) < 0.001 && Math.abs(london.lon + 0.1253) < 0.001);
    const ny = rows[3];
    assert.ok(ny.lat > 40.7 && ny.lon < -74);
    assert.ok(rows[4].lat < 0 && rows[4].lon > 150);
    assert.deepStrictEqual(rows[1].countries, ["DE", "DK", "NO", "SE", "SJ"]);
});

test("a zone named twice is kept once, the first time it appears", () => {
    const rows = Localisation.parseZoneTable("DK\t+5540+01235\tEurope/Copenhagen\nDK\t+0000+00000\tEurope/Copenhagen");
    assert.strictEqual(rows.length, 1);
    assert.ok(rows[0].lat > 55);
});

test("the nearest zone is the one with the closest coordinates", () => {
    const rows = Localisation.parseZoneTable(TABLE);
    assert.strictEqual(Localisation.nearestZone(rows, { lat: 55.7, lon: 12.5 }).zone, "Europe/Copenhagen");
    assert.strictEqual(Localisation.nearestZone(rows, { lat: 52.0, lon: 13.0 }).zone, "Europe/Berlin");
    assert.strictEqual(Localisation.nearestZone(rows, { lat: 40.7, lon: -74.0 }).zone, "America/New_York");
    assert.strictEqual(Localisation.nearestZone(rows, { lat: -34, lon: 151 }).zone, "Australia/Sydney");
    assert.strictEqual(Localisation.nearestZone([], { lat: 0, lon: 0 }), null);
});

test("distances are great-circle kilometres", () => {
    const d = Localisation.distanceKm({ lat: 55.67, lon: 12.58 }, { lat: 52.52, lon: 13.4 });
    assert.ok(d > 340 && d < 370, `${d}`);
    assert.strictEqual(Localisation.distanceKm({ lat: 1, lon: 1 }, { lat: 1, lon: 1 }), 0);
});

test("the place of a zone comes from the table, and an unknown zone has none", () => {
    const rows = Localisation.parseZoneTable(TABLE);
    assert.ok(Math.abs(Localisation.placeOfZone(rows, "Europe/Copenhagen").lat - 55.667) < 0.01);
    assert.strictEqual(Localisation.placeOfZone(rows, "Mars/Base"), null);
});

test("geoclue's demo output gives a position, and silence gives none", () => {
    const out = "Client object: /org/freedesktop/GeoClue2/Client/1\nNew location:\nLatitude:    55.676100°\nLongitude:   12.568300°\nAccuracy:    3000.000000 meters\n";
    assert.deepStrictEqual(Localisation.parseWhereAmI(out), { lat: 55.6761, lon: 12.5683 });
    assert.deepStrictEqual(Localisation.parseWhereAmI("Latitude: -33,87°\nLongitude: 151,21°"), { lat: -33.87, lon: 151.21 });
    assert.strictEqual(Localisation.parseWhereAmI(""), null);
    assert.strictEqual(Localisation.parseWhereAmI("Latitude: 999\nLongitude: 12"), null);
});

const STATUS = [
    "System Locale: LANG=en_DK.UTF-8",
    "                LC_NUMERIC=da_DK.UTF-8",
    "                LC_PAPER=da_DK.UTF-8",
    "       VC Keymap: us",
    "      X11 Layout: us"
].join("\n");

test("localectl status gives the language and the formats, over several lines", () => {
    const locale = Localisation.parseLocaleStatus(STATUS);
    assert.deepStrictEqual(locale, { LANG: "en_DK.UTF-8", LC_NUMERIC: "da_DK.UTF-8", LC_PAPER: "da_DK.UTF-8" });
    assert.strictEqual(Localisation.languageOf(locale), "en_DK.UTF-8");
    assert.strictEqual(Localisation.formatsOf(locale), "da_DK.UTF-8");
    assert.strictEqual(Localisation.formatsOf({ LANG: "en_GB.UTF-8" }), "en_GB.UTF-8");
    assert.deepStrictEqual(Localisation.parseLocaleStatus("System Locale: n/a"), {});
});

test("generated locales are matched however utf-8 is spelled", () => {
    const available = Localisation.parseLocales("C.UTF-8\nen_DK.UTF-8\n");
    assert.ok(Localisation.hasLocale(available, "en_DK.utf8"));
    assert.ok(Localisation.hasLocale(available, "EN_DK.UTF-8"));
    assert.ok(!Localisation.hasLocale(available, "da_DK.UTF-8"));
});

test("a locale that is not generated is listed but marked", () => {
    const available = ["C.UTF-8", "en_GB.UTF-8"];
    const list = Localisation.choices(Localisation.LANGUAGES, available);
    assert.deepStrictEqual(list[0], ["en_GB.UTF-8", "English (UK)"]);
    assert.deepStrictEqual(list[1], ["en_US.UTF-8", "English (US) · not set up on this machine"]);
    assert.deepStrictEqual(list[2], ["da_DK.UTF-8", "Dansk · not set up on this machine"]);
});

test("the current locale shows as a choice when it is one, and as itself when it is not", () => {
    assert.strictEqual(Localisation.currentChoice(Localisation.LANGUAGES, "en_gb.utf8"), "en_GB.UTF-8");
    assert.strictEqual(Localisation.currentChoice(Localisation.LANGUAGES, "en_DK.UTF-8"), "en_DK.UTF-8");
    assert.strictEqual(Localisation.labelOf(Localisation.FORMATS, "da_DK.UTF-8"), "Denmark");
    assert.strictEqual(Localisation.labelOf(Localisation.FORMATS, "fr_FR.UTF-8"), "fr_FR.UTF-8");
});

test("changing the language keeps the formats, and changing the formats keeps the language", () => {
    const locale = { LANG: "en_GB.UTF-8", LC_NUMERIC: "da_DK.UTF-8", LC_PAPER: "da_DK.UTF-8" };
    assert.deepStrictEqual(Localisation.localeArguments(locale, { language: "da_DK.UTF-8" }), ["LANG=da_DK.UTF-8", "LC_NUMERIC=da_DK.UTF-8", "LC_PAPER=da_DK.UTF-8"]);
    assert.deepStrictEqual(Localisation.localeArguments(locale, { formats: "en_US.UTF-8" }), ["LANG=en_GB.UTF-8", "LC_NUMERIC=en_US.UTF-8", "LC_PAPER=en_US.UTF-8", "LC_MONETARY=en_US.UTF-8", "LC_MEASUREMENT=en_US.UTF-8"]);
    assert.deepStrictEqual(Localisation.localeArguments({}, { formats: "en_US.UTF-8" }), ["LANG=en_US.UTF-8", "LC_NUMERIC=en_US.UTF-8", "LC_MONETARY=en_US.UTF-8", "LC_MEASUREMENT=en_US.UTF-8", "LC_PAPER=en_US.UTF-8"]);
});

test("the zone choices start at the zone in use, then the world clocks, then the well-known ones", () => {
    const known = ["Europe/Copenhagen", "Europe/London", "America/New_York", "Asia/Tokyo", "Pacific/Chatham"];
    const list = Localisation.zoneChoices("Europe/Copenhagen", ["Pacific/Chatham", "Asia/Tokyo"], known);
    assert.deepStrictEqual(list, ["Europe/Copenhagen", "Pacific/Chatham", "Asia/Tokyo", "America/New_York", "Europe/London"]);
    assert.ok(Localisation.zoneChoices("Mars/Base", [], known).includes("Mars/Base"));
    assert.ok(Localisation.zoneChoices("Europe/Copenhagen", [], []).includes("Asia/Tokyo"));
});
