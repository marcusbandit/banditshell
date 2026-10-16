const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Dates = lib("services/dates.js", ["dateAsk", "parseDate", "isoWeek", "between"]);
const Colours = lib("services/colours.js", ["colourAnswer", "parseColour"]);
const Search = lib("modules/launcher/search.js", ["zoneConvertAsk", "readConversion", "ZONE_ABBREVIATIONS"]);
const Money = lib("services/currency.js", ["parse", "total", "readCoins", "coinsIn", "COINS", "coinFeed"]);

const NOW = new Date(2026, 9, 16, 10, 0);
const iso = d => `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
const ask = text => {
    const got = Dates.dateAsk(text, NOW);
    return got && Object.assign({}, got, {
        date: got.date && iso(got.date),
        end: got.end && iso(got.end)
    });
};

test.describe("dates", () => {
    test.it("counts the days until a date, rolling past dates to next year", () => {
        assert.strictEqual(ask("days until christmas").days, 70);
        assert.strictEqual(ask("how many days until 31 mar").date, "2027-03-31");
        assert.strictEqual(ask("days till 2026-12-24").days, 69);
        assert.strictEqual(ask("dage til jul").date, "2026-12-24");
    });

    test.it("counts since and between", () => {
        assert.strictEqual(ask("days since 1 jan").days, 288);
        assert.strictEqual(ask("days between 1 jan and 31 mar").days, 89);
        assert.strictEqual(ask("weeks until christmas").unit, "weeks");
    });

    test.it("reads a weekday a number of weeks away, by the week it falls in", () => {
        assert.strictEqual(ask("monday in 3 weeks").date, "2026-11-02");
        assert.strictEqual(ask("next friday").date, "2026-10-23");
        assert.strictEqual(ask("last monday").date, "2026-10-12");
    });

    test.it("moves by days, weeks, months and years", () => {
        assert.strictEqual(ask("in 3 weeks").date, "2026-11-06");
        assert.strictEqual(ask("10 days ago").date, "2026-10-06");
        assert.strictEqual(ask("45 days from now").date, "2026-11-30");
        assert.strictEqual(Dates.dateAsk("in 1 month", new Date(2026, 0, 31)).date.getDate(), 28);
    });

    test.it("gives the ISO week, including the year-end edges", () => {
        assert.strictEqual(ask("week number").week, 42);
        assert.strictEqual(Dates.isoWeek(new Date(2021, 0, 3)), 53);
        assert.strictEqual(Dates.isoWeek(new Date(2024, 11, 30)), 1);
    });

    test.it("reads holidays, Easter and day-first numbers", () => {
        assert.strictEqual(ask("easter").date, "2027-03-28");
        assert.strictEqual(ask("24/12").date, "2026-12-24");
        assert.strictEqual(ask("12/24").date, "2026-12-24");
        assert.strictEqual(ask("what day is 1 jan 2027").date, "2027-01-01");
        assert.ok(ask("christmas").bare);
    });

    test.it("leaves other words alone", () => {
        for (const text of ["today", "firefox", "may", "5", "blah blah", "31 foo"])
            assert.strictEqual(ask(text), null, text);
    });
});

test.describe("colours", () => {
    test.it("turns hex into rgb and names the hsl too", () => {
        assert.deepStrictEqual(Colours.colourAnswer("#ff8800"), {
            text: "rgb(255, 136, 0)",
            detail: "hsl(32, 100%, 50%)",
            swatch: "#ff8800"
        });
        assert.strictEqual(Colours.colourAnswer("#f80").text, "rgb(255, 136, 0)");
    });

    test.it("goes the other way, and to the form asked for", () => {
        assert.strictEqual(Colours.colourAnswer("rgb(255, 136, 0)").text, "#ff8800");
        assert.strictEqual(Colours.colourAnswer("hsl(32, 100%, 50%)").text, "#ff8800");
        assert.strictEqual(Colours.colourAnswer("#ff8800 to hsl").text, "hsl(32, 100%, 50%)");
        assert.strictEqual(Colours.colourAnswer("rgb(0 0 255) in hex").text, "#0000ff");
    });

    test.it("keeps transparency", () => {
        const got = Colours.colourAnswer("#ff880080");
        assert.strictEqual(got.text, "rgba(255, 136, 0, 0.5)");
        assert.strictEqual(got.swatch, "#80ff8800");
        assert.strictEqual(Colours.colourAnswer("rgba(255, 136, 0, 0.5)").text, "#ff880080");
    });

    test.it("refuses what is not a colour", () => {
        for (const text of ["#ff88f", "#ggg", "rgb(300, 0, 0)", "ff8800", "hsl(10, 200%, 50%)", "#ff8800 to cmyk"])
            assert.strictEqual(Colours.colourAnswer(text), null, text);
    });
});

test.describe("time between places", () => {
    test.it("reads a time, where it is, and where you want it", () => {
        assert.deepStrictEqual(Search.zoneConvertAsk("5pm ldn in sf"), { clock: { hour: 17, minute: 0 }, from: "ldn", to: "sf" });
        assert.deepStrictEqual(Search.zoneConvertAsk("3pm in new york to tokyo"), { clock: { hour: 15, minute: 0 }, from: "new york", to: "tokyo" });
        assert.deepStrictEqual(Search.zoneConvertAsk("5pm in tokyo"), { clock: { hour: 17, minute: 0 }, from: "", to: "tokyo" });
        assert.deepStrictEqual(Search.zoneConvertAsk("9:30 pst"), { clock: { hour: 9, minute: 30 }, from: "pst", to: "" });
        assert.deepStrictEqual(Search.zoneConvertAsk("noon utc to cet"), { clock: { hour: 12, minute: 0 }, from: "utc", to: "cet" });
    });

    test.it("needs a real clock time, so timers and sums stay theirs", () => {
        for (const text of ["5 tokyo", "5m", "timer 5m", "time in tokyo", "remind me at 3pm in london"])
            assert.strictEqual(Search.zoneConvertAsk(text), null, text);
    });

    test.it("reads date's answer and whether the day moved", () => {
        assert.deepStrictEqual(Search.readConversion("02 00 2026-10-17\n2026-10-16\n"), { hour: 2, minute: 0, day: "2026-10-17", shift: 1 });
        assert.strictEqual(Search.readConversion("09 00 2026-10-16\n2026-10-16").shift, 0);
        assert.strictEqual(Search.readConversion("date: invalid date"), null);
    });

    test.it("maps the common abbreviations to real zones", () => {
        for (const zone of Object.values(Search.ZONE_ABBREVIATIONS))
            assert.ok(zone === "UTC" || /^[A-Z][a-z]+\/[A-Za-z_]+$/.test(zone), zone);
    });
});

test.describe("crypto", () => {
    const rates = { USD: 1.08, DKK: 7.46, BTC: 1 / 73055, ETH: 1 / 2177.2 };
    const known = ["EUR", "USD", "DKK", ...Object.keys(Money.COINS)];

    test.it("reads coins by ticker or name, four letters too", () => {
        assert.deepStrictEqual(Money.parse("1 btc in usd", known, "DKK", null), { terms: [{ amount: 1, from: "BTC" }], to: "USD", worked: false });
        assert.strictEqual(Money.parse("0.5 bitcoin", known, "DKK", null).terms[0].from, "BTC");
        assert.strictEqual(Money.parse("100 doge", known, "DKK", null).terms[0].from, "DOGE");
        assert.strictEqual(Money.parse("100 dkk in eth", known, "DKK", null).to, "ETH");
    });

    test.it("converts through euros like any currency", () => {
        const got = Money.total(Money.parse("1 btc in usd", known, "DKK", null), rates);
        assert.ok(Math.abs(got - 73055 * 1.08) < 0.01);
    });

    test.it("reads CoinGecko's prices into rates per euro", () => {
        const got = Money.readCoins('{"bitcoin":{"eur":73055},"ethereum":{"eur":2177.2},"tron":{"eur":0}}');
        assert.strictEqual(got.BTC, 1 / 73055);
        assert.strictEqual(got.TRX, undefined);
        assert.strictEqual(Money.readCoins("not json"), null);
        assert.ok(Money.coinFeed().includes("ids=bitcoin,ethereum"));
    });

    test.it("says when an ask needs coin prices", () => {
        assert.ok(Money.coinsIn(Money.parse("1 btc", known, "DKK", null)));
        assert.ok(!Money.coinsIn(Money.parse("5 usd", known, "DKK", null)));
        assert.ok(!Money.coinsIn(null));
    });
});
