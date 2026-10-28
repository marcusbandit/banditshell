const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "..", "services/weather.js"), "utf8");
const Forecast = new Function(src + "\nreturn { wttrIcon, wmo, placeOf, coordsOf, wttrDays, outlookUrl, outlookDays, dateOf, upcoming, isToday, weekRange, barOf, rainText, readWttr, failureLook, ago, suggestionQueries, geocodeUrl, editDistance, geocodeResults, suggestPlace, suggestionCommand, typeaheadCommand, placeMatches };")();

function hour(time, code, desc, rain) {
    return { time, weatherCode: String(code), weatherDesc: [{ value: desc }], chanceofrain: String(rain) };
}

const WTTR = {
    nearest_area: [{ areaName: [{ value: "Kongens Lyngby" }], country: [{ value: "Denmark" }], latitude: "55.767", longitude: "12.517" }],
    weather: [
        {
            date: "2026-10-18",
            maxtempC: "11",
            mintempC: "6",
            maxtempF: "52",
            mintempF: "43",
            hourly: [hour("0", 116, "Partly cloudy", 9), hour("1200", 113, "Sunny ", 4), hour("2100", 296, "Light rain", 62)]
        },
        {
            date: "2026-10-19",
            maxtempC: "12",
            mintempC: "7",
            maxtempF: "54",
            mintempF: "45",
            hourly: [hour("0", 122, "Overcast", 0), hour("1200", 122, "Overcast", 10)]
        }
    ]
};

const METEO = {
    daily: {
        time: ["2026-10-18", "2026-10-19", "2026-10-20"],
        weather_code: [2, 3, 65],
        temperature_2m_max: [11.9, 12.2, 8.5],
        temperature_2m_min: [6.9, 7.7, 4.4],
        precipitation_probability_max: [0, 29, null]
    }
};

test("wttr place and coordinates", () => {
    assert.strictEqual(Forecast.placeOf(WTTR), "Kongens Lyngby");
    assert.deepStrictEqual(Forecast.coordsOf(WTTR), { latitude: 55.767, longitude: 12.517 });
    assert.strictEqual(Forecast.placeOf({}), "");
    assert.strictEqual(Forecast.coordsOf({}), null);
    assert.strictEqual(Forecast.coordsOf({ nearest_area: [{ latitude: "x", longitude: "1" }] }), null);
});

test("wttr days in metric", () => {
    const days = Forecast.wttrDays(WTTR, false);
    assert.strictEqual(days.length, 2);
    assert.deepStrictEqual(days[0], { date: "2026-10-18", high: 11, low: 6, icon: "sunny", summary: "Sunny", rain: 62 });
    assert.strictEqual(days[1].icon, "cloud");
    assert.strictEqual(days[1].rain, 10);
});

test("wttr days in imperial", () => {
    const days = Forecast.wttrDays(WTTR, true);
    assert.strictEqual(days[0].high, 52);
    assert.strictEqual(days[0].low, 43);
});

test("wttr days survive missing data", () => {
    assert.deepStrictEqual(Forecast.wttrDays(null, false), []);
    assert.deepStrictEqual(Forecast.wttrDays({ weather: [{ date: "2026-10-18" }] }, false), []);
    const bare = Forecast.wttrDays({ weather: [{ date: "2026-10-18", maxtempC: "3", mintempC: "1" }] }, false);
    assert.strictEqual(bare[0].rain, -1);
    assert.strictEqual(bare[0].icon, "cloud");
});

test("wttr icon keeps the old mapping", () => {
    assert.strictEqual(Forecast.wttrIcon(113, true), "clear_night");
    assert.strictEqual(Forecast.wttrIcon(116, false), "partly_cloudy_day");
    assert.strictEqual(Forecast.wttrIcon(389, false), "thunderstorm");
    assert.strictEqual(Forecast.wttrIcon(302, false), "rainy_heavy");
    assert.strictEqual(Forecast.wttrIcon(999, false), "cloud");
});

