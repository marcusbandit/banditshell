const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/wifilist.js"), "utf8");
const WifiList = new Function(src + "\nreturn { band, collapse, arrange, settle, secretLine };")();

const STEPS = 4;

function network(name, signalStrength, extra) {
    return Object.assign({ name, signalStrength, connected: false, known: false }, extra);
}

function names(list) {
    return list.map(n => n.name);
}

test.describe("band", () => {
    test.it("matches the bars the menu draws", () => {
        const cases = [[0, 0], [0.004, 0], [0.01, 1], [0.25, 1], [0.26, 2], [0.5, 2], [0.51, 3], [0.75, 3], [0.76, 4], [1, 4]];
        for (const [strength, expected] of cases)
            assert.strictEqual(WifiList.band(strength, STEPS), expected, `strength ${strength}`);
    });

    test.it("treats a missing strength as no signal", () => {
        assert.strictEqual(WifiList.band(undefined, STEPS), 0);
    });
});

test.describe("collapse", () => {
    test.it("drops hidden networks", () => {
        assert.deepStrictEqual(names(WifiList.collapse([network("", 0.9), network("cafe", 0.4)])), ["cafe"]);
    });

    test.it("keeps the connected entry over a stronger one", () => {
        const on = network("mesh", 0.3, { connected: true });
        const loud = network("mesh", 0.9);
        assert.strictEqual(WifiList.collapse([loud, on])[0], on);
    });

    test.it("keeps the strongest entry otherwise", () => {
        const quiet = network("mesh", 0.3);
        const loud = network("mesh", 0.9);
        assert.strictEqual(WifiList.collapse([quiet, loud])[0], loud);
    });

    test.it("survives names that are object keys", () => {
        const list = WifiList.collapse([network("__proto__", 0.5), network("constructor", 0.5), network("toString", 0.5)]);
        assert.deepStrictEqual(names(list).sort(), ["__proto__", "constructor", "toString"]);
    });
});

test.describe("arrange", () => {
    test.it("puts the connected network first, then the known ones, then by band", () => {
        const list = [
            network("strong", 0.95),
            network("saved", 0.2, { known: true }),
            network("here", 0.1, { connected: true, known: true }),
            network("weak", 0.1)
        ];
        assert.deepStrictEqual(names(WifiList.arrange(list, STEPS)), ["here", "saved", "strong", "weak"]);
    });

    test.it("orders a band by name, not by the signal inside it", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        assert.deepStrictEqual(names(WifiList.arrange([b, a], STEPS)), ["alpha", "bravo"]);
        b.signalStrength = 0.52;
        a.signalStrength = 0.74;
        assert.deepStrictEqual(names(WifiList.arrange([b, a], STEPS)), ["alpha", "bravo"]);
    });

    test.it("moves a network when its band changes", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        b.signalStrength = 0.9;
        assert.deepStrictEqual(names(WifiList.arrange([a, b], STEPS)), ["bravo", "alpha"]);
    });

    test.it("does not depend on the order networks arrive in", () => {
        const list = [network("b", 0.5), network("a", 0.5), network("c", 0.9), network("A", 0.5)];
        const forward = names(WifiList.arrange(list, STEPS));
        const backward = names(WifiList.arrange(list.slice().reverse(), STEPS));
        assert.deepStrictEqual(forward, backward);
    });
});

