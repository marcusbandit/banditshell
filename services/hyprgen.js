const MOD_BITS = [
    { name: "SUPER", bit: 64 },
    { name: "CTRL", bit: 4 },
    { name: "ALT", bit: 8 },
    { name: "SHIFT", bit: 1 },
    { name: "CAPS", bit: 2 }
];

function parseChord(chord) {
    const mods = [];
    let key = "";
    for (const tok of String(chord ?? "").split(" + ")) {
        const mod = MOD_BITS.find(m => m.name === tok.toUpperCase());

        if (mod && !key) {
            if (!mods.includes(mod.name))
                mods.push(mod.name);
        } else if (!key)
            key = tok;
        else
            key += ` + ${tok}`;
    }
    let mask = 0;
    for (const name of mods)
        mask += MOD_BITS.find(m => m.name === name).bit;
    return { mods, key, mask };
}

function luaString(s) {
    return String(s ?? "")
        .replace(/\\/g, "\\\\")
        .replace(/"/g, "\\\"")
        .replace(/\n/g, "\\n")
        .replace(/\r/g, "\\r")
        .replace(/\t/g, "\\t");
}

function luaUnescape(s) {
    let out = "";
    for (let i = 0; i < s.length; i++) {
        if (s[i] !== "\\") {
            out += s[i];
            continue;
        }
        const c = s[++i];
        if (c === "n")
            out += "\n";
        else if (c === "r")
            out += "\r";
        else if (c === "t")
            out += "\t";
        else
            out += c ?? "";
    }
    return out;
}

const OPENERS = ["function", "do", "then", "repeat"];
const CLOSERS = ["end", "until"];

function isIdentStart(c) {
    return /[A-Za-z_]/.test(c);
}
function isIdent(c) {
    return /[A-Za-z0-9_]/.test(c);
}

function resolveLuaValue(raw, aliases) {
    const t = String(raw ?? "").trim();

    if (/^".*"$/.test(t) || /^'.*'$/.test(t))
        return {
            v: luaUnescape(t.slice(1, -1)),
            literal: true
        };
    if (/^-?(\d+\.?\d*|\.\d+)$/.test(t))
        return {
            v: +t,
            literal: true
        };
    if (aliases && aliases[t] !== undefined)
        return {
            v: aliases[t],
            literal: true
        };
    return {
        v: t,
        literal: false
    };
}

