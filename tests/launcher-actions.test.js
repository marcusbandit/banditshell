const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Search = lib("modules/launcher/search.js", ["timerAsk", "reminderAsk", "volumeAsk", "zoneAsk", "zoneMatches", "readOffsets", "killAsk", "readProcesses", "spanText"]);

const cityOf = id => id.slice(id.lastIndexOf("/") + 1).replace(/_/g, " ");

test.describe("timerAsk", () => {
    test.it("reads the length before or after the word timer", () => {
        assert.deepStrictEqual(Search.timerAsk("timer 5m"), { seconds: 300, label: "" });
        assert.deepStrictEqual(Search.timerAsk("timer 5"), { seconds: 300, label: "" });
        assert.deepStrictEqual(Search.timerAsk("timer 1h 30 min tea"), { seconds: 5400, label: "tea" });
        assert.deepStrictEqual(Search.timerAsk("timer for 90s for eggs"), { seconds: 90, label: "eggs" });
        assert.deepStrictEqual(Search.timerAsk("10 min timer"), { seconds: 600, label: "" });
        assert.deepStrictEqual(Search.timerAsk("2,5 minutes timer pasta"), { seconds: 150, label: "pasta" });
    });

    test.it("leaves everything else alone", () => {
        for (const t of ["timer", "timer tea", "timers", "5m", "5 mo timer", "time 5m"])
            assert.strictEqual(Search.timerAsk(t), null, t);
    });
});

test.describe("reminderAsk", () => {
    test.it("takes a clock time in front or behind", () => {
        assert.deepStrictEqual(Search.reminderAsk("remind me at 15:00 to call mum"), { at: { hour: 15, minute: 0 }, label: "call mum" });
        assert.deepStrictEqual(Search.reminderAsk("remind me 3pm call mum"), { at: { hour: 15, minute: 0 }, label: "call mum" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at 9 stand up"), { at: { hour: 9, minute: 0 }, label: "stand up" });
        assert.deepStrictEqual(Search.reminderAsk("remind me to water plants at 18.30"), { at: { hour: 18, minute: 30 }, label: "water plants" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at 12am"), { at: { hour: 0, minute: 0 }, label: "" });
    });

    test.it("takes a span in front or behind", () => {
        assert.deepStrictEqual(Search.reminderAsk("remind me in 20 min to stretch"), { seconds: 1200, label: "stretch" });
        assert.deepStrictEqual(Search.reminderAsk("remind me to stretch in 1h"), { seconds: 3600, label: "stretch" });
    });

    test.it("needs a real time", () => {
        for (const t of ["remind me", "remind me to call mum", "remind me 3 things", "remind me at 25:00 x", "remind me at 13pm x", "remind me in a bit", "reminders"])
            assert.strictEqual(Search.reminderAsk(t), null, t);
    });
});

test.describe("volumeAsk", () => {
    test.it("reads a level", () => {
        assert.strictEqual(Search.volumeAsk("volume 50"), 50);
        assert.strictEqual(Search.volumeAsk("set volume to 35%"), 35);
        assert.strictEqual(Search.volumeAsk("vol 0"), 0);
        assert.strictEqual(Search.volumeAsk("volume 200"), -1);
        assert.strictEqual(Search.volumeAsk("volume up"), -1);
    });
});

test.describe("zoneAsk and zoneMatches", () => {
    const zones = ["Asia/Tokyo", "Europe/London", "America/New_York", "America/Los_Angeles", "Etc/GMT+1", "UTC", "Europe/Copenhagen", "America/Argentina/Buenos_Aires"];

    test.it("reads the place", () => {
        assert.strictEqual(Search.zoneAsk("time in tokyo"), "tokyo");
        assert.strictEqual(Search.zoneAsk("what time is it in New York"), "new york");
        assert.strictEqual(Search.zoneAsk("tokyo time"), "tokyo");
        assert.strictEqual(Search.zoneAsk("time london"), "london");
        assert.strictEqual(Search.zoneAsk("time in"), "");
        assert.strictEqual(Search.zoneAsk("timer 5m"), "");
    });

    test.it("finds zones by city and by alias", () => {
        assert.deepStrictEqual(Search.zoneMatches(zones, "tokyo", cityOf), ["Asia/Tokyo"]);
        assert.deepStrictEqual(Search.zoneMatches(zones, "new york", cityOf), ["America/New_York"]);
        assert.deepStrictEqual(Search.zoneMatches(zones, "sf", cityOf), ["America/Los_Angeles"]);
        assert.deepStrictEqual(Search.zoneMatches(zones, "buenos", cityOf), ["America/Argentina/Buenos_Aires"]);
        assert.deepStrictEqual(Search.zoneMatches(zones, "format", cityOf), []);
    });

    test.it("reads date +%z output", () => {
        assert.deepStrictEqual(Search.readOffsets("Asia/Tokyo +0900\nAmerica/St_Johns -0230\n"), { "Asia/Tokyo": 540, "America/St_Johns": -150 });
    });
});

test.describe("killAsk and readProcesses", () => {
    test.it("reads the filter", () => {
        assert.strictEqual(Search.killAsk("kill"), "");
        assert.strictEqual(Search.killAsk("kill Firefox"), "firefox");
        assert.strictEqual(Search.killAsk("force quit steam"), "steam");
        assert.strictEqual(Search.killAsk("killer"), null);
    });

    test.it("parses ps lines and skips names", () => {
        const out = "  412 812344 firefox\n  99 1200 ps\n 7 50 Isolated Web Co\n";
        assert.deepStrictEqual(Search.readProcesses(out, ["ps"]), [
            { pid: 412, kb: 812344, name: "firefox" },
            { pid: 7, kb: 50, name: "Isolated Web Co" }
        ]);
    });
});

test.describe("spanText", () => {
    test.it("says a span in short words", () => {
        assert.strictEqual(Search.spanText(300), "5 min");
        assert.strictEqual(Search.spanText(5430), "1 h 30 min 30 s");
    });
});

test.describe("actions are caught before the calculator", () => {
    test.it("matches one action parser", () => {
        for (const t of ["timer 5m", "5 min timer", "remind me at 15:00 to call mum", "remind me in 20m to stretch", "volume 50", "time in tokyo", "kill firefox"]) {
            const caught = !!Search.timerAsk(t) || !!Search.reminderAsk(t) || Search.volumeAsk(t) >= 0 || !!Search.zoneAsk(t) || Search.killAsk(t) !== null;
            assert.ok(caught, t);
        }
    });
});
