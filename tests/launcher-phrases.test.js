const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");

function lib(file, names) {
    const src = fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
    return new Function(`${src}\nreturn { ${names.join(", ")} };`)();
}

const Search = lib("modules/launcher/search.js", ["timerAsk", "leadingSpan", "reminderAsk", "reminderDay", "reminderMoment", "vagueHour", "clockOf", "volumeAsk", "volumeLevelAsk", "LOUDER", "QUIETER", "zoneAsk", "zoneMatches", "namedZones", "placeLabel", "ZONE_REGIONS", "ZONE_CHOICES", "portAsk", "killAsk", "awakeAsk"]);
const Ports = lib("services/ports.js", ["readListeners"]);

const cityOf = id => id.slice(id.lastIndexOf("/") + 1).replace(/_/g, " ");
function systemZones() {
    const out = [];
    try {
        for (const line of fs.readFileSync("/usr/share/zoneinfo/tzdata.zi", "utf8").split("\n")) {
            const parts = line.split(" ");
            if (parts[0] === "Z")
                out.push(parts[1]);
            if (parts[0] === "L")
                out.push(parts[2]);
        }
    } catch (error) {
        return Intl.supportedValuesOf("timeZone");
    }
    return out;
}

function realZone(id) {
    try {
        new Intl.DateTimeFormat("en", { timeZone: id });
        return true;
    } catch (error) {
        return false;
    }
}

const ZONES = systemZones();
const FRIDAY = new Date(2026, 9, 16, 10, 0);
const stamp = ms => {
    const d = new Date(ms);
    const pad = n => String(n).padStart(2, "0");
    return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
};
const when = (text, now) => {
    const ask = Search.reminderAsk(text);
    return ask ? stamp(Search.reminderMoment(ask, now || FRIDAY, 9)) : null;
};

test.describe("spoken spans", () => {
    test.it("reads words for numbers and fractions of an hour", () => {
        const seconds = t => Search.leadingSpan(t, false)?.seconds ?? null;
        assert.strictEqual(seconds("an hour"), 3600);
        assert.strictEqual(seconds("a minute"), 60);
        assert.strictEqual(seconds("half an hour"), 1800);
        assert.strictEqual(seconds("half a minute"), 30);
        assert.strictEqual(seconds("a quarter of an hour"), 900);
        assert.strictEqual(seconds("three quarters of an hour"), 2700);
        assert.strictEqual(seconds("an hour and a half"), 5400);
        assert.strictEqual(seconds("one and a half hours"), 5400);
        assert.strictEqual(seconds("2 and a half minutes"), 150);
        assert.strictEqual(seconds("two minutes"), 120);
        assert.strictEqual(seconds("twenty five minutes"), 1500);
        assert.strictEqual(seconds("forty-five seconds"), 45);
        assert.strictEqual(seconds("a couple of minutes"), 120);
        assert.strictEqual(seconds("a few minutes"), 180);
        assert.strictEqual(seconds("seventeen minutes"), 1020);
        assert.strictEqual(seconds("an hour and 20 minutes"), 4800);
        assert.strictEqual(seconds("seventy five minutes"), 4500);
        assert.strictEqual(seconds("sixty five minutes"), 3900);
        assert.strictEqual(seconds("ninety minutes"), 5400);
        assert.strictEqual(seconds("a couple minutes"), 120);
    });

    test.it("adds a trailing number to the unit before it", () => {
        const span = t => Search.leadingSpan(t, false);
        assert.deepStrictEqual(span("1h30"), { seconds: 5400, rest: "" });
        assert.deepStrictEqual(span("1h 30 tea"), { seconds: 5400, rest: "tea" });
        assert.deepStrictEqual(span("2h05"), { seconds: 7500, rest: "" });
        assert.deepStrictEqual(span("5m30"), { seconds: 330, rest: "" });
        assert.deepStrictEqual(span("5 min 30"), { seconds: 330, rest: "" });
        assert.deepStrictEqual(span("5 min 2 eggs"), { seconds: 300, rest: "2 eggs" });
        assert.deepStrictEqual(span("1h 90"), { seconds: 3600, rest: "90" });
    });

    test.it("still says no to things that are not spans", () => {
        for (const t of ["a bit", "a while", "the hour", "an apple", "half", "minutes"])
            assert.strictEqual(Search.leadingSpan(t, false), null, t);
    });

    test.it("keeps awake for spoken spans too", () => {
        assert.strictEqual(Search.awakeAsk("keep awake for an hour"), 3600);
        assert.strictEqual(Search.awakeAsk("coffee half an hour"), 1800);
    });
});