function scanLua(src) {
    const s = String(src ?? "");
    const binds = [];
    const monitors = [];
    const outputTables = [];
    const bands = [];
    const bandTables = [];
    const requires = [];
    const foreign = [];

    let i = 0;
    let line = 1;
    let blockDepth = 0;
    let parenDepth = 0;

    const aliases = {};
    const frames = [];
    let pendingKey = null;

    const lineOf = offset => s.slice(0, offset).split("\n").length;

    function longLevel(pos) {
        if (s[pos] !== "[")
            return -1;
        let j = pos + 1;
        while (s[j] === "=")
            j++;
        return s[j] === "[" ? j - pos - 1 : -1;
    }

    function skipLongBracket(pos, level) {
        const close = `]${"=".repeat(level)}]`;
        const end = s.indexOf(close, pos);
        return end === -1 ? s.length : end + close.length;
    }

    while (i < s.length) {
        const c = s[i];

        if (c === "\n") {
            line++;
            i++;
            continue;
        }
        if (c === " " || c === "\t" || c === "\r") {
            i++;
            continue;
        }

        if (c === "-" && s[i + 1] === "-") {
            const lvl = longLevel(i + 2);
            if (lvl >= 0) {
                i = skipLongBracket(i + 2, lvl);
                continue;
            }
            while (i < s.length && s[i] !== "\n")
                i++;
            continue;
        }

        if (c === "\"" || c === "'") {
            const quote = c;
            i++;
            while (i < s.length && s[i] !== quote) {
                if (s[i] === "\\")
                    i++;
                if (s[i] === "\n")
                    line++;
                i++;
            }
            i++;
            continue;
        }

        const lvl = longLevel(i);
        if (lvl >= 0) {
            const end = skipLongBracket(i + 1, lvl);
            line += s.slice(i, end).split("\n").length - 1;
            i = end;
            continue;
        }

        if (isIdentStart(c)) {
            let j = i;
            while (j < s.length && isIdent(s[j]))
                j++;
            const word = s.slice(i, j);

            if (OPENERS.includes(word)) {

                blockDepth++;
                i = j;
                continue;
            }
            if (CLOSERS.includes(word)) {
                blockDepth = Math.max(0, blockDepth - 1);
                i = j;
                continue;
            }
            if (word === "require" && blockDepth === 0) {
                i = readRequire(j);
                continue;
            }
            if (word === "hl") {
                i = readCall(j);
                continue;
            }
            if (word === "local" && parenDepth === 0) {
                i = readLocal(j);
                continue;
            }

            if (frames.length) {
                let k = j;
                while (s[k] === " " || s[k] === "\t")
                    k++;
                if (s[k] === "=" && s[k + 1] !== "=") {
                    pendingKey = word;
                    i = readFieldValue(k + 1);
                    continue;
                }
            }
            i = j;
            continue;
        }

        if (c === "(") {
            parenDepth++;
            i++;
            continue;
        }
        if (c === ")") {
            parenDepth = Math.max(0, parenDepth - 1);
            i++;
            continue;
        }

        if (c === "{") {
            frames.push({
                open: i,
                line,
                key: pendingKey,
                fields: [],
                entries: 0,
                bands: 0
            });
            pendingKey = null;
            i++;
            continue;
        }
        if (c === "}") {
            closeFrame(i);
            i++;
            continue;
        }

        i++;
    }

    function readRequire(pos) {
        let j = pos;
        while (s[j] === " " || s[j] === "\t")
            j++;
        if (s[j] !== "(")
            return pos;
        j++;
        while (s[j] === " " || s[j] === "\t")
            j++;
        if (s[j] !== "\"")
            return pos;
        const strStart = ++j;
        while (j < s.length && s[j] !== "\"")
            j++;
        const name = s.slice(strStart, j);
        if (s[j] === "\"")
            j++;
        while (s[j] === " " || s[j] === "\t")
            j++;
        if (s[j] === ")")
            j++;
        if (parenDepth === 0 && blockDepth === 0 && name)
            requires.push(name);
        return j;
    }

    function readCall(pos) {
        const callStart = i;
        const startLine = line;

        let j = pos;
        while (s[j] === " " || s[j] === "\t")
            j++;
        if (s[j] !== ".")
            return j;
        j++;
        let k = j;
        while (k < s.length && isIdent(s[k]))
            k++;
        const what = s.slice(j, k);

        j = k;
        while (s[j] === " " || s[j] === "\t")
            j++;
        if (s[j] !== "(")
            return k;

        if (what !== "bind") {
            foreign.push({
                line: startLine,
                text: `hl.${what}(...)`
            });
            return k;
        }

        let depth = 0;
        j++;
        depth++;
        while (j < s.length && depth > 0) {
            const ch = s[j];
            if (ch === "\"" || ch === "'") {
                const quote = ch;
                j++;
                while (j < s.length && s[j] !== quote) {
                    if (s[j] === "\\")
                        j++;
                    j++;
                }
                j++;
                continue;
            }
            const ll = longLevel(j);
            if (ll >= 0) {
                j = skipLongBracket(j + 1, ll);
                continue;
            }
            if (ch === "(" || ch === "{")
                depth++;
            else if (ch === ")" || ch === "}")
                depth--;
            j++;
        }

        const callEnd = j;
        const raw = s.slice(callStart, callEnd);

        collectBind(raw, callStart, callEnd, startLine);

        line += raw.split("\n").length - 1;
        return callEnd;
    }

    function readLocal(pos) {
        let j = pos;
        while (s[j] === " " || s[j] === "\t")
            j++;
        let k = j;
        while (k < s.length && isIdent(s[k]))
            k++;
        const name = s.slice(j, k);
        j = k;
        while (s[j] === " " || s[j] === "\t")
            j++;

        if (OPENERS.includes(name) || CLOSERS.includes(name))
            return pos;
        if (!name || s[j] !== "=")
            return j;
        j++;
        while (s[j] === " " || s[j] === "\t")
            j++;
        const q = s[j];
        if (q === "\"" || q === "'") {
            j++;
            let v = "";
            while (j < s.length && s[j] !== q) {
                if (s[j] === "\\") {
                    v += luaUnescape(s.slice(j, j + 2));
                    j += 2;
                    continue;
                }
                v += s[j++];
            }
            if (s[j] === q)
                j++;
            if (blockDepth === 0)
                aliases[name] = v;
            return j;
        }
        const num = /^-?(\d+\.?\d*|\.\d+)/.exec(s.slice(j, j + 32));
        if (num) {
            if (blockDepth === 0)
                aliases[name] = +num[0];
            return j + num[0].length;
        }

        pendingKey = name;
        return j;
    }

    function readFieldValue(pos) {
        let j = pos;
        while (s[j] === " " || s[j] === "\t")
            j++;
        if (s[j] === "{")
            return j;
        const start = j;
        let depth = 0;
        let end = -1;
        while (j < s.length) {
            const ch = s[j];
            if (ch === "\"" || ch === "'") {
                const quote = ch;
                j++;
                while (j < s.length && s[j] !== quote) {
                    if (s[j] === "\\")
                        j++;
                    if (s[j] === "\n")
                        line++;
                    j++;
                }
                j++;
                continue;
            }
            if (ch === "-" && s[j + 1] === "-") {
                while (j < s.length && s[j] !== "\n")
                    j++;
                continue;
            }
            if (ch === "{" || ch === "(")
                depth++;
            else if (ch === "}" || ch === ")") {
                if (depth === 0)
                    break;
                depth--;
            } else if (ch === "," && depth === 0) {
                j++;
                end = j - 1;
                break;
            }
            j++;
        }
        if (end < 0)
            end = j;
        const raw = s.slice(start, end).trim();
        if (frames.length && raw)
            frames[frames.length - 1].fields.push({
                key: pendingKey,
                raw
            });
        pendingKey = null;
        line += s.slice(start, end).split("\n").length - 1;
        return j;
    }

    function closeFrame(at) {
        const f = frames.pop();
        if (!f)
            return;
        const path = frames.filter(x => x.key).map(x => x.key);
        if (f.fields.some(x => x.key === "output")) {
            collectMonitor(s.slice(f.open, at + 1), f, at, path);
            if (frames.length)
                frames[frames.length - 1].entries++;
            return;
        }
        if (f.fields.some(x => x.key === "monitor") && f.fields.some(x => x.key === "workspaces")) {
            collectBand(s.slice(f.open, at + 1), f, at, path);
            if (frames.length)
                frames[frames.length - 1].bands++;
            return;
        }
        if (f.key === "outputs" && f.entries > 0)
            outputTables.push({
                startLine: f.line,
                endLine: lineOf(at),
                path: path.concat(f.key)
            });
        if (f.bands > 0)
            bandTables.push({
                startLine: f.line,
                endLine: lineOf(at),
                path: path.concat(f.key)
            });
    }

    function collectMonitor(raw, f, at, path) {
        const byKey = {};
        for (const x of f.fields)
            byKey[x.key] = x.raw;

        const out = resolveLuaValue(byKey.output, aliases);
        const entry = {
            output: out.v,
            dynamic: blockDepth > 0 || !out.literal,
            raws: f.fields,
            trailing: entryTrailing(at),

            aliases
        };
        for (const key of ["mode", "position", "scale", "transform", "vrr"]) {
            if (byKey[key] === undefined)
                continue;
            const r = resolveLuaValue(byKey[key], aliases);
            entry[key] = r.v;
            if (!r.literal)
                entry.dynamic = true;
        }
        entry.indent = entryIndent(f);
        entry.startLine = f.line;
        entry.endLine = lineOf(at);
        entry.raw = raw.trim();
        monitors.push(entry);
    }

    function collectBand(raw, f, at, path) {
        const byKey = {};
        for (const x of f.fields)
            byKey[x.key] = x.raw;

        const mon = resolveLuaValue(byKey.monitor, aliases);
        const spec = resolveLuaValue(byKey.workspaces, aliases);
        const parsed = spec.literal ? parseBandSpec(spec.v) : {
            ok: false
        };
        bands.push({
            monitor: mon.v,
            workspaces: spec.v,
            first: parsed.ok ? parsed.first : undefined,
            last: parsed.ok ? parsed.last : undefined,
            invalid: !parsed.ok,
            dynamic: blockDepth > 0 || !mon.literal || !spec.literal,
            path,
            raws: f.fields,
            trailing: entryTrailing(at),
            indent: entryIndent(f),
            startLine: f.line,
            endLine: lineOf(at),
            raw: raw.trim(),
            aliases
        });
    }

    function entryTrailing(at) {
        let k = at + 1;
        while (k < s.length && (s[k] === " " || s[k] === "\t"))
            k++;
        return s[k] === "," ? "," : "";
    }

    function entryIndent(f) {
        const before = s.slice(s.lastIndexOf("\n", f.open) + 1, f.open);
        return /^\s*$/.test(before) ? before : "";
    }

    function collectBind(raw, callStart, callEnd, startLine) {

        const open = raw.indexOf("(");
        const body = raw.slice(open + 1, raw.lastIndexOf(")"));

        let rest = body.trim();
        let chord = null;
        let chordLiteral = true;

        const q = rest[0];
        if (q === "\"" || q === "'") {
            const close = rest.indexOf(q, 1);

            let end = 1;
            while (end < rest.length) {
                if (rest[end] === "\\")
                    end++;
                else if (rest[end] === q)
                    break;
                end++;
            }
            if (rest[end] === q) {
                chord = luaUnescape(rest.slice(1, end));
                rest = rest.slice(end + 1).trim();
            }
        }

        if (chord === null) {

            chord = raw.replace(/\s+/g, " ").trim();
            chordLiteral = false;
            rest = "";
        } else {

            rest = rest.replace(/^,/, "").trim();
        }

        let opts = { locked: false, repeating: false, description: "" };
        let optsLiteral = true;
        const om = /,\s*\{(.*)\}\s*$/.exec(rest);
        if (om) {
            for (const part of splitTop(om[1])) {
                const pm = /^\s*(\w+)\s*=\s*(.+?)\s*$/.exec(part);
                if (!pm) {
                    optsLiteral = false;
                    continue;
                }
                if (pm[1] === "locked" || pm[1] === "repeating")
                    opts[pm[1]] = pm[2] === "true";
                else if (pm[1] === "description" && /^".*"$/.test(pm[2].trim()))
                    opts.description = luaUnescape(pm[2].trim().slice(1, -1));
                else
                    optsLiteral = false;
            }
            rest = rest.slice(0, om.index).trim();
        } else if (rest.endsWith("}")) {

        }

        const expr = rest;

        binds.push({
            chord,
            chordLiteral,
            expr,
            description: opts.description,
            locked: opts.locked,
            repeating: opts.repeating,

            dynamic: !chordLiteral || !optsLiteral || blockDepth > 0 || expr.includes(".."),
            startLine,
            endLine: lineOf(callEnd - 1),
            raw: raw.trim()
        });
    }

    function splitTop(str) {
        const parts = [];
        let cur = "";
        let quoted = false;
        for (let p = 0; p < str.length; p++) {
            const ch = str[p];
            if (ch === "\\") {
                cur += ch + (str[++p] ?? "");
                continue;
            }
            if (ch === "\"")
                quoted = !quoted;
            if (ch === "," && !quoted) {
                parts.push(cur);
                cur = "";
                continue;
            }
            cur += ch;
        }
        if (cur.trim())
            parts.push(cur);
        return parts;
    }

    return {
        binds,
        monitors,
        outputTables,
        bands,
        bandTables,
        requires,
        foreign
    };
}

