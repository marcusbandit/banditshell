const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const read = file => fs.readFileSync(path.join(ROOT, file), "utf8").replace(/^\.pragma .*$/m, "");
const Idle = new Function(`${read("services/idle.js")}\nreturn { plan, handlerOf, hypridleTimes, hypridleConfigPath };`)();
const Durations = new Function(`${read("modules/settings/durations.js")}\nreturn { minutesFromChoice, choiceFromMinutes, choiceFromSeconds };`)();

test("a step with 0 minutes is never planned", () => {
    assert.deepStrictEqual(Idle.plan({ lock: 0, screensOff: 0, sleep: 0 }, true), []);
    assert.deepStrictEqual(Idle.plan({ lock: 5, screensOff: 0, sleep: 0 }, true).map(s => s.name), ["lock"]);
});

test("steps come in the order they fire, with seconds for the idle monitor", () => {
    const steps = Idle.plan({ lock: 15, screensOff: 5, sleep: 30 }, true);
    assert.deepStrictEqual(steps.map(s => [s.name, s.seconds]), [["screensOff", 300], ["lock", 900], ["sleep", 1800]]);
});

test("sleep is only planned on battery", () => {
    const minutes = { lock: 5, screensOff: 10, sleep: 30 };
    assert.ok(Idle.plan(minutes, true).some(s => s.name === "sleep"));
    assert.ok(!Idle.plan(minutes, false).some(s => s.name === "sleep"));
});

test("junk minutes plan nothing instead of firing at once", () => {
    assert.deepStrictEqual(Idle.plan({ lock: "x", screensOff: -3, sleep: undefined }, true), []);
});

test("a running idle tool is named, and nothing else counts", () => {
    assert.strictEqual(Idle.handlerOf("3794 hypridle\n"), "hypridle");
    assert.strictEqual(Idle.handlerOf("812 swayidle\n"), "swayidle");
    assert.strictEqual(Idle.handlerOf(""), "");
    assert.strictEqual(Idle.handlerOf("  \n"), "");
    assert.strictEqual(Idle.handlerOf("44 something-else\n"), "");
});

test("idle choices map to minutes and back", () => {
    for (const [label, minutes] of [["1 min", 1], ["5 min", 5], ["15 min", 15], ["30 min", 30], ["1 h", 60], ["never", 0]]) {
        assert.strictEqual(Durations.minutesFromChoice(label), minutes, label);
        assert.strictEqual(Durations.choiceFromMinutes(minutes), label, label);
    }
});

test("minutes nobody offered still show as themselves, and nonsense reads as never", () => {
    assert.strictEqual(Durations.choiceFromMinutes(7), "7 min");
    assert.strictEqual(Durations.choiceFromMinutes(90), "90 min");
    assert.strictEqual(Durations.choiceFromMinutes(undefined), "never");
    assert.strictEqual(Durations.minutesFromChoice("soon"), 0);
});

test("hypridle's timeouts are read per job, and a job it has no listener for is never", () => {
    const conf = `# lock after ten minutes
$LOCK = 600
general {
    lock_cmd = pidof hyprlock || hyprlock
}
listener {
    timeout = 150
    on-timeout = brightnessctl -s set 10
}
listener {
    timeout = $LOCK
    on-timeout = loginctl lock-session # banditshell answers
}
listener {
    timeout = 330
    on-timeout = hyprctl dispatch dpms off
    on-resume = hyprctl dispatch dpms on
}`;
    assert.deepStrictEqual(Idle.hypridleTimes(conf), { lock: 600, screensOff: 330, sleep: 0 });
    assert.deepStrictEqual(Idle.hypridleTimes("listener {\n timeout = 1800\n on-timeout = systemctl suspend\n}\nlistener {\n timeout = 900\n on-timeout = systemctl suspend\n}"), { lock: 0, screensOff: 0, sleep: 900 });
    assert.deepStrictEqual(Idle.hypridleTimes(""), { lock: 0, screensOff: 0, sleep: 0 });
});

test("hypridle's times are unknown when its config is unread or pulls in another file", () => {
    assert.strictEqual(Idle.hypridleTimes(undefined), null);
    assert.deepStrictEqual(Idle.hypridleTimes("source = ~/.config/hypr/idle-times.conf\nlistener {\n timeout = 60\n on-timeout = loginctl lock-session\n}"), { lock: 60, screensOff: null, sleep: null });
});

test("hypridle's config comes from its -c flag, else the XDG config folder", () => {
    assert.strictEqual(Idle.hypridleConfigPath("812 /usr/bin/hypridle -c /etc/idle.conf\n", "/home/a/.config"), "/etc/idle.conf");
    assert.strictEqual(Idle.hypridleConfigPath("812 hypridle --config=/x.conf", "/home/a/.config"), "/x.conf");
    assert.strictEqual(Idle.hypridleConfigPath("812 hypridle\n", "/home/a/.config"), "/home/a/.config/hypr/hypridle.conf");
    assert.strictEqual(Idle.hypridleConfigPath("", "/c"), "/c/hypr/hypridle.conf");
    assert.strictEqual(Idle.hypridleConfigPath("812 hypridle -c idle.conf", "/c"), "");
});

test("another daemon's seconds read as the shell's own choices", () => {
    assert.deepStrictEqual([600, 3600, 0, 45, 150].map(Durations.choiceFromSeconds), ["10 min", "1 h", "never", "45 s", "3 min"]);
});
