const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const src = fs.readFileSync(path.join(__dirname, "..", "services/weather.js"), "utf8");
const Forecast = new Function(src + "\nreturn { wttrIcon, wmo, placeOf, coordsOf, wttrDays, outlookUrl, outlookDays, dateOf, weekRange, barOf, rainText, readWttr, failureLook, ago };")();

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
    assert.deepStrictEqual(days[0], { date: "2026-10-18", high: 12, low: 7, icon: "partly_cloudy_day", summary: "Partly cloudy", rain: 0 });
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

test("a failure says what went wrong", () => {
    assert.strictEqual(Forecast.failureLook("offline").title, "Weather unavailable");
    assert.strictEqual(Forecast.failureLook("offline").detail, "This computer is offline");
    assert.strictEqual(Forecast.failureLook("service").detail, "The weather service did not answer");
    assert.match(Forecast.failureLook("place").detail, /config\.json/);
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
