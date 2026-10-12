const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const child = require("node:child_process");

const ROOT = path.resolve(__dirname, "..");
const src = fs.readFileSync(path.join(ROOT, "services/quoting.js"), "utf8").replace(/^\.pragma .*$/m, "");
const Quoting = new Function(src + "\nreturn { forShell, posix, visible, hasControl };")();

const CONTROLS = [];
for (let code = 0x00; code <= 0x1f; code++)
    CONTROLS.push(code);
CONTROLS.push(0x7f);
for (let code = 0x80; code <= 0x9f; code++)
    CONTROLS.push(code);

const ATTACK = "\x15touch PWNED;echo '";

function typeable(text) {
    for (let i = 0; i < text.length; i++) {
        const code = text.charCodeAt(i);
        if (code < 0x20 || code === 0x7f || (code >= 0x80 && code < 0xa0))
            return false;
    }
    return true;
}

function installed(shell) {
    return child.spawnSync("sh", ["-c", `command -v ${shell}`]).status === 0;
}

function echoed(shell, quoted) {
    const run = child.spawnSync(shell, ["-f", "-c", `printf '%s' ${quoted}`], {encoding: "buffer"});
    assert.strictEqual(run.status, 0, run.stderr.toString());
    return run.stdout;
}

test.describe("quoting: what may be typed into a live shell", () => {
    test.it("keeps every control character out of what zsh and bash are sent", () => {
        for (const shell of ["zsh", "bash"]) {
            for (const code of CONTROLS) {
                const name = `a${String.fromCharCode(code)}b`;
                const quoted = Quoting.forShell(shell, name);
                if (code === 0) {
                    assert.strictEqual(quoted, null, `${shell} NUL`);
                    continue;
                }
                assert.ok(quoted, `${shell} 0x${code.toString(16)}`);
                assert.ok(typeable(quoted), `${shell} 0x${code.toString(16)} leaked: ${JSON.stringify(quoted)}`);
            }
        }
    });

    test.it("uses dollar quoting with hex escapes for a control character", () => {
        assert.strictEqual(Quoting.forShell("zsh", "a\x1bb"), "$'a\\x1bb'");
        assert.strictEqual(Quoting.forShell("bash", "a\u009bb"), "$'a\\xc2\\x9bb'");
        assert.strictEqual(Quoting.forShell("zsh", ATTACK), "$'\\x15touch PWNED;echo \\x27'");
    });

    test.it("escapes quote, backslash and bang inside dollar quotes", () => {
        assert.strictEqual(Quoting.forShell("bash", "\x01'\\!"), "$'\\x01\\x27\\x5c\\x21'");
    });

    test.it("keeps plain single quotes for a name with no control character", () => {
        assert.strictEqual(Quoting.forShell("zsh", "/home/me/it's here"), "'/home/me/it'\\''s here'");
        assert.strictEqual(Quoting.forShell("bash", "/tmp/a b"), "'/tmp/a b'");
    });

    test.it("refuses control characters where the shell has no dollar quoting", () => {
        for (const shell of ["sh", "dash", "fish", "nu", "", "tcsh"])
            for (const code of CONTROLS)
                assert.strictEqual(Quoting.forShell(shell, `x${String.fromCharCode(code)}`), null, `${shell} 0x${code.toString(16)}`);
    });

    test.it("quotes for fish with its own backslash rule", () => {
        assert.strictEqual(Quoting.forShell("fish", "it's a\\b"), "'it\\'s a\\\\b'");
    });

    test.it("quotes plainly for an unknown shell only when nothing needs escaping", () => {
        assert.strictEqual(Quoting.forShell("nu", "/home/me/a b"), "'/home/me/a b'");
        assert.strictEqual(Quoting.forShell("nu", "/home/me/it's"), null);
        assert.strictEqual(Quoting.forShell("elvish", "a\\b"), null);
        assert.strictEqual(Quoting.forShell("tcsh", "wow!"), null);
    });

    test.it("refuses a lone surrogate", () => {
        assert.strictEqual(Quoting.forShell("zsh", "a\ud800b"), null);
        assert.strictEqual(Quoting.forShell("zsh", "a\udc00b"), null);
        assert.strictEqual(Quoting.forShell("zsh", "a😀b"), "'a😀b'");
    });

    test.it("quotes for sh -c the posix way", () => {
        assert.strictEqual(Quoting.posix("it's"), "'it'\\''s'");
    });

    test.it("shows control characters as hex escapes", () => {
        assert.strictEqual(Quoting.visible(ATTACK), "\\x15touch PWNED;echo '");
        assert.strictEqual(Quoting.visible("a\u0085b"), "a\\xc2\\x85b");
        assert.ok(Quoting.hasControl(ATTACK));
        assert.ok(!Quoting.hasControl("plain"));
    });
});

test.describe("quoting: the shells decode it back to the same bytes", () => {
    const names = [ATTACK, "plain", "it's", "a\\b", "x!y", "tab\there", "new\nline", "é\u0085\u009b\x7f", "$HOME `id` \"q\"", "\x1b[201~\x03"];

    for (const shell of ["zsh", "bash"]) {
        test.it(shell, {skip: !installed(shell)}, () => {
            for (const name of names) {
                const quoted = Quoting.forShell(shell, name);
                assert.ok(quoted, JSON.stringify(name));
                assert.deepStrictEqual(echoed(shell, quoted), Buffer.from(name, "utf8"), JSON.stringify(name));
            }
            for (const code of CONTROLS.slice(1)) {
                const name = `[${String.fromCharCode(code)}]`;
                assert.deepStrictEqual(echoed(shell, Quoting.forShell(shell, name)), Buffer.from(name, "utf8"), `0x${code.toString(16)}`);
            }
        });
    }
});