function composeBind(chord, expr, opts) {
    if (!chord || !expr)
        return null;

    const parts = [];
    if (opts?.locked)
        parts.push("locked = true");
    if (opts?.repeating)
        parts.push("repeating = true");
    if (opts?.description)
        parts.push(`description = "${luaString(opts.description)}"`);

    const head = `hl.bind("${luaString(chord)}", ${expr}`;
    return parts.length ? `${head}, { ${parts.join(", ")} })` : `${head})`;
}

function parseBandSpec(spec) {
    const s = String(spec ?? "").trim();
    const out = [];
    for (const raw of s.split(",")) {
        const part = raw.trim();

        if (!part)
            continue;
        let m = /^(\d+)-(\d+)$/.exec(part);
        if (m) {
            const a = +m[1];
            const b = +m[2];
            if (b < a || b - a > 512)
                return {
                    ok: false,
                    ids: []
                };
            for (let i = a; i <= b; i++)
                if (!out.includes(i))
                    out.push(i);
            continue;
        }
        m = /^(\d+)$/.exec(part);
        if (m) {
            if (!out.includes(+m[1]))
                out.push(+m[1]);
            continue;
        }
        return {
            ok: false,
            ids: []
        };
    }
    if (!out.length || out.length > 1024)
        return {
            ok: false,
            ids: []
        };
    out.sort((a, b) => a - b);
    return {
        ok: true,
        ids: out,
        first: out[0],
        last: out[out.length - 1]
    };
}