test("open-meteo days", () => {
    const days = Forecast.outlookDays(METEO);
    assert.strictEqual(days.length, 3);
    assert.deepStrictEqual(days[0], { date: "2026-10-18", high: 12, low: 7, icon: "partly_cloudy_day", summary: "Partly cloudy", rain: 0, offset: null });
    assert.strictEqual(days[1].icon, "cloud");
    assert.strictEqual(days[1].rain, 29);
    assert.strictEqual(days[2].icon, "rainy_heavy");
    assert.strictEqual(days[2].rain, -1);
    assert.strictEqual(days[2].high, 9);
});

test("open-meteo garbage gives no days", () => {
    assert.deepStrictEqual(Forecast.outlookDays({}), []);
    assert.deepStrictEqual(Forecast.outlookDays({ error: true, reason: "bad" }), []);
});

test("wmo mapping covers every code with an icon and a summary", () => {
    const icons = ["sunny", "partly_cloudy_day", "cloud", "foggy", "rainy", "rainy_heavy", "weather_snowy", "weather_mix", "thunderstorm"];
    const codes = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99];
    for (const code of codes) {
        const info = Forecast.wmo(code);
        assert.ok(icons.includes(info.icon), `${code} -> ${info.icon}`);
        assert.ok(info.summary.length > 0);
    }
    assert.strictEqual(Forecast.wmo(45).icon, "foggy");
    assert.strictEqual(Forecast.wmo(67).icon, "weather_mix");
    assert.strictEqual(Forecast.wmo(86).icon, "weather_snowy");
    assert.strictEqual(Forecast.wmo(96).icon, "thunderstorm");
    assert.strictEqual(Forecast.wmo(1234).icon, "cloud");
});

test("open-meteo url", () => {
    const coords = { latitude: 55.767, longitude: 12.517 };
    const metric = Forecast.outlookUrl(coords, false);
    assert.ok(metric.startsWith("https://api.open-meteo.com/v1/forecast?latitude=55.767&longitude=12.517&"));
    assert.ok(metric.includes("daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"));
    assert.ok(metric.includes("timezone=auto&forecast_days=7"));
    assert.ok(!metric.includes("fahrenheit"));
    assert.ok(Forecast.outlookUrl(coords, true).endsWith("&temperature_unit=fahrenheit"));
});

test("week range and bars", () => {
    const days = Forecast.outlookDays(METEO);
    const range = Forecast.weekRange(days);
    assert.deepStrictEqual(range, { min: 4, max: 12 });
    const first = Forecast.barOf(days[0], range);
    assert.strictEqual(first.from, 3 / 8);
    assert.strictEqual(first.to, 1);
    const last = Forecast.barOf(days[2], range);
    assert.strictEqual(last.from, 0);
    assert.strictEqual(last.to, 5 / 8);
    assert.deepStrictEqual(Forecast.weekRange([]), { min: 0, max: 0 });
    assert.deepStrictEqual(Forecast.barOf({ low: 5, high: 5 }, { min: 5, max: 5 }), { from: 0, to: 1 });
});

test("dates parse as local days", () => {
    const date = Forecast.dateOf("2026-10-18");
    assert.strictEqual(date.getFullYear(), 2026);
    assert.strictEqual(date.getMonth(), 9);
    assert.strictEqual(date.getDate(), 18);
    assert.strictEqual(date.getDay(), 0);
});

test("rain shows from twenty percent", () => {
    assert.strictEqual(Forecast.rainText({ rain: 19 }), "");
    assert.strictEqual(Forecast.rainText({ rain: 20 }), "20%");
    assert.strictEqual(Forecast.rainText({ rain: -1 }), "");
});

test("a wttr answer with a status of 200 gives its data", () => {
    const answer = Forecast.readWttr(JSON.stringify({ ...WTTR, current_condition: [{ temp_C: "9" }] }) + "\n200 0");
    assert.strictEqual(answer.failure, undefined);
    assert.strictEqual(answer.data.current_condition[0].temp_C, "9");
});