test.describe("timer phrases", () => {
    const cases = [
        ["set a timer for 5 minutes", 300, ""],
        ["start a 10 minute timer", 600, ""],
        ["timer 1h30", 5400, ""],
        ["timer 1h 30", 5400, ""],
        ["timer 1h30 pasta", 5400, "pasta"],
        ["timer for an hour", 3600, ""],
        ["timer half an hour", 1800, ""],
        ["a minute timer", 60, ""],
        ["start a minute timer", 60, ""],
        ["two minute timer", 120, ""],
        ["timer two minutes", 120, ""],
        ["set timer for an hour and a half", 5400, ""],
        ["countdown 5 min", 300, ""],
        ["start a timer for twenty five minutes called pasta", 1500, "pasta"],
        ["can you set a 3 minute timer for eggs", 180, "eggs"],
        ["set a 25 min timer for focus", 1500, "focus"],
        ["please start a timer for 90 seconds", 90, ""],
        ["set me a timer of 10 minutes", 600, ""],
        ["make a 4 minute timer tea", 240, "tea"],
        ["start the timer for 45 minutes", 2700, ""],
        ["timer for a quarter of an hour", 900, ""],
        ["Set A Timer For 5 Minutes", 300, ""],
        ["timer for 10 min to check oven", 600, "check oven"],
        ["10 min timer to check the oven", 600, "check the oven"],
        ["timer for a couple minutes", 120, ""],
        ["timer for seventy five minutes", 4500, ""]
    ];

    test.it("understands the ways people ask", () => {
        for (const [text, seconds, label] of cases)
            assert.deepStrictEqual(Search.timerAsk(text), { seconds: seconds, label: label }, text);
    });

    test.it("leaves look-alikes alone", () => {
        for (const t of ["set a timer", "start timer", "timer", "timers", "time machine", "set volume to 50", "start firefox", "a timer", "the timer app", "timer settings"])
            assert.strictEqual(Search.timerAsk(t), null, t);
    });
});