function composeEntry(entry, changed) {
    const parts = [];
    const seen = {};

    for (const f of entry?.raws ?? []) {
        seen[f.key] = true;
        const c = changed?.[f.key];
        parts.push(`${f.key} = ${c === undefined || entrySame(f.raw, c, entry) ? f.raw : entryLiteral(f.key, c)}`);
    }
    for (const key in changed ?? {})
        if (!seen[key])
            parts.push(`${key} = ${entryLiteral(key, changed[key])}`);

    if (!parts.length)
        return null;
    return `{ ${parts.join(", ")} }`;
}

const QUOTED_KEYS = ["output", "mode", "position", "monitor", "workspaces"];

function entrySame(raw, value, entry) {
    const r = resolveLuaValue(raw, entry?.aliases);
    return r.literal && r.v === value;
}

function entryLiteral(key, value) {
    return QUOTED_KEYS.includes(key) ? `"${luaString(value)}"` : String(value);
}

function spliceLines(src, startLine, endLine, replacement) {
    const lines = String(src ?? "").split("\n");
    if (startLine < 1 || endLine < startLine || endLine > lines.length)
        return null;
    return lines.slice(0, startLine - 1)
        .concat(replacement ?? [])
        .concat(lines.slice(endLine))
        .join("\n");
}