test("an unknown place is told apart from a failed fetch", () => {
    const captured = fs.readFileSync(path.join(__dirname, "fixtures/weather/wttr-unknown-place.txt"), "utf8");
    assert.deepStrictEqual(Forecast.readWttr(captured), { failure: "place" });
    assert.deepStrictEqual(Forecast.readWttr("\n000 6"), { failure: "offline" });
    assert.deepStrictEqual(Forecast.readWttr("\n000 7"), { failure: "offline" });
    assert.deepStrictEqual(Forecast.readWttr("\n000 28"), { failure: "service" });
    assert.deepStrictEqual(Forecast.readWttr(""), { failure: "offline" });
    assert.strictEqual(Forecast.readWttr(JSON.stringify({ current_condition: [{ weatherDesc: [{ value: "unknown location" }] }] }) + "\n200 0").failure, undefined);
    assert.deepStrictEqual(Forecast.readWttr("<html>Bad gateway</html>\n502"), { failure: "service" });
    assert.deepStrictEqual(Forecast.readWttr("Sorry, we are running out of queries\n200"), { failure: "service" });
    assert.deepStrictEqual(Forecast.readWttr("{}\n200"), { failure: "service" });
});

test("a failure says what went wrong and offers Try again only where it can work", () => {
    assert.strictEqual(Forecast.failureLook("offline").title, "You're offline");
    assert.strictEqual(Forecast.failureLook("offline").retry, false);
    assert.strictEqual(Forecast.failureLook("service").retry, true);
    assert.strictEqual(Forecast.failureLook("place").retry, false);
    assert.match(Forecast.failureLook("place").detail, /^Change place/);
    assert.doesNotMatch(Forecast.failureLook("place").detail, /config\.json/);
    assert.strictEqual(Forecast.failureLook("service").fix, undefined);
});

test("the age of an older forecast", () => {
    const now = Date.UTC(2026, 9, 25, 12, 0);
    assert.strictEqual(Forecast.ago(now - 20000, now), "just now");
    assert.strictEqual(Forecast.ago(now - 42 * 60000, now), "42 min ago");
    assert.strictEqual(Forecast.ago(now - 179 * 60000, now), "3 h ago");
    assert.strictEqual(Forecast.ago(now - 30 * 3600000, now), "yesterday");
    assert.strictEqual(Forecast.ago(now - 5 * 86400000, now), "5 days ago");
    assert.strictEqual(Forecast.ago(now + 60000, now), "just now");
});

function geocoded(name) {
    return Forecast.geocodeResults(fs.readFileSync(path.join(__dirname, `fixtures/weather/geocode-${name}.txt`), "utf8"));
}

function town(name, country, extra) {
    return { name, country, country_code: country.slice(0, 2).toUpperCase(), feature_code: "PPL", ...extra };
}

test("a misspelt place is looked up whole, then a letter shorter at a time", () => {
    assert.deepStrictEqual(Forecast.suggestionQueries("Lyngbyy"), ["Lyngbyy", "Lyngby", "Lyngb", "Lyng", "Lyn"]);
    assert.deepStrictEqual(Forecast.suggestionQueries("Lyngbyy, Denmark"), ["Lyngbyy", "Lyngby", "Lyngb", "Lyng", "Lyn"]);
    assert.deepStrictEqual(Forecast.suggestionQueries("Copenhgenn").length, 7);
    assert.deepStrictEqual(Forecast.suggestionQueries("New Yrok"), ["New Yrok", "New Yro", "New Yr", "New Y", "New"]);
    assert.deepStrictEqual(Forecast.suggestionQueries("Ny"), []);
    assert.deepStrictEqual(Forecast.suggestionQueries(""), []);
    assert.strictEqual(Forecast.geocodeUrl("Nørre Lyngby"), "https://geocoding-api.open-meteo.com/v1/search?name=N%C3%B8rre%20Lyngby&count=20&language=en&format=json");
});

test("edit distance counts a swap of two letters as one", () => {
    assert.strictEqual(Forecast.editDistance("lyngbyy", "lyngby"), 1);
    assert.strictEqual(Forecast.editDistance("lygnby", "lyngby"), 1);
    assert.strictEqual(Forecast.editDistance("lyngvy", "lyngby"), 1);
    assert.strictEqual(Forecast.editDistance("", "abc"), 3);
    assert.strictEqual(Forecast.editDistance("paris", "paris"), 0);
});

