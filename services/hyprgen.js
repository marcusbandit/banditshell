const MOD_BITS = [
    { name: "SUPER", bit: 64, aliases: ["WIN", "LOGO", "META", "MOD4"] },
    { name: "CTRL", bit: 4, aliases: ["CONTROL"] },
    { name: "ALT", bit: 8, aliases: ["MOD1"] },
    { name: "SHIFT", bit: 1, aliases: [] },
    { name: "CAPS", bit: 2, aliases: [] },
    { name: "MOD2", bit: 16, aliases: [] },
    { name: "MOD3", bit: 32, aliases: [] },
    { name: "MOD5", bit: 128, aliases: [] }
];

function parseChord(chord) {
    const mods = [];
    let key = "";
    for (const tok of String(chord ?? "").split(" + ")) {
        const said = tok.toUpperCase();
        const mod = MOD_BITS.find(m => m.name === said || m.aliases.includes(said));

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

const OPENING = { "(": ")", "{": "}", "[": "]" };

function longBracketLevel(s, pos) {
    if (s[pos] !== "[")
        return -1;
    let j = pos + 1;
    while (s[j] === "=")
        j++;
    return s[j] === "[" ? j - pos - 1 : -1;
}

function pastLongBracket(s, pos, level) {
    const close = `]${"=".repeat(level)}]`;
    const end = s.indexOf(close, pos);
    return end === -1 ? s.length : end + close.length;
}

function pastString(s, pos) {
    const quote = s[pos];
    let j = pos + 1;
    while (j < s.length && s[j] !== quote) {
        if (s[j] === "\\")
            j++;
        j++;
    }
    return Math.min(j + 1, s.length);
}

function pastComment(s, pos) {
    const level = longBracketLevel(s, pos + 2);
    if (level >= 0)
        return pastLongBracket(s, pos + 2, level);
    const end = s.indexOf("\n", pos);
    return end === -1 ? s.length : end;
}

function pastBalanced(s, pos) {
    const closers = [OPENING[s[pos]]];
    let j = pos + 1;
    while (j < s.length && closers.length) {
        const c = s[j];
        if (c === "\"" || c === "'") {
            j = pastString(s, j);
            continue;
        }
        if (c === "-" && s[j + 1] === "-") {
            j = pastComment(s, j);
            continue;
        }
        const level = longBracketLevel(s, j);
        if (level >= 0) {
            j = pastLongBracket(s, j + 1, level);
            continue;
        }
        if (OPENING[c])
            closers.push(OPENING[c]);
        else if (c === closers[closers.length - 1])
            closers.pop();
        j++;
    }
    return j;
}

function splitTopLevel(text, separator) {
    const s = String(text ?? "");
    const parts = [];
    let start = 0;
    let j = 0;
    while (j < s.length) {
        const c = s[j];
        if (c === "\"" || c === "'") {
            j = pastString(s, j);
            continue;
        }
        if (c === "-" && s[j + 1] === "-") {
            j = pastComment(s, j);
            continue;
        }
        const level = longBracketLevel(s, j);
        if (level >= 0) {
            j = pastLongBracket(s, j + 1, level);
            continue;
        }
        if (OPENING[c]) {
            j = pastBalanced(s, j);
            continue;
        }
        if (s.startsWith(separator, j) && (separator !== ".." || s[j + 2] !== ".")) {
            parts.push(s.slice(start, j).trim());
            j += separator.length;
            start = j;
            continue;
        }
        j++;
    }
    const last = s.slice(start).trim();
    if (last || parts.length)
        parts.push(last);
    return parts;
}

function stringLiteral(text) {
    const t = String(text ?? "").trim();
    if (t[0] === "\"" || t[0] === "'")
        return pastString(t, 0) === t.length && t[t.length - 1] === t[0] ? luaUnescape(t.slice(1, -1)) : null;
    const level = longBracketLevel(t, 0);
    if (level >= 0 && pastLongBracket(t, 1, level) === t.length) {
        const body = t.slice(level + 2, t.length - level - 2);
        return body[0] === "\n" ? body.slice(1) : body;
    }
    return null;
}

function parseLuaTable(text, aliases) {
    const s = String(text ?? "");
    let i = 0;

    function skipBlank() {
        for (;;) {
            while (i < s.length && /\s/.test(s[i]))
                i++;
            if (s[i] === "-" && s[i + 1] === "-") {
                i = pastComment(s, i);
                continue;
            }
            return;
        }
    }

    function opaque() {
        while (i < s.length && s[i] !== "," && s[i] !== ";" && s[i] !== "}") {
            const c = s[i];
            if (c === "\"" || c === "'")
                i = pastString(s, i);
            else if (OPENING[c])
                i = pastBalanced(s, i);
            else
                i++;
        }
        return undefined;
    }

    function value() {
        skipBlank();
        const start = i;
        const c = s[i];
        let v;
        if (c === "{")
            v = table();
        else if (c === "\"" || c === "'" || longBracketLevel(s, i) >= 0) {
            i = c === "[" ? pastLongBracket(s, i + 1, longBracketLevel(s, i)) : pastString(s, i);
            v = stringLiteral(s.slice(start, i));
        } else {
            const number = /^-?(\d+\.?\d*|\.\d+)/.exec(s.slice(i, i + 32));
            const word = /^[A-Za-z_]\w*/.exec(s.slice(i, i + 256));
            if (number) {
                i += number[0].length;
                v = +number[0];
            } else if (word) {
                i += word[0].length;
                v = word[0] === "true" ? true : word[0] === "false" ? false : aliases?.[word[0]];
            } else
                return opaque();
        }
        skipBlank();
        return i < s.length && s[i] !== "," && s[i] !== ";" && s[i] !== "}" ? opaque() : v;
    }

    function table() {
        const out = {
            list: [],
            fields: {}
        };
        i++;
        for (;;) {
            skipBlank();
            if (i >= s.length)
                return out;
            if (s[i] === "}") {
                i++;
                return out;
            }
            if (s[i] === "," || s[i] === ";") {
                i++;
                continue;
            }
            const named = /^([A-Za-z_]\w*)\s*=(?!=)/.exec(s.slice(i, i + 256));
            if (named) {
                i += named[0].length;
                out.fields[named[1]] = value();
            } else if (s[i] === "[" && longBracketLevel(s, i) < 0) {
                i = pastBalanced(s, i);
                skipBlank();
                if (s[i] === "=")
                    i++;
                value();
            } else
                out.list.push(value());
        }
    }

    skipBlank();
    return s[i] === "{" ? table() : null;
}

function readSubmapHead(s, from) {
    const open = s.indexOf("(", from);
    if (open < 0 || s.slice(from, open).trim())
        return null;
    const args = splitTopLevel(s.slice(open + 1, pastBalanced(s, open) - 1), ",");
    const name = stringLiteral(args[0]);
    if (name === null)
        return null;
    const body = stringLiteral(args[1]) !== null ? args[2] : args[1];
    return /^function\b/.test(body ?? "") ? name : null;
}

function readLoopHead(s, from, aliases, tables) {
    let j = from;
    let head = null;
    while (j < s.length) {
        const c = s[j];
        if (c === "\"" || c === "'") {
            j = pastString(s, j);
            continue;
        }
        if (OPENING[c]) {
            j = pastBalanced(s, j);
            continue;
        }
        if (s.startsWith("do", j) && !/\w/.test(s[j - 1] ?? "") && !/\w/.test(s[j + 2] ?? "")) {
            head = s.slice(from, j);
            break;
        }
        if (c === "\n" && j - from > 2048)
            break;
        j++;
    }
    const m = /^\s*([A-Za-z_]\w*(?:\s*,\s*[A-Za-z_]\w*)*)\s+in\s+(i?pairs)\s*\(([\s\S]*)\)\s*$/.exec(head ?? "");
    if (!m)
        return null;
    const names = m[1].split(",").map(n => n.trim());
    const source = m[3].trim();
    const table = source[0] === "{" ? parseLuaTable(source, aliases) : tables[source] ?? null;
    if (!table)
        return null;
    let items = table.list.slice();
    if (m[2] === "pairs")
        for (const k in table.fields)
            items.push(table.fields[k]);
    return {
        variable: names[names.length - 1],
        items
    };
}

function indexValue(value, index) {
    if (!value || typeof value !== "object")
        return undefined;
    if (typeof index === "number")
        return value.list[index - 1];
    return value.fields[index];
}

function resolvePiece(piece, lookup) {
    const t = String(piece ?? "").trim();
    const text = stringLiteral(t);
    if (text !== null)
        return text;
    if (/^-?(\d+\.?\d*|\.\d+)$/.test(t))
        return t;
    const wrapped = /^tostring\s*\(([\s\S]*)\)$/.exec(t);
    if (wrapped)
        return resolvePiece(wrapped[1], lookup);
    const base = /^[A-Za-z_]\w*/.exec(t);
    if (!base)
        return null;
    let value = lookup(base[0]);
    let rest = t.slice(base[0].length).trim();
    while (rest && value !== undefined) {
        const field = /^\.\s*([A-Za-z_]\w*)/.exec(rest) ?? /^\[\s*"([^"]*)"\s*\]/.exec(rest) ?? /^\[\s*'([^']*)'\s*\]/.exec(rest);
        const slot = /^\[\s*(\d+)\s*\]/.exec(rest);
        if (field) {
            value = indexValue(value, field[1]);
            rest = rest.slice(field[0].length).trim();
        } else if (slot) {
            value = indexValue(value, +slot[1]);
            rest = rest.slice(slot[0].length).trim();
        } else
            return null;
    }
    if (rest)
        return null;
    return typeof value === "string" || typeof value === "number" ? String(value) : null;
}

const CHORD_LIMIT = 64;

function resolveChord(text, scope) {
    const loops = scope.loops;
    const pieces = splitTopLevel(text, "..");
    if (!pieces.length || pieces.some(p => !p))
        return [];
    const used = [];
    for (const piece of pieces) {
        const base = /^(?:tostring\s*\(\s*)?([A-Za-z_]\w*)/.exec(piece);
        if (!base)
            continue;
        for (let l = loops.length - 1; l >= 0; l--) {
            if (loops[l].variable !== base[1])
                continue;
            if (!used.includes(loops[l]))
                used.push(loops[l]);
            break;
        }
    }

    const out = [];
    const bound = {};
    const walk = depth => {
        if (out.length >= CHORD_LIMIT)
            return;
        if (depth === used.length) {
            const lookup = name => bound[name] !== undefined ? bound[name] : scope.aliases[name] !== undefined ? scope.aliases[name] : scope.tables[name];
            let chord = "";
            for (const piece of pieces) {
                const v = resolvePiece(piece, lookup);
                if (v === null)
                    return;
                chord += v;
            }
            if (!out.includes(chord))
                out.push(chord);
            return;
        }
        for (const item of used[depth].items) {
            bound[used[depth].variable] = item;
            walk(depth + 1);
        }
        delete bound[used[depth].variable];
    };
    walk(0);
    return out;
}

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
    const tables = {};
    const frames = [];
    const submapScopes = [];
    const loopScopes = [];
    let pendingKey = null;

    const lineOf = offset => s.slice(0, offset).split("\n").length;

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
            const lvl = longBracketLevel(s, i + 2);
            if (lvl >= 0) {
                i = pastLongBracket(s, i + 2, lvl);
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

        const lvl = longBracketLevel(s, i);
        if (lvl >= 0) {
            const end = pastLongBracket(s, i + 1, lvl);
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
            if (CLOSERS.includes(word) || word === "elseif") {
                blockDepth = Math.max(0, blockDepth - 1);
                while (submapScopes.length && submapScopes[submapScopes.length - 1].depth >= blockDepth)
                    submapScopes.pop();
                while (loopScopes.length && loopScopes[loopScopes.length - 1].depth >= blockDepth)
                    loopScopes.pop();
                i = j;
                continue;
            }
            if (word === "for") {
                const loop = readLoopHead(s, j, aliases, tables);
                if (loop)
                    loopScopes.push(Object.assign({
                        depth: blockDepth
                    }, loop));
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
            if (what === "define_submap") {
                const name = readSubmapHead(s, k);
                if (name !== null)
                    submapScopes.push({
                        name,
                        depth: blockDepth
                    });
            } else
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
            const ll = longBracketLevel(s, j);
            if (ll >= 0) {
                j = pastLongBracket(s, j + 1, ll);
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
        if (s[j] === "{" && blockDepth === 0) {
            const table = parseLuaTable(s.slice(j, pastBalanced(s, j)), aliases);
            if (table)
                tables[name] = table;
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
        const args = splitTopLevel(raw.slice(open + 1, raw.lastIndexOf(")")), ",");
        const first = args[0] ?? "";
        const literal = stringLiteral(first);
        const chordLiteral = literal !== null;
        const chord = chordLiteral ? literal : first.replace(/\s+/g, " ").trim();
        const expr = args[1] ?? "";

        const opts = {
            locked: false,
            repeating: false,
            description: ""
        };
        let optsLiteral = args.length <= 3;
        const table = /^\{([\s\S]*)\}$/.exec(args[2] ?? "");
        if (args[2] !== undefined && !table)
            optsLiteral = false;
        for (const part of table ? splitTopLevel(table[1], ",") : []) {
            if (!part)
                continue;
            const pm = /^(\w+)\s*=\s*([\s\S]+)$/.exec(part);
            const said = pm ? stringLiteral(pm[2]) : null;
            if (pm && (pm[1] === "locked" || pm[1] === "repeating"))
                opts[pm[1]] = pm[2].trim() === "true";
            else if (pm && (pm[1] === "description" || pm[1] === "desc") && said !== null)
                opts.description = said;
            else
                optsLiteral = false;
        }

        binds.push({
            chord,
            chordLiteral,
            chords: chordLiteral ? [chord] : resolveChord(first, {
                aliases,
                tables,
                loops: loopScopes
            }),
            expr,
            description: opts.description,
            locked: opts.locked,
            repeating: opts.repeating,
            submap: submapScopes.length ? submapScopes[submapScopes.length - 1].name : "",
            dynamic: !chordLiteral || !optsLiteral || blockDepth > 0 || expr.includes(".."),
            startLine,
            endLine: lineOf(callEnd - 1),
            raw: raw.trim()
        });
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

function configFromCommandLine(text, home) {
    const lines = String(text ?? "").split("\n");
    const cwd = lines[0].startsWith("cwd=") ? lines[0].slice(4) : "";
    let given = "";
    for (let a = 1; a < lines.length; a++) {
        if ((lines[a] === "-c" || lines[a] === "--config") && a + 1 < lines.length)
            given = lines[++a];
        else if (lines[a].startsWith("--config="))
            given = lines[a].slice(9);
    }
    if (!given)
        return "";
    if (given === "~" || given.startsWith("~/"))
        return `${home}${given.slice(1)}`;
    if (given.startsWith("/"))
        return given;
    return cwd ? `${cwd}/${given.replace(/^(\.\/)+/, "")}` : "";
}

function confSources(text, dir, home) {
    const out = [];
    for (const raw of String(text ?? "").split("\n")) {
        const m = /^\s*source\s*=\s*([^#]*?)\s*(#.*)?$/.exec(raw);
        if (!m || !m[1] || m[1].includes("*"))
            continue;
        const p = m[1].replace(/^\$HOME(?=\/|$)/, home).replace(/^~(?=\/|$)/, home);
        out.push(p.startsWith("/") ? p : `${dir}/${p.replace(/^(\.\/)+/, "")}`);
    }
    return out;
}

function appendSplice(src, addition) {
    const lines = String(src ?? "").split("\n");
    const last = lines[lines.length - 1];
    return {
        startLine: lines.length,
        endLine: lines.length,
        replacement: last === "" ? addition.concat([""]) : [last].concat(addition)
    };
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