const ACTION_WORDS = [
    [/^hl\.dsp\.window\.fullscreen\(\{ mode = "fullscreen" \}\)$/, "Fullscreen the focused window"],
    [/^hl\.dsp\.window\.fullscreen\(\{ mode = "maximize" \}\)$/, "Maximize the focused window"],
    [/^hl\.dsp\.window\.fullscreen\(\)$/, "Fullscreen the focused window"],
    [/^hl\.dsp\.window\.close\(\)$/, "Close the focused window"],
    [/^hl\.dsp\.window\.pseudo\(\)$/, "Pseudo-tile the focused window"],
    [/^hl\.dsp\.window\.pin\(\)$/, "Pin the window to every workspace"],
    [/^hl\.dsp\.window\.float\(\{ action = "toggle" \}\)$/, "Float or tile the focused window"],
    [/^hl\.dsp\.window\.float\(\)$/, "Float the focused window"],
    [/^hl\.dsp\.window\.drag\(\)$/, "Move the window with the mouse"],
    [/^hl\.dsp\.window\.resize\(\)$/, "Resize the window with the mouse"],
    [/^hl\.dsp\.window\.move\(\{ direction = "([a-z]+)" \}\)$/, "Move the window $1"],
    [/^hl\.dsp\.window\.swap\(\{ direction = "([a-z]+)" \}\)$/, "Swap the window $1 (position, column, and size)"],
    [/^hl\.dsp\.window\.move\(\{ workspace = "special:([^"]+)" \}\)$/, "Move the window to the special workspace '$1'"],
    [/^hl\.dsp\.window\.move\(\{ workspace = "([^"]+)" \}\)$/, "Move the window to workspace $1"],
    [/^hl\.dsp\.window\.move\(\{ workspace = ([^ }]+) \}\)$/, "Move the window to workspace $1"],
    [/^hl\.dsp\.focus\(\{ workspace = "special:([^"]+)" \}\)$/, "Open the special workspace '$1'"],
    [/^hl\.dsp\.focus\(\{ workspace = ([^ }]+) \}\)$/, "Go to workspace $1"],
    [/^hl\.dsp\.focus\(\{ window = .+\}\)$/, "Focus the named window"],
    [/^hl\.dsp\.workspace\.toggle_special\("([^"]+)"\)$/, "Toggle the special workspace '$1'"],
    [/^hl\.dsp\.layout\("focus l"\)$/, "Focus the window to the left"],
    [/^hl\.dsp\.layout\("focus r"\)$/, "Focus the window to the right"],
    [/^hl\.dsp\.layout\("focus u"\)$/, "Focus the window above"],
    [/^hl\.dsp\.layout\("focus d"\)$/, "Focus the window below"],
    [/^hl\.dsp\.layout\("promote"\)$/, "Promote the window to its own column"],
    [/^hl\.dsp\.layout\("swapcol l"\)$/, "Swap with the column to the left"],
    [/^hl\.dsp\.layout\("swapcol r"\)$/, "Swap with the column to the right"],
    [/^hl\.dsp\.layout\("fit active"\)$/, "Fit the focused window"],
    [/^hl\.dsp\.layout\("fit visible"\)$/, "Fit every visible window"],
    [/^hl\.dsp\.global\("([^"]+)"\)$/, "Quickshell: $1"],
    [/^hl\.dsp\.exit\(\)$/, "Exit Hyprland"],
    [/^hl\.dsp\.submap\("reset"\)$/, "Leave the submap"]
];

function describeExpr(expr) {
    const e = String(expr ?? "").trim();

    const exec = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"\)$/.exec(e);
    if (exec)
        return luaUnescape(exec[1]);

    for (const [re, say] of ACTION_WORDS)
        if (re.test(e))
            return e.replace(re, say);

    return e;
}
