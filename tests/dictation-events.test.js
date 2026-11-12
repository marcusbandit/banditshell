const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/dictation-events.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Events = new Function(src + "\nreturn { read, outcome, startKey, asking, languageCode, dictationSettings, OUTPUTS };")();
const [older, listening, cancelled, chrome, streamed] = fs.readFileSync(path.join(ROOT, "tests/fixtures/gvoice/events.jsonl"), "utf8").trim().split("\n");

test.describe("dictation events", () => {
    test.it("offers no cancel to a daemon that does not say it can", () => {
        const e = Events.read(older);
        assert.strictEqual(e.phase, "idle");
        assert.strictEqual(e.lang, "en-DK");
        assert.strictEqual(e.canCancel, false);
        assert.strictEqual(e.cancelled, false);
    });

    test.it("offers cancel while a newer daemon listens", () => {
        const e = Events.read(listening);
        assert.strictEqual(e.phase, "listening");
        assert.strictEqual(e.level, 0.4123);
        assert.strictEqual(e.canCancel, true);
        assert.strictEqual(e.cancelled, false);
    });

    test.it("hears a cancel only as the idle that ends it", () => {
        assert.strictEqual(Events.read(cancelled).cancelled, true);
        assert.strictEqual(Events.read('{"phase": "listening", "cancelled": true}').cancelled, false);
    });

    test.it("says Partly kept only when the daemon says some words were typed", () => {
        assert.strictEqual(Events.outcome(Events.read(cancelled).typed), "Dictation discarded");
        assert.strictEqual(Events.outcome(Events.read(streamed).typed), "Partly kept");
        assert.strictEqual(Events.outcome(Events.read('{"phase": "idle", "cancelled": true}').typed), "Dictation discarded");
    });

    test.it("withdraws cancel when the daemon says it cannot", () => {
        assert.strictEqual(Events.read(chrome).canCancel, false);
    });

    test.it("ignores lines that are not an event", () => {
        assert.strictEqual(Events.read("not json"), null);
        assert.strictEqual(Events.read("[1, 2]"), null);
        assert.strictEqual(Events.read("null"), null);
        assert.strictEqual(Events.read('{"level": "loud"}').level, null);
    });
});

test.describe("the key that starts dictation", () => {
    const bind = (chord, cmd) => ({ chord, cmd });

    test.it("reads the chord of the bind that runs voice", () => {
        assert.strictEqual(Events.startKey([bind("SUPER + T", "kitty"), bind("SUPER + R", "voice toggle")]), "Super + R");
    });

    test.it("finds voice when it is run through a path", () => {
        assert.strictEqual(Events.startKey([bind("SUPER + SHIFT + D", "/home/me/bin/voice up")]), "Super + Shift + D");
    });

    test.it("skips the binds that stop or cancel", () => {
        assert.strictEqual(Events.startKey([bind("SUPER + ESCAPE", "voice cancel"), bind("SUPER + Z", "voice retype"), bind("SUPER + R", "voice start")]), "Super + R");
    });

    test.it("says nothing when no bind runs voice", () => {
        assert.strictEqual(Events.startKey([bind("SUPER + T", "kitty"), { chord: "", cmd: "voice" }]), "");
        assert.strictEqual(Events.startKey(null), "");
    });

    test.it("turns what was dictated into a question for the assistant", () => {
        assert.strictEqual(Events.asking("why is the sky blue", "why is the sky blue"), "ask why is the sky blue");
    });

    test.it("leaves text alone that is already an ask or does not hold the dictation yet", () => {
        assert.strictEqual(Events.asking("ask why is the sky blue", "why is the sky blue"), null);
        assert.strictEqual(Events.asking("? why", "why"), null);
        assert.strictEqual(Events.asking("firefox", "why is the sky blue"), null);
        assert.strictEqual(Events.asking("anything", ""), null);
    });

    test.it("maps the daemon language tag back to the code the voice tool takes", () => {
        assert.strictEqual(Events.languageCode("da-DK"), "da");
        assert.strictEqual(Events.languageCode("en-DK"), "en-dk");
        assert.strictEqual(Events.languageCode("auto"), "auto");
        assert.strictEqual(Events.languageCode("ja"), "ja");
    });

    test.it("reads output and microphone from the voice settings, defaulting when wrong", () => {
        assert.deepStrictEqual(Events.dictationSettings('{"output":"copy","microphone":"alsa_input.usb"}'), { output: "copy", microphone: "alsa_input.usb" });
        assert.deepStrictEqual(Events.dictationSettings('{"output":"email","microphone":""}'), { output: "auto", microphone: "default" });
        assert.deepStrictEqual(Events.dictationSettings("not json"), { output: "auto", microphone: "default" });
    });
});