test("a doubled letter suggests the town", () => {
    assert.deepStrictEqual(Forecast.suggestPlace("Lyngbyy", geocoded("lyngbyy")), { name: "Lyngby", country: "Denmark", text: "Lyngby, Denmark" });
});

test("a missing letter suggests the town", () => {
    assert.deepStrictEqual(Forecast.suggestPlace("Copenhgen", geocoded("copenhgen")), { name: "Copenhagen", country: "Denmark", text: "Copenhagen, Denmark" });
});

test("a one-letter typo suggests the town, in any case and accent", () => {
    const results = geocoded("lyngbyy");
    assert.strictEqual(Forecast.suggestPlace("Lyngvy", results).text, "Lyngby, Denmark");
    assert.strictEqual(Forecast.suggestPlace("lygnby", results).text, "Lyngby, Denmark");
    assert.strictEqual(Forecast.suggestPlace("Lyngbo", [town("Lyngbø", "Norway")]).text, "Lyngbø, Norway");
    assert.strictEqual(Forecast.suggestPlace("Lodz", [town("Łódź", "Poland")]).text, "Łódź, Poland");
});

test("of towns sharing a name, the most populous wins unless a country was named", () => {
    assert.strictEqual(Forecast.suggestPlace("Pariss", geocoded("pariss")).text, "Paris, France");
    assert.strictEqual(Forecast.suggestPlace("Pariss, US", geocoded("pariss")).text, "Paris, United States");
    assert.strictEqual(Forecast.suggestPlace("Lyngbyy, Sweden", geocoded("lyngbyy")).text, "Lyngby, Sweden");
    assert.strictEqual(Forecast.suggestPlace("Pariss, Texas", [town("Paris", "France", { population: 2138551 }), town("Paris", "United States", { admin1: "Texas", population: 24782 })]).text, "Paris, Texas, United States");
    assert.strictEqual(Forecast.suggestPlace("Lyngby, Danmark", geocoded("lyngbyy")).text, "Lyngby, Denmark");
    assert.strictEqual(Forecast.suggestPlace("Pariss", [town("Paris", "United States", { population: 24782, feature_code: "PPLA2" }), town("Paris", "France", { population: 2138551, feature_code: "PPLC" })]).text, "Paris, France");
});

test("a closer spelling beats a bigger town", () => {
    assert.strictEqual(Forecast.suggestPlace("Lyngbyy", [town("Lynge", "Denmark", { population: 4425 }), town("Lyngby", "Denmark")]).text, "Lyngby, Denmark");
});

test("no suggestion when nothing is close, or only non-towns are", () => {
    assert.strictEqual(Forecast.suggestPlace("Xqzwvb", geocoded("xqzwvb")), null);
    assert.strictEqual(Forecast.suggestPlace("Lynby", [{ name: "Lynbye Slough", country: "United States", feature_code: "PRK" }]), null);
    assert.strictEqual(Forecast.suggestPlace("Pompei", [town("Pompeii", "Italy", { feature_code: "PPLH" })]), null);
    assert.strictEqual(Forecast.suggestPlace("Lyngbyy", []), null);
    assert.strictEqual(Forecast.suggestPlace("Ly", geocoded("lyngbyy")), null);
});

test("a suggestion never repeats the place as it is written", () => {
    const results = geocoded("lyngbyy");
    assert.strictEqual(Forecast.suggestPlace("Lyngby", results).text, "Lyngby, Denmark");
    assert.strictEqual(Forecast.suggestPlace("lyngby, denmark", results), null);
    assert.strictEqual(Forecast.suggestPlace("Lyngby, Sweden", results), null);
});

test("unreadable geocoder answers are skipped", () => {
    assert.deepStrictEqual(Forecast.geocodeResults(""), []);
    assert.deepStrictEqual(Forecast.geocodeResults('{"error":true,"reason":"x"}\nnot json\n{"results":[{"name":"Lyngby"}]}\n').length, 1);
});

