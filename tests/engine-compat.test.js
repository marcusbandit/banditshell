const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const QML_ROOTS = ["shell.qml", "preview.qml", "config", "services", "components", "modules", "previews", "installer"];

const MISSING = [
    ["String.prototype.matchAll", /\.matchAll\s*\(/],
    ["String.prototype.replaceAll", /\.replaceAll\s*\(/],
    ["String.prototype.trimStart", /\.trimStart\s*\(/],
    ["String.prototype.trimEnd", /\.trimEnd\s*\(/],
    ["String.prototype.isWellFormed", /\.(isWellFormed|toWellFormed)\s*\(/],
    ["Array.prototype.findLast", /\.findLast(Index)?\s*\(/],
    ["Array.prototype.flat", /\.flat(Map)?\s*\(/],
    ["Array.prototype.toSorted", /\.(toSorted|toReversed|toSpliced)\s*\(/],
    ["Array.prototype.with", /\.with\s*\(/],
    ["Object.hasOwn", /\bObject\.hasOwn\b/],
    ["Object.fromEntries", /\bObject\.fromEntries\b/],
    ["Object.groupBy", /\b(Object|Map)\.groupBy\b/],
    ["Set.prototype.union and kin", /\.(union|intersection|difference|symmetricDifference|isSubsetOf|isSupersetOf|isDisjointFrom)\s*\(/],
    ["Promise.allSettled", /\bPromise\.(allSettled|any)\b/],
    ["Promise.prototype.finally", /\.finally\s*\(/],
    ["structuredClone", /\bstructuredClone\b/],
    ["globalThis", /\bglobalThis\b/],
    ["queueMicrotask", /\bqueueMicrotask\b/],
    ["BigInt", /\bBigInt\b|\b\d+n\b/],
    ["WeakRef", /\b(WeakRef|FinalizationRegistry)\b/],
    ["Intl", /\bIntl\./],
    ["TextEncoder", /\bText(En|De)coder\b/],
    ["Symbol.asyncIterator", /\bSymbol\.asyncIterator\b/],
    ["optional catch binding", /\bcatch\s*\{/],
    ["logical assignment", /\?\?=|\|\|=|&&=/],
    ["object spread or rest", /\{\s*\.\.\./],
    ["private class member", /(^|[^\w$])#[A-Za-z_$]/],
    ["static block", /\bstatic\s*\{/],
    ["async or await", /\basync\s+(function\b|\(|[A-Za-z_$][\w$]*\s*=>)|\bawait\b/]
];

const RESERVED = "abstract|boolean|byte|char|double|enum|final|float|goto|implements|int|interface|long|native|package|private|protected|public|short|synchronized|throws|transient|volatile";

MISSING.push(
    ["reserved word as a variable before Qt 6.12", new RegExp(`\\b(const|let|var)\\s+(${RESERVED})\\b`)],
    ["reserved word as a function before Qt 6.12", new RegExp(`\\bfunction\\s+(${RESERVED})\\s*\\(`)],
    ["reserved word as a parameter before Qt 6.12", new RegExp(`\\bfunction\\b[^(]*\\((?:[^)]*,)?\\s*(${RESERVED})\\s*[:,)=]|(?:^|[^\\w$.])(${RESERVED})\\s*=>|\\((?:[^()]*,)?\\s*(${RESERVED})\\s*(?:,[^()]*)?\\)\\s*=>|\\bcatch\\s*\\(\\s*(${RESERVED})\\s*\\)`)],
    ["reserved word as a property before Qt 6.12", new RegExp(`\\bproperty\\s+[\\w$<>.]+\\s+(${RESERVED})\\b`)]
);

const MISSING_IN_REGEX = [
    ["regex flag s", r => r.flags.includes("s")],
    ["regex flag d", r => r.flags.includes("d")],
    ["regex flag v", r => r.flags.includes("v")],
    ["regex named group", r => /\(\?<[A-Za-z_$]/.test(r.body)],
    ["regex lookbehind", r => /\(\?<[=!]/.test(r.body)],
    ["regex unicode property", r => /\\[pP]\{/.test(r.body)]
];

const REGEX_BEFORE = new Set("(,=:[!&|?{};+-*%<>~^".split(""));
const REGEX_AFTER_WORD = new Set(["return", "typeof", "case", "do", "else", "in", "of", "new", "delete", "void", "throw", "yield"]);

function blank(text) {
    return text.replace(/[^\n]/g, " ");
}

function scan(source) {
    let code = "";
    const regexes = [];
    const braces = [];
    let i = 0;

    function previousSignificant() {
        const trimmed = code.replace(/\s+$/, "");
        const word = /([A-Za-z_$][\w$]*)$/.exec(trimmed);
        return { char: trimmed.slice(-1), word: word ? word[1] : "" };
    }

    function templateText() {
        while (i < source.length) {
            const ch = source[i];
            if (ch === "\\") {
                code += blank(source.slice(i, i + 2));
                i += 2;
            } else if (ch === "`") {
                code += "`";
                i++;
                return;
            } else if (ch === "$" && source[i + 1] === "{") {
                code += "${";
                i += 2;
                braces.push("template");
                return;
            } else {
                code += blank(ch);
                i++;
            }
        }
    }

    function regexLiteral() {
        let j = i + 1;
        let inClass = false;
        while (j < source.length && source[j] !== "\n") {
            if (source[j] === "\\") {
                j += 2;
                continue;
            }
            if (source[j] === "[")
                inClass = true;
            else if (source[j] === "]")
                inClass = false;
            else if (source[j] === "/" && !inClass)
                break;
            j++;
        }
        let k = j + 1;
        while (k < source.length && /[a-z]/.test(source[k]))
            k++;
        const body = source.slice(i + 1, j);
        regexes.push({ body, flags: source.slice(j + 1, k), line: source.slice(0, i).split("\n").length });
        code += "/" + blank(body) + source.slice(j, k);
        i = k;
    }

    while (i < source.length) {
        const ch = source[i];
        const next = source[i + 1];
        if (ch === "/" && (next === "/" || next === "*")) {
            const end = next === "/" ? source.indexOf("\n", i) : source.indexOf("*/", i + 2);
            const stop = end < 0 ? source.length : next === "/" ? end : end + 2;
            code += blank(source.slice(i, stop));
            i = stop;
        } else if (ch === "\"" || ch === "'") {
            let j = i + 1;
            while (j < source.length && source[j] !== ch && source[j] !== "\n")
                j += source[j] === "\\" ? 2 : 1;
            const closed = source[j] === ch;
            code += ch + blank(source.slice(i + 1, j)) + (closed ? ch : "");
            i = closed ? j + 1 : j;
        } else if (ch === "`") {
            code += "`";
            i++;
            templateText();
        } else if (ch === "{") {
            braces.push("block");
            code += ch;
            i++;
        } else if (ch === "}") {
            code += ch;
            i++;
            if (braces.pop() === "template")
                templateText();
        } else if (ch === "/") {
            const prev = previousSignificant();
            if (prev.char === "" || REGEX_BEFORE.has(prev.char) || REGEX_AFTER_WORD.has(prev.word)) {
                regexLiteral();
            } else {
                code += ch;
                i++;
            }
        } else {
            code += ch;
            i++;
        }
    }
    return { code, regexes };
}

function walk(entry) {
    const full = path.join(ROOT, entry);
    if (!fs.existsSync(full))
        return [];
    if (fs.statSync(full).isFile())
        return [entry];
    return fs.readdirSync(full).flatMap(name => walk(path.join(entry, name)));
}

function engineFiles() {
    const qml = QML_ROOTS.flatMap(walk).filter(f => f.endsWith(".qml"));
    const js = new Set();
    const queue = [...qml];
    while (queue.length) {
        const file = queue.shift();
        const text = fs.readFileSync(path.join(ROOT, file), "utf8");
        for (const m of text.matchAll(/^\s*\.?import\s+"([^"]+\.js)"/gm)) {
            const target = path.normalize(path.join(path.dirname(file), m[1]));
            if (!js.has(target) && fs.existsSync(path.join(ROOT, target))) {
                js.add(target);
                queue.push(target);
            }
        }
    }
    return [...qml, ...js].sort();
}

function hitsIn(file) {
    const source = fs.readFileSync(path.join(ROOT, file), "utf8");
    const { code, regexes } = scan(source);
    const hits = [];
    code.split("\n").forEach((text, index) => {
        for (const [name, pattern] of MISSING)
            if (pattern.test(text))
                hits.push(`${file}:${index + 1}: ${name}`);
    });
    for (const regex of regexes)
        for (const [name, check] of MISSING_IN_REGEX)
            if (check(regex))
                hits.push(`${file}:${regex.line}: ${name}`);
    return hits;
}

test("the scanner sees code, not strings, comments or regex bodies", () => {
    const sample = [
        "const a = \"x.matchAll(y)\"; // s.replaceAll(t)",
        "/* catch { */ const b = /catch {/g;",
        "const c = `${s.matchAll(/x/s)} and .flat()`;",
        "const d = e / f / g;",
        "const h = 'unterminated",
        "const i = j.flatMap(k);"
    ].join("\n");
    const { code, regexes } = scan(sample);
    assert.strictEqual(code.length, sample.length);
    assert.ok(!/replaceAll|flat\(|catch/.test(code), code);
    assert.ok(/s\.matchAll\(/.test(code), code);
    assert.deepStrictEqual(regexes.map(r => [r.body, r.flags, r.line]), [["catch {", "g", 2], ["x", "s", 3]]);
    assert.strictEqual(code.split("\n")[5], "const i = j.flatMap(k);");
});

test("reserved words are caught as names but not as types, members or keys", () => {
    const flagged = text => MISSING.some(([name, pattern]) => name.startsWith("reserved") && pattern.test(text));
    for (const bad of ["const final = 1;", "var short = x;", "function float(): string {", "function f(a, char) {", "function f(byte: int) {", "long => long + 1", "(a, long) => a", "catch (char) {", "property bool long: false"])
        assert.ok(flagged(bad), bad);
    for (const good of ["function f(a: int, b: double): int {", "o.long + o.float", "({ long: 1, char: 2 })", "property int count: 0", "const longBreak = 1;", "function undock(): string {"])
        assert.ok(!flagged(good), good);
});

test("the engine's file list follows the JavaScript that QML imports", () => {
    const files = engineFiles();
    assert.ok(files.includes("services/hyprland-lua.js"));
    assert.ok(files.includes("components/vt.js"));
    assert.ok(files.includes("installer/theme.js"));
    assert.ok(!files.includes("services/cli-migration.js"));
});

test("no file Quickshell's engine loads uses JavaScript that engine lacks", () => {
    const hits = engineFiles().flatMap(hitsIn);
    assert.deepStrictEqual(hits, [], `\n${hits.join("\n")}`);
});