test.describe("reminder phrases", () => {
    test.it("reads a day with the time", () => {
        assert.deepStrictEqual(Search.reminderAsk("remind me tomorrow at 9 to call mum"), { at: { hour: 9, minute: 0 }, label: "call mum", day: "tomorrow" });
        assert.deepStrictEqual(Search.reminderAsk("remind me on friday at 15 to pay"), { at: { hour: 15, minute: 0 }, label: "pay", day: "friday" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at 3pm tomorrow"), { at: { hour: 15, minute: 0 }, label: "", day: "tomorrow" });
        assert.deepStrictEqual(Search.reminderAsk("remind me to call mum tomorrow at 3pm"), { at: { hour: 15, minute: 0 }, label: "call mum", day: "tomorrow" });
        assert.deepStrictEqual(Search.reminderAsk("remind me to call mum at 3pm on friday"), { at: { hour: 15, minute: 0 }, label: "call mum", day: "friday" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at 3pm on friday to call mum"), { at: { hour: 15, minute: 0 }, label: "call mum", day: "friday" });
        assert.deepStrictEqual(Search.reminderAsk("remind me tomorrow"), { at: null, label: "", day: "tomorrow" });
        assert.deepStrictEqual(Search.reminderAsk("remind me in 2 days to renew"), { at: null, label: "renew", day: "in 2 days" });
    });

    test.it("reads compact clock times after at, and noon", () => {
        assert.deepStrictEqual(Search.reminderAsk("remind me at 1500 to stretch"), { at: { hour: 15, minute: 0 }, label: "stretch" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at 930 to stand up"), { at: { hour: 9, minute: 30 }, label: "stand up" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at noon to eat"), { at: { hour: 12, minute: 0 }, label: "eat" });
        assert.deepStrictEqual(Search.reminderAsk("remind me at 7 p.m. to cook"), { at: { hour: 19, minute: 0 }, label: "cook" });
        assert.strictEqual(Search.reminderAsk("remind me 1500 things"), null);
        assert.strictEqual(Search.reminderAsk("remind me at 2500 to x"), null);
    });

    test.it("keeps the word that joins the label", () => {
        assert.deepStrictEqual(Search.reminderAsk("remind me about rent in 5m"), { seconds: 300, label: "rent", link: "about" });
        assert.deepStrictEqual(Search.reminderAsk("remind me in 10 min that the oven is on"), { seconds: 600, label: "the oven is on", link: "that" });
        assert.deepStrictEqual(Search.reminderAsk("remind me of the meeting at 14:00"), { at: { hour: 14, minute: 0 }, label: "the meeting", link: "about" });
        assert.deepStrictEqual(Search.reminderAsk("remind me in an hour to stop"), { seconds: 3600, label: "stop" });
    });

    test.it("lands on the right moment", () => {
        assert.strictEqual(when("remind me tomorrow at 9 to call mum"), "2026-10-17 09:00");
        assert.strictEqual(when("remind me at 3pm tomorrow"), "2026-10-17 15:00");
        assert.strictEqual(when("remind me on friday at 15 to pay"), "2026-10-16 15:00");
        assert.strictEqual(when("remind me on friday at 9 to pay"), "2026-10-23 09:00");
        assert.strictEqual(when("remind me next friday at 9 to pay"), "2026-10-23 09:00");
        assert.strictEqual(when("remind me next monday at 10 to file taxes"), "2026-10-19 10:00");
        assert.strictEqual(when("remind me tomorrow"), "2026-10-17 09:00");
        assert.strictEqual(when("remind me tomorrow evening to call"), "2026-10-17 19:00");
        assert.strictEqual(when("remind me tonight at 9 to lock up"), "2026-10-16 21:00");
        assert.strictEqual(when("remind me tonight to lock up"), "2026-10-16 20:00");
        assert.strictEqual(when("remind me this afternoon at 2 to call"), "2026-10-16 14:00");
        assert.strictEqual(when("remind me on 24 dec at 9 to buy gifts"), "2026-12-24 09:00");
        assert.strictEqual(when("remind me on december 24th to buy gifts"), "2026-12-24 09:00");
        assert.strictEqual(when("remind me on 1 jan to plan"), "2027-01-01 09:00");
        assert.strictEqual(when("remind me on 2026-11-02 at 8:15 to vote"), "2026-11-02 08:15");
        assert.strictEqual(when("remind me on 3/11 to renew"), "2026-11-03 09:00");
        assert.strictEqual(when("remind me on the 20th to pay rent"), "2026-10-20 09:00");
        assert.strictEqual(when("remind me on the 2nd to pay rent"), "2026-11-02 09:00");
        assert.strictEqual(when("remind me in 2 days to renew"), "2026-10-18 09:00");
        assert.strictEqual(when("remind me in a week to check"), "2026-10-23 09:00");
        assert.strictEqual(when("remind me the day after tomorrow at 18 to pack"), "2026-10-18 18:00");
        assert.strictEqual(when("remind me at 9 tomorrow morning"), "2026-10-17 09:00");
        assert.strictEqual(when("remind me at 9 to x"), "2026-10-17 09:00");
        assert.strictEqual(when("remind me at 11 to x"), "2026-10-16 11:00");
        assert.strictEqual(when("remind me about rent in 5m"), "2026-10-16 10:05");
        assert.strictEqual(when("remind me on wednesday evening to call"), "2026-10-21 19:00");
        assert.strictEqual(when("remind me monday morning to x"), "2026-10-19 09:00");
        assert.strictEqual(when("remind me next tuesday afternoon at 3 to x"), "2026-10-20 15:00");
        assert.strictEqual(when("remind me in ten days to x"), "2026-10-26 09:00");
        assert.deepStrictEqual(Search.reminderAsk("remind me on wednesday evening to call"), { at: null, label: "call", day: "wednesday evening" });
    });

    test.it("reads a bare hour on a 12 hour clock as the next one coming", () => {
        const ask = Search.reminderAsk("remind me at 5 to leave");
        assert.ok(Search.vagueHour("remind me at 5 to leave"));
        assert.ok(!Search.vagueHour("remind me at 5pm to leave"));
        assert.ok(!Search.vagueHour("remind me at 5:30 to leave"));
        assert.ok(!Search.vagueHour("remind me at 17 to leave"));
        assert.strictEqual(stamp(Search.reminderMoment(ask, FRIDAY, 9, true)), "2026-10-16 17:00");
        assert.strictEqual(stamp(Search.reminderMoment(ask, FRIDAY, 9, false)), "2026-10-17 05:00");
        assert.strictEqual(stamp(Search.reminderMoment(Search.reminderAsk("remind me at 11 to x"), FRIDAY, 9, true)), "2026-10-16 11:00");
        assert.strictEqual(stamp(Search.reminderMoment(Search.reminderAsk("remind me at 5 to x"), new Date(2026, 9, 16, 22, 0), 9, true)), "2026-10-17 05:00");
    });

    test.it("uses the configured hour when no time is given", () => {
        assert.strictEqual(stamp(Search.reminderMoment(Search.reminderAsk("remind me tomorrow"), FRIDAY, 7)), "2026-10-17 07:00");
    });

    test.it("says when the moment has passed", () => {
        assert.strictEqual(Search.reminderMoment(Search.reminderAsk("remind me today at 9 to x"), FRIDAY, 9), 0);
        assert.strictEqual(Search.reminderMoment(Search.reminderAsk("remind me this morning to x"), FRIDAY, 9), 0);
        assert.strictEqual(Search.reminderMoment(Search.reminderAsk("remind me on 31/02 to x"), FRIDAY, 9), 0);
    });

    test.it("does not read a day out of the middle of a label", () => {
        assert.deepStrictEqual(Search.reminderAsk("remind me to plan monday's meeting at 14:00"), { at: { hour: 14, minute: 0 }, label: "plan monday's meeting" });
    });

    test.it("still refuses what is not a reminder", () => {
        for (const t of ["remind me", "remind me to call mum", "remind me 3 things", "remind me at 25:00 x", "remind me in a bit", "reminders", "remind me later"])
            assert.strictEqual(Search.reminderAsk(t), null, t);
    });
});

test.describe("volume phrases", () => {
    test.it("reads levels over the limit so the row can say so", () => {
        assert.strictEqual(Search.volumeLevelAsk("volume 200"), 200);
        assert.strictEqual(Search.volumeAsk("volume 200"), -1);
        assert.strictEqual(Search.volumeLevelAsk("set the volume to 80 percent"), 80);
        assert.strictEqual(Search.volumeLevelAsk("turn the volume to 30"), 30);
        assert.strictEqual(Search.volumeLevelAsk("volume up to 70%"), 70);
        assert.strictEqual(Search.volumeLevelAsk("volume up"), -1);
        assert.strictEqual(Search.volumeLevelAsk("volume up 10"), -1);
        assert.strictEqual(Search.volumeLevelAsk("volume 1000"), -1);
    });

    test.it("hears louder and quieter", () => {
        for (const t of ["louder", "Louder", "turn it up", "turn up the volume", "turn the music up", "volume up", "raise the volume", "increase volume", "make it louder"])
            assert.ok(Search.LOUDER.test(t), t);
        for (const t of ["quieter", "softer", "turn it down", "turn down the volume", "volume down", "lower the volume", "reduce volume", "too loud"])
            assert.ok(Search.QUIETER.test(t), t);
        for (const t of ["louder than bombs", "turn", "loud", "volume", "turn off"])
            assert.ok(!Search.LOUDER.test(t) && !Search.QUIETER.test(t), t);
    });
});

test.describe("time zone places", () => {
    test.it("reads more ways of asking", () => {
        assert.strictEqual(Search.zoneAsk("what's the time in germany"), "germany");
        assert.strictEqual(Search.zoneAsk("whats the time in Texas?"), "texas");
        assert.strictEqual(Search.zoneAsk("what time is it in india right now"), "india");
        assert.strictEqual(Search.zoneAsk("time now in japan"), "japan");
        assert.strictEqual(Search.zoneAsk("current time in tokyo"), "tokyo");
        assert.strictEqual(Search.zoneAsk("tokyo time now"), "tokyo");
        assert.strictEqual(Search.zoneAsk("london time"), "london");
    });

    test.it("leaves everyday phrases with time in them alone", () => {
        for (const t of ["time out", "current time", "time zone", "time machine", "lunch time", "bed time", "prime time", "epoch time", "time to relax", "unix time", "screen time", "time lapse", "time tracker"])
            assert.strictEqual(Search.zoneAsk(t), "", t);
    });

    test.it("maps countries and states to zones", () => {
        const match = place => Search.zoneMatches(ZONES, place, cityOf, "Europe/Copenhagen");
        assert.deepStrictEqual(match("india"), ["Asia/Kolkata"]);
        assert.deepStrictEqual(match("germany"), ["Europe/Berlin"]);
        assert.deepStrictEqual(match("california"), ["America/Los_Angeles"]);
        assert.deepStrictEqual(match("texas"), ["America/Chicago"]);
        assert.deepStrictEqual(match("the netherlands"), ["Europe/Amsterdam"]);
        assert.deepStrictEqual(match("usa"), ["America/New_York", "America/Chicago", "America/Denver", "America/Los_Angeles"]);
        assert.deepStrictEqual(match("australia").length, 4);
        assert.deepStrictEqual(match("utc"), ["UTC"]);
        assert.deepStrictEqual(match("tokyo"), ["Asia/Tokyo"]);
    });

    test.it("every zone in the tables is a real zone", () => {
        const all = [];
        for (const v of Object.values(Search.ZONE_REGIONS))
            all.push(...[].concat(v));
        for (const v of Object.values(Search.ZONE_CHOICES))
            all.push(...v.map(c => c[0]));
        for (const id of all)
            assert.ok(realZone(id), id);
    });

    test.it("orders ambiguous abbreviations by where the user is", () => {
        assert.deepStrictEqual(Search.namedZones("ist", "Europe/Copenhagen"), ["Asia/Kolkata", "Europe/Dublin", "Asia/Jerusalem"]);
        assert.deepStrictEqual(Search.namedZones("ist", "Europe/Dublin")[0], "Europe/Dublin");
        assert.deepStrictEqual(Search.namedZones("ist", "Asia/Jerusalem")[0], "Asia/Jerusalem");
        assert.deepStrictEqual(Search.namedZones("cst", "Europe/Copenhagen")[0], "America/Chicago");
        assert.deepStrictEqual(Search.namedZones("cst", "Asia/Shanghai")[0], "Asia/Shanghai");
        assert.deepStrictEqual(Search.namedZones("cst", "America/Havana")[0], "America/Havana");
        assert.deepStrictEqual(Search.namedZones("cst", "America/Denver")[0], "America/Chicago");
        assert.deepStrictEqual(Search.namedZones("bst", "Asia/Dhaka")[0], "Asia/Dhaka");
        assert.deepStrictEqual(Search.namedZones("georgia", "America/New_York")[0], "America/New_York");
        assert.deepStrictEqual(Search.namedZones("georgia", "Europe/Berlin")[0], "Asia/Tbilisi");
    });

    test.it("names the place the way it was asked", () => {
        assert.strictEqual(Search.placeLabel("india", "Asia/Kolkata", cityOf), "India");
        assert.strictEqual(Search.placeLabel("new south wales", "Australia/Sydney", cityOf), "New South Wales");
        assert.strictEqual(Search.placeLabel("uk", "Europe/London", cityOf), "UK");
        assert.strictEqual(Search.placeLabel("washington dc", "America/New_York", cityOf), "Washington DC");
        assert.strictEqual(Search.placeLabel("usa", "America/Denver", cityOf), "Denver");
        assert.strictEqual(Search.placeLabel("ist", "Asia/Kolkata", cityOf), "Kolkata");
        assert.strictEqual(Search.placeLabel("cet", "Europe/Paris", cityOf), "CET");
        assert.strictEqual(Search.placeLabel("tokyo", "Asia/Tokyo", cityOf), "Tokyo");
    });
});

test.describe("port phrases", () => {
    test.it("reads the port and whether the ask was to stop it", () => {
        assert.deepStrictEqual(Search.portAsk("kill port 3000"), { port: 3000, kill: true });
        assert.deepStrictEqual(Search.portAsk("what is using port 8080"), { port: 8080, kill: false });
        assert.deepStrictEqual(Search.portAsk("what's on port 5173?"), { port: 5173, kill: false });
        assert.deepStrictEqual(Search.portAsk("whats using port 80"), { port: 80, kill: false });
        assert.deepStrictEqual(Search.portAsk("who is listening on port 22"), { port: 22, kill: false });
        assert.deepStrictEqual(Search.portAsk("which process is using port 9000"), { port: 9000, kill: false });
        assert.deepStrictEqual(Search.portAsk("is port 3000 in use"), { port: 3000, kill: false });
        assert.deepStrictEqual(Search.portAsk("port 3000"), { port: 3000, kill: false });
        assert.deepStrictEqual(Search.portAsk("lsof -i :3000"), { port: 3000, kill: false });
        assert.deepStrictEqual(Search.portAsk("free port 3000"), { port: 3000, kill: true });
        assert.deepStrictEqual(Search.portAsk("kill the process on port 4000"), { port: 4000, kill: true });
        assert.deepStrictEqual(Search.portAsk("force quit port :8000"), { port: 8000, kill: true });
        assert.deepStrictEqual(Search.portAsk("what process is using port 3000"), { port: 3000, kill: false });
        assert.deepStrictEqual(Search.portAsk("what app is using port 3000"), { port: 3000, kill: false });
        assert.deepStrictEqual(Search.portAsk("kill whatever is on port 3000"), { port: 3000, kill: true });
        assert.deepStrictEqual(Search.portAsk("kill anything on port 3000"), { port: 3000, kill: true });
        assert.deepStrictEqual(Search.portAsk("kill port:3000"), { port: 3000, kill: true });
        assert.strictEqual(Search.killAsk("kill whatever is on port 3000"), null);
    });

    test.it("refuses ports out of range and other asks", () => {
        for (const t of ["port 0", "port 70000", "port royal", "airport", "kill firefox", "port", "passport 3000"])
            assert.strictEqual(Search.portAsk(t), null, t);
    });

    test.it("keeps the process killer away from port asks", () => {
        assert.strictEqual(Search.killAsk("kill port 3000"), null);
        assert.strictEqual(Search.killAsk("force quit port 3000"), null);
        assert.strictEqual(Search.killAsk("kill portal"), "portal");
        assert.strictEqual(Search.killAsk("kill firefox"), "firefox");
    });

    test.it("reads ss output, one entry per process", () => {
        const out = [
            "tcp LISTEN 0      511    127.0.0.1:3000 0.0.0.0:* users:((\"node\",pid=4242,fd=21))",
            "tcp LISTEN 0      511    [::1]:3000 [::]:* users:((\"node\",pid=4242,fd=22))",
            "tcp LISTEN 0      511    0.0.0.0:3000 0.0.0.0:* users:((\"nginx\",pid=10,fd=6),(\"nginx\",pid=11,fd=6))",
            "udp UNCONN 0      0      192.168.1.2%enp6s0:3000 0.0.0.0:*",
            "garbage line"
        ].join("\n");
        assert.deepStrictEqual(Ports.readListeners(out), [
            { pid: 4242, name: "node", addresses: ["tcp 127.0.0.1:3000", "tcp [::1]:3000"] },
            { pid: 10, name: "nginx", addresses: ["tcp 0.0.0.0:3000"] },
            { pid: 11, name: "nginx", addresses: ["tcp 0.0.0.0:3000"] },
            { pid: 0, name: "", addresses: ["udp 192.168.1.2%enp6s0:3000"] }
        ]);
        assert.deepStrictEqual(Ports.readListeners(""), []);
    });

    test.it("reads ss output without the protocol column", () => {
        assert.deepStrictEqual(Ports.readListeners("LISTEN 0 128 *:22 *:* users:((\"sshd\",pid=7,fd=3))"), [{ pid: 7, name: "sshd", addresses: ["tcp *:22"] }]);
    });
});