test("the suggestion lookup is one curl over every query, and nothing for a name too short", () => {
    const command = Forecast.suggestionCommand("Lyngbyy, Denmark");
    assert.deepStrictEqual(command.slice(0, 6), ["curl", "-sS", "--max-time", "4", "-w", "\n"]);
    assert.deepStrictEqual(command.slice(6), ["Lyngbyy", "Lyngby", "Lyngb", "Lyng", "Lyn"].map(Forecast.geocodeUrl));
    assert.deepStrictEqual(Forecast.suggestionCommand("Ny"), []);
});

test("a forecast fetched before midnight calls no past day upcoming or Today", () => {
    const days = ["2026-10-27", "2026-10-28", "2026-10-29"].map(date => ({ date, high: 10, low: 2 }));
    const afterMidnight = new Date(2026, 9, 28, 0, 30).getTime();
    assert.deepStrictEqual(Forecast.upcoming(days, afterMidnight).map(d => d.date), ["2026-10-28", "2026-10-29"]);
    assert.ok(Forecast.isToday({ date: "2026-10-28" }, afterMidnight));
    assert.ok(!Forecast.isToday({ date: "2026-10-27" }, afterMidnight));
    assert.deepStrictEqual(Forecast.upcoming(days, new Date(2026, 10, 2, 9).getTime()), []);
    assert.ok(Forecast.isToday({ date: "2026-01-05" }, new Date(2026, 0, 5, 23, 59).getTime()));
});

test("a forecast for a place in another time zone counts today by that place's date", () => {
    const at = Date.UTC(2026, 9, 28, 1, 0);
    const newYork = ["2026-10-27", "2026-10-28"].map(date => ({ date, offset: -4 * 3600 }));
    assert.deepStrictEqual(Forecast.upcoming(newYork, at).map(d => d.date), ["2026-10-27", "2026-10-28"]);
    assert.ok(Forecast.isToday(newYork[0], at));
    const tokyo = { date: "2026-10-29", offset: 9 * 3600 };
    assert.ok(Forecast.isToday(tokyo, Date.UTC(2026, 9, 28, 16, 0)));
    const read = Forecast.outlookDays({ utc_offset_seconds: 3600, daily: { time: ["2026-10-28"], temperature_2m_max: [9], temperature_2m_min: [2], weather_code: [3] } });
    assert.strictEqual(read[0].offset, 3600);
});

test("typing a place asks the geocoder once for the name, never for under three letters", () => {
    assert.deepStrictEqual(Forecast.typeaheadCommand("Pa"), []);
    assert.deepStrictEqual(Forecast.typeaheadCommand("Paris, Tex"), ["curl", "-sS", "--max-time", "4", Forecast.geocodeUrl("Paris")]);
});

test("the type-ahead lists towns that start with what was typed, with the region only where a country has twins", () => {
    const paris = Forecast.geocodeResults(fs.readFileSync(path.join(__dirname, "fixtures/weather/geocode-pariss.txt"), "utf8").split("\n")[1]);
    const listed = Forecast.placeMatches("Paris", paris);
    assert.deepStrictEqual(listed.map(p => p.text), ["Paris, France", "Paris, Texas, United States", "Paris, Tennessee, United States", "Paris, Kentucky, United States"]);
    assert.deepStrictEqual(listed[0], { name: "Paris", region: "Île-de-France Region", country: "France", text: "Paris, France" });
    assert.strictEqual(Forecast.placeMatches("Paris, US", paris)[0].text, "Paris, Texas, United States");
    assert.ok(Forecast.placeMatches("Paris", paris).every(p => p.name.indexOf("Mountain") < 0));
    const lyngby = Forecast.placeMatches("Lyngby", geocoded("lyngbyy"));
    assert.strictEqual(new Set(lyngby.map(p => p.text)).size, lyngby.length);
    assert.deepStrictEqual(Forecast.placeMatches("Xqzwvb", geocoded("xqzwvb")), []);
});
