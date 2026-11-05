const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/bluetooth-pairing.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Pairing = new Function(src + "\nreturn { parseEvent, describe, describeShown, answerFor, failureLabel, stateLabel };")();

test.describe("agent events", () => {
    test("a JSON line with an event name parses, anything else is ignored", () => {
        assert.deepStrictEqual(Pairing.parseEvent('{"event":"ready"}'), { event: "ready" });
        assert.strictEqual(Pairing.parseEvent("Traceback (most recent call last):"), null);
        assert.strictEqual(Pairing.parseEvent("[]"), null);
        assert.strictEqual(Pairing.parseEvent("{}"), null);
        assert.strictEqual(Pairing.parseEvent("null"), null);
    });
});

test.describe("what the menu asks", () => {
    test("a number check shows the code and names the device", () => {
        const ask = Pairing.describe({ id: 1, kind: "confirm", name: "Pixel 9", address: "AA:BB:CC:DD:EE:FF", code: "123456" });
        assert.strictEqual(ask.title, "Pair with Pixel 9?");
        assert.strictEqual(ask.code, "123456");
        assert.strictEqual(ask.field, "");
    });

    test("a keyboard that wants a typed code gets a field, and the device address stands in for a missing name", () => {
        const ask = Pairing.describe({ id: 2, kind: "passkey", name: "", address: "AA:BB:CC:DD:EE:FF" });
        assert.strictEqual(ask.field, "code");
        assert.match(ask.title, /AA:BB:CC:DD:EE:FF/);
    });

    test("a legacy PIN asks for one and says what to try", () => {
        const ask = Pairing.describe({ id: 3, kind: "pin", name: "Speaker" });
        assert.strictEqual(ask.field, "PIN");
        assert.match(ask.detail, /0000/);
    });

    test("an unknown kind asks nothing", () => {
        assert.strictEqual(Pairing.describe({ id: 4, kind: "other" }), null);
        assert.strictEqual(Pairing.describe(null), null);
    });

    test("a code the device wants typed on its own keyboard is shown with the next step", () => {
        const shown = Pairing.describeShown({ name: "K380", code: "004321", entered: 2 });
        assert.deepStrictEqual(shown, { title: "Type this on K380", detail: "then press Enter", code: "004321" });
        assert.strictEqual(Pairing.describeShown({ name: "K380", code: "004321", entered: 6 }).detail, "now press Enter");
        assert.strictEqual(Pairing.describeShown(null), null);
    });
});

test.describe("answers", () => {
    const passkey = { id: 7, kind: "passkey", name: "Keyboard" };

    test("a passkey must be one to six digits", () => {
        assert.deepStrictEqual(Pairing.answerFor(passkey, true, " 4321 "), { id: 7, accept: true, code: "4321" });
        assert.strictEqual(Pairing.answerFor(passkey, true, ""), null);
        assert.strictEqual(Pairing.answerFor(passkey, true, "12ab"), null);
        assert.strictEqual(Pairing.answerFor(passkey, true, "1234567"), null);
    });

    test("a refusal needs no code and sends none", () => {
        assert.deepStrictEqual(Pairing.answerFor(passkey, false, "4321"), { id: 7, accept: false, code: "" });
    });

    test("a PIN cannot be empty and a number check carries no code back", () => {
        assert.strictEqual(Pairing.answerFor({ id: 8, kind: "pin" }, true, "  "), null);
        assert.deepStrictEqual(Pairing.answerFor({ id: 9, kind: "confirm", code: "123456" }, true, "ignored"), { id: 9, accept: true, code: "" });
        assert.strictEqual(Pairing.answerFor(null, true, "1"), null);
    });
});

test.describe("device state words", () => {
    const idle = { blocked: false, pairing: false, connecting: false, disconnecting: false, connected: false, battery: -1, paired: true };

    test("a saved device that is not connected says so", () => {
        assert.strictEqual(Pairing.stateLabel(idle, ""), "not connected");
        assert.strictEqual(Pairing.stateLabel(Object.assign({}, idle, { paired: false }), ""), "not paired");
    });

    test("a failure shows on an idle row and gives way to a live state", () => {
        const failure = Pairing.failureLabel("connect");
        assert.strictEqual(failure, "could not connect");
        assert.strictEqual(Pairing.stateLabel(idle, failure), "could not connect");
        assert.strictEqual(Pairing.failureLabel("pair"), "pairing failed");
        assert.strictEqual(Pairing.stateLabel(Object.assign({}, idle, { connecting: true }), failure), "connecting");
        assert.strictEqual(Pairing.stateLabel(Object.assign({}, idle, { connected: true, battery: 0.8 }), failure), "connected · 80%");
    });

    test("blocked and pairing outrank everything else", () => {
        assert.strictEqual(Pairing.stateLabel(Object.assign({}, idle, { blocked: true, connected: true }), ""), "blocked");
        assert.strictEqual(Pairing.stateLabel(Object.assign({}, idle, { pairing: true }), "pairing failed"), "pairing");
        assert.strictEqual(Pairing.stateLabel(null, ""), "");
    });
});
