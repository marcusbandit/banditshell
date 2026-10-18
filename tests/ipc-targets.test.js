const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const SNAPSHOT = path.join(ROOT, "tests/fixtures/ipc-targets.json");
const SKIPPED = new Set([".git", ".scratch", "node_modules", "tests"]);

function qmlFiles(dir) {
    const found = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
        if (SKIPPED.has(entry.name))
            continue;
        const full = path.join(dir, entry.name);
        if (entry.isDirectory())
            found.push(...qmlFiles(full));
        else if (entry.name.endsWith(".qml"))
            found.push(full);
    }
    return found.sort();
}

function skipQuoted(text, i) {
    const quote = text[i];
    i++;
    while (i < text.length && text[i] !== quote) {
        if (text[i] === "\\")
            i++;
        i++;
    }
    return i + 1;
}

function skipTemplate(text, i) {
    i++;
    while (i < text.length && text[i] !== "`") {
        if (text[i] === "\\") {
            i += 2;
        } else if (text[i] === "$" && text[i + 1] === "{") {
            i = skipBraced(text, i + 1);
        } else {
            i++;
        }
    }
    return i + 1;
}

function skipBraced(text, i) {
    let depth = 0;
    while (i < text.length) {
        const c = text[i];
        if (c === "{") {
            depth++;
            i++;
        } else if (c === "}") {
            depth--;
            i++;
            if (depth === 0)
                return i;
        } else if (c === '"' || c === "'") {
            i = skipQuoted(text, i);
        } else if (c === "`") {
            i = skipTemplate(text, i);
        } else {
            i++;
        }
    }
    return i;
}

function tokens(text) {
    const out = [];
    let i = 0;
    while (i < text.length) {
        const c = text[i];
        if (/\s/.test(c)) {
            i++;
        } else if (c === "/" && text[i + 1] === "/") {
            while (i < text.length && text[i] !== "\n")
                i++;
        } else if (c === "/" && text[i + 1] === "*") {
            i = text.indexOf("*/", i + 2) + 2;
        } else if (c === '"' || c === "'") {
            const end = skipQuoted(text, i);
            out.push({ kind: "string", value: text.slice(i + 1, end - 1), start: i, end });
            i = end;
        } else if (c === "`") {
            const end = skipTemplate(text, i);
            out.push({ kind: "template", value: text.slice(i, end), start: i, end });
            i = end;
        } else if (/[A-Za-z_$]/.test(c)) {
            let end = i + 1;
            while (end < text.length && /[\w$]/.test(text[end]))
                end++;
            out.push({ kind: "word", value: text.slice(i, end), start: i, end });
            i = end;
        } else {
            out.push({ kind: "punct", value: c, start: i, end: i + 1 });
            i++;
        }
    }
    return out;
}

function objectsOf(text, file) {
    const toks = tokens(text);
    const objects = [];
    const stack = [];
    for (let n = 0; n < toks.length; n++) {
        const t = toks[n];
        const top = stack[stack.length - 1];
        if (t.kind === "word" && /^[A-Z]/.test(t.value) && toks[n + 1]?.value === "{" && toks[n + 1].kind === "punct" && toks[n - 1]?.value !== ".") {
            const object = { type: t.value, file, target: null, functions: [] };
            objects.push(object);
            stack.push(object);
            n++;
        } else if (t.kind === "punct" && t.value === "{") {
            stack.push(null);
        } else if (t.kind === "punct" && t.value === "}") {
            stack.pop();
        } else if (top && t.kind === "word" && t.value === "target" && toks[n + 1]?.value === ":" && toks[n + 2]?.kind === "string" && toks[n - 1]?.value !== ".") {
            top.target = toks[n + 2].value;
        } else if (top && t.kind === "word" && t.value === "function" && toks[n + 1]?.kind === "word" && toks[n + 2]?.value === "(") {
            let close = n + 3;
            while (toks[close].value !== ")")
                close++;
            let after = close + 1;
            let returns = "";
            if (toks[after].value === ":") {
                let end = after + 1;
                while (toks[end].value !== "{")
                    end++;
                returns = text.slice(toks[after + 1].start, toks[end - 1].end);
                after = end;
            }
            const params = text.slice(toks[n + 2].end, toks[close].start).replace(/\s+/g, " ").trim();
            top.functions.push(`${toks[n + 1].value}(${params})${returns ? `: ${returns}` : ""}`);
            n = after - 1;
        }
    }
    assert.strictEqual(stack.length, 0, `unbalanced braces in ${file}`);
    return objects;
}

function parseAll() {
    const files = qmlFiles(ROOT).map(file => ({ file, text: fs.readFileSync(file, "utf8") }));
    const rootTypeOf = {};
    for (const { file, text } of files) {
        const match = /^([A-Z][\w.]*)\s*\{/m.exec(text);
        if (match)
            rootTypeOf[path.basename(file, ".qml")] = { type: match[1], file };
    }
    const handlerTypes = new Set(["IpcHandler"]);
    for (let grew = true; grew;) {
        grew = false;
        for (const [name, { type }] of Object.entries(rootTypeOf)) {
            if (handlerTypes.has(type) && !handlerTypes.has(name)) {
                handlerTypes.add(name);
                grew = true;
            }
        }
    }
    const mention = new RegExp(`\\b(${[...handlerTypes].join("|")})\\s*\\{`);
    const objects = [];
    for (const { file, text } of files)
        if (mention.test(text))
            objects.push(...objectsOf(text, file));
    return { objects, handlerTypes, rootTypeOf, files };
}

function inheritedFunctions(object, parsed, seen = new Set()) {
    const own = parsed.objects.filter(o => o.file === parsed.rootTypeOf[object.type]?.file && o.type === parsed.rootTypeOf[object.type]?.type);
    const base = own.length ? own[0] : null;
    return base && !seen.has(base) ? [...base.functions, ...inheritedFunctions(base, parsed, seen.add(base))] : [];
}

function targets(parsed) {
    const found = {};
    for (const object of parsed.objects) {
        if (!parsed.handlerTypes.has(object.type))
            continue;
        const target = object.target;
        if (!target)
            continue;
        assert.ok(!(target in found), `target "${target}" is declared twice`);
        found[target] = [...object.functions, ...inheritedFunctions(object, parsed)].sort();
    }
    return Object.fromEntries(Object.keys(found).sort().map(key => [key, found[key]]));
}

test.describe("ipc targets", () => {
    const parsed = parseAll();
    const found = targets(parsed);

    test.it("keeps every target, function name and parameter list the CLI and users' scripts call", () => {
        if (process.env.UPDATE_IPC_SNAPSHOT) {
            fs.writeFileSync(SNAPSHOT, `${JSON.stringify(found, null, 2)}\n`);
            return;
        }
        assert.deepStrictEqual(found, JSON.parse(fs.readFileSync(SNAPSHOT, "utf8")));
    });

    test.it("has no empty target", () => {
        for (const [target, functions] of Object.entries(found))
            assert.ok(functions.length > 0, `${target} has no functions`);
    });

    test.it("instantiates every file that declares a target from modules/Ipc.qml", () => {
        const wiring = fs.readFileSync(path.join(ROOT, "modules/Ipc.qml"), "utf8");
        const declaring = new Set(parsed.objects.filter(o => o.target).map(o => path.basename(o.file, ".qml")));
        for (const name of declaring)
            assert.match(wiring, new RegExp(`^\\s*${name}\\s*\\{`, "m"), `${name} is not listed in modules/Ipc.qml`);
    });
});