test.describe("settle", () => {
    test.it("hands back the same array when the order and members are unchanged", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        const before = WifiList.arrange([a, b], STEPS);
        a.signalStrength = 0.6;
        const after = WifiList.settle(before, WifiList.arrange([a, b], STEPS));
        assert.strictEqual(after, before);
    });

    test.it("hands back the new array when a band reorders the list", () => {
        const a = network("alpha", 0.55);
        const b = network("bravo", 0.7);
        const before = WifiList.arrange([a, b], STEPS);
        b.signalStrength = 0.9;
        const next = WifiList.arrange([a, b], STEPS);
        assert.strictEqual(WifiList.settle(before, next), next);
    });

    test.it("hands back the new array when a network arrives or leaves", () => {
        const a = network("alpha", 0.55);
        const before = WifiList.arrange([a], STEPS);
        const grown = WifiList.arrange([a, network("bravo", 0.3)], STEPS);
        assert.strictEqual(WifiList.settle(before, grown), grown);
        const shrunk = WifiList.arrange([], STEPS);
        assert.strictEqual(WifiList.settle(grown, shrunk), shrunk);
    });

    test.it("hands back the new array when an entry is a different object under the same name", () => {
        const before = [network("alpha", 0.5)];
        const next = [network("alpha", 0.5)];
        assert.strictEqual(WifiList.settle(before, next), next);
    });

    test.it("accepts having nothing before", () => {
        const next = [network("alpha", 0.5)];
        assert.strictEqual(WifiList.settle(undefined, next), next);
    });
});

function isSpace(character) {
    return character === " " || character === "\t" || character === "\n" || character === "\v" || character === "\f" || character === "\r";
}

function trimEnd(text) {
    let end = text.length;
    while (end > 0 && isSpace(text[end - 1]))
        end--;
    return text.slice(0, end);
}

function nmcliUnescape(text) {
    let start = 0;
    while (start < text.length && isSpace(text[start]))
        start++;
    text = text.slice(start);
    let at = text.indexOf("\\");
    if (at < 0)
        return trimEnd(text);
    let out = text.slice(0, at);
    for (;;) {
        at++;
        let character = text[at];
        if (character === undefined)
            break;
        if (character >= "0" && character <= "9") {
            let value = character.charCodeAt(0) - 48;
            at++;
            if (text[at] >= "0" && text[at] <= "7") {
                value = value * 8 + text.charCodeAt(at) - 48;
                at++;
                if (text[at] >= "0" && text[at] <= "7") {
                    value = value * 8 + text.charCodeAt(at) - 48;
                    at++;
                }
            }
            character = String.fromCharCode(value & 0xff);
        } else {
            character = { b: "\b", f: "\f", n: "\n", r: "\r", t: "\t", v: "\v" }[character] ?? character;
            at++;
        }
        out += character;
        const next = text.indexOf("\\", at);
        if (next < 0)
            return out + trimEnd(text.slice(at));
        out += text.slice(at, next);
        at = next;
    }
    return out;
}

function nmcliPasswords(contents) {
    const found = {};
    for (const raw of contents.split(/\r\n|\n|\r/)) {
        let line = raw;
        while (line && isSpace(line[0]))
            line = line.slice(1);
        if (!line || line[0] === "#")
            continue;
        const cut = line.search(/[:=]/);
        assert.ok(cut > 0, `no separator in ${JSON.stringify(line)}`);
        found[line.slice(0, cut).trim()] = nmcliUnescape(line.slice(cut + 1));
    }
    return found;
}

test.describe("secretLine", () => {
    const secrets = [
        "hunter2",
        "",
        " leading space",
        "trailing space ",
        "  both  ",
        "tab\there",
        "new\nline",
        "carriage\rreturn",
        "back\\slash",
        "\\n is not a newline",
        "trailing backslash\\",
        "colon:and=equals",
        "#not a comment",
        "octal \\101 stays",
        "delete\x7fcharacter",
        "zero after space 0",
        "ünïcödé ✓ 🔑"
    ];

    test.it("is one line that nmcli reads back as the same secret", () => {
        for (const secret of secrets) {
            const line = WifiList.secretLine("802-1x.password", secret);
            assert.ok(line.endsWith("\n"), JSON.stringify(secret));
            assert.ok(!/[\r\n]/.test(line.slice(0, -1)), `line break inside for ${JSON.stringify(secret)}`);
            assert.deepStrictEqual(nmcliPasswords(line), { "802-1x.password": secret }, JSON.stringify(secret));
        }
    });

    test.it("leaves an ordinary password readable", () => {
        assert.strictEqual(WifiList.secretLine("802-1x.password", "correct-horse"), "802-1x.password:correct-horse\n");
    });
});
