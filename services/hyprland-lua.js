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
            path,
            startOffset: f.open,
            endOffset: at + 1,

            aliases
        };
        for (const key of ["mode", "position", "scale", "transform", "vrr", "mirror"]) {
            if (byKey[key] === undefined)
                continue;
            const r = resolveLuaValue(byKey[key], aliases);
            entry[key] = r.v;
            if (!r.literal)
                entry.dynamic = true;
        }
        if (byKey.disabled !== undefined) {
            const flag = /^(true|false)$/.exec(byKey.disabled.trim());
            entry.disabled = flag ? flag[1] === "true" : byKey.disabled.trim();
            if (!flag)
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
            startOffset: f.open,
            endOffset: at + 1,
            raws: f.fields,
            indent: entryIndent(f),
            startLine: f.line,
            endLine: lineOf(at),
            raw: raw.trim(),
            aliases
        });
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
        if (c === null)
            continue;
        parts.push(`${f.key} = ${c === undefined || entrySame(f.raw, c, entry) ? f.raw : entryLiteral(f.key, c)}`);
    }
    for (const key in changed ?? {})
        if (!seen[key] && changed[key] !== null)
            parts.push(`${key} = ${entryLiteral(key, changed[key])}`);

    if (!parts.length)
        return null;
    return `{ ${parts.join(", ")} }`;
}

function entryReplacement(src, entry, composed) {
    const text = String(src ?? "");
    const lineStart = text.lastIndexOf("\n", entry.startOffset - 1) + 1;
    const lineBreak = text.indexOf("\n", entry.endOffset);
    const lineEnd = lineBreak < 0 ? text.length : lineBreak;
    return [text.slice(lineStart, entry.startOffset) + composed + text.slice(entry.endOffset, lineEnd)];
}

function entriesForHost(entries, host) {
    const own = entries.filter(e => e.path?.[1] === host);
    return own.length ? own : entries.filter(e => e.path?.[1] === undefined);
}

function verifyReport(output, code, crashed, prefixes) {
    const useful = String(output ?? "").split("\n").map(l => (prefixes ?? []).reduce((line, prefix) => line.replace(prefix, ""), l.trim())).filter(l => l && !l.includes("DEBUG") && !l.startsWith("=") && l !== "config ok");
    if (useful.length)
        return useful[useful.length - 1];
    return crashed ? `Hyprland crashed while checking it (signal ${code})` : `Hyprland rejected it (exit ${code})`;
}

function baselineRefusal(report) {
    return `your Hyprland config fails Hyprland's own check as it is, so nothing was changed · ${report}`;
}

const QUOTED_KEYS = ["output", "mode", "position", "mirror", "monitor", "workspaces"];

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

function actionTable(text) {
    const rows = [];
    for (const line of String(text ?? "").split("\n")) {
        if (!line || line[0] === "#")
            continue;
        const [id, , , , description] = line.split("\t");
        if (id && description)
            rows.push({ segments: id.split("."), description });
    }
    return rows;
}

function actionDescription(id, rows) {
    const want = String(id).split(".");
    let best = null;
    for (const row of rows ?? []) {
        if (row.segments.length !== want.length)
            continue;
        const stars = row.segments.filter(s => s === "*").length;
        if (row.segments.every((s, i) => s === "*" || s === want[i]) && (!best || stars < best.stars))
            best = { stars, description: row.description };
    }
    return best ? best.description : "";
}

function describeExpr(expr, actions) {
    const e = String(expr ?? "").trim();

    const exec = /^hl\.dsp\.exec_cmd\("((?:[^"\\]|\\.)*)"\)$/.exec(e);
    if (exec)
        return luaUnescape(exec[1]);

    const named = /^bs\.([a-z0-9_]+(?:\.[a-z0-9_]+)*)$/.exec(e) || /^bs\.action\(\s*"([a-z0-9_]+(?:\.[a-z0-9_]+)*)"/.exec(e);
    if (named && actions) {
        const said = actionDescription(named[1], actions);
        if (said)
            return said;
    }

    for (const [re, say] of ACTION_WORDS)
        if (re.test(e))
            return e.replace(re, say);

    return e;
}

function optionSegments(path) {
    return String(path ?? "").split(/[:.]/).filter(Boolean).map(part => part.replace(/-/g, "_"));
}

function luaOptionValue(value) {
    if (typeof value === "boolean")
        return value ? "true" : "false";
    if (typeof value === "number")
        return Number.isFinite(value) ? String(Number.isInteger(value) ? value : +value.toFixed(4)) : null;
    if (typeof value === "string")
        return `"${luaString(value)}"`;
    return null;
}

function literalValue(raw) {
    const t = String(raw ?? "").trim();
    return stringLiteral(t) !== null || /^-?(\d+\.?\d*|\.\d+)$/.test(t) || t === "true" || t === "false";
}

function readTableFields(s, open) {
    const fields = [];
    let i = open + 1;

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

    function skipValue() {
        let codeEnd = i;
        while (i < s.length && s[i] !== "," && s[i] !== ";" && s[i] !== "}") {
            const c = s[i];
            if (/\s/.test(c)) {
                i++;
                continue;
            }
            if (c === "-" && s[i + 1] === "-") {
                i = pastComment(s, i);
                continue;
            }
            if (c === "\"" || c === "'")
                i = pastString(s, i);
            else if (longBracketLevel(s, i) >= 0)
                i = pastLongBracket(s, i + 1, longBracketLevel(s, i));
            else if (OPENING[c])
                i = pastBalanced(s, i);
            else
                i++;
            codeEnd = i;
        }
        return codeEnd;
    }

    for (;;) {
        skipBlank();
        if (i >= s.length)
            return { open, close: -1, fields };
        if (s[i] === "}")
            return { open, close: i, fields };
        if (s[i] === "," || s[i] === ";") {
            i++;
            continue;
        }
        const rest = s.slice(i, i + 256);
        const named = /^([A-Za-z_]\w*)\s*=(?!=)/.exec(rest);
        const quoted = /^\[\s*(["'])((?:[^"'\\]|\\.)*)\1\s*\]\s*=(?!=)/.exec(rest);
        const head = named ?? quoted;
        const keyStart = i;
        if (!head) {
            skipValue();
            continue;
        }
        const key = named ? named[1] : luaUnescape(quoted[2]);
        i += head[0].length;
        skipBlank();
        const field = { key, keyStart, valueStart: i };
        if (s[i] === "{") {
            field.table = readTableFields(s, i);
            field.valueEnd = field.table.close < 0 ? s.length : field.table.close + 1;
            i = field.valueEnd;
            skipValue();
        } else {
            field.valueEnd = skipValue();
            field.literal = literalValue(s.slice(field.valueStart, field.valueEnd));
        }
        let after = field.valueEnd;
        while (s[after] === " " || s[after] === "\t")
            after++;
        field.comma = s[after] === "," ? after : -1;
        fields.push(field);
    }
}

function scanOptions(src) {
    const s = String(src ?? "");
    const configs = [];
    const devices = [];
    let depth = 0;
    let i = 0;

    while (i < s.length) {
        const c = s[i];
        if (c === "\"" || c === "'") {
            i = pastString(s, i);
            continue;
        }
        if (c === "-" && s[i + 1] === "-") {
            i = pastComment(s, i);
            continue;
        }
        const level = longBracketLevel(s, i);
        if (level >= 0) {
            i = pastLongBracket(s, i + 1, level);
            continue;
        }
        if (!isIdentStart(c)) {
            i++;
            continue;
        }
        let j = i;
        while (j < s.length && isIdent(s[j]))
            j++;
        const word = s.slice(i, j);
        const call = word === "hl" && s[i - 1] !== "." ? /^\s*\.\s*(config|device)\s*\(/.exec(s.slice(j, j + 64)) : null;
        if (call) {
            const open = j + call[0].length - 1;
            let k = open + 1;
            while (/\s/.test(s[k] ?? ""))
                k++;
            if (s[k] === "{") {
                const table = readTableFields(s, k);
                if (table.close >= 0)
                    (call[1] === "config" ? configs : devices).push({ table, depth });
            }
            i = pastBalanced(s, open);
            continue;
        }
        if (OPENERS.includes(word))
            depth++;
        else if (CLOSERS.includes(word) || word === "elseif")
            depth = Math.max(0, depth - 1);
        i = j;
    }
    return { configs, devices };
}

function lineAt(s, offset) {
    return s.slice(0, offset).split("\n").length;
}

function lineDiff(before, after) {
    const a = String(before ?? "").split("\n");
    const b = String(after ?? "").split("\n");
    let head = 0;
    while (head < a.length && head < b.length && a[head] === b[head])
        head++;
    if (head === a.length && head === b.length)
        return null;
    let tail = 0;
    while (tail < a.length - head && tail < b.length - head && a[a.length - 1 - tail] === b[b.length - 1 - tail])
        tail++;
    if (head + tail === a.length) {
        if (head > 0)
            head--;
        else
            tail--;
    }
    return {
        startLine: head + 1,
        endLine: a.length - tail,
        replacement: b.slice(head, b.length - tail)
    };
}

function indentOfLine(s, offset) {
    return /^[ \t]*/.exec(s.slice(s.lastIndexOf("\n", offset - 1) + 1))[0];
}

function insertField(s, table, text) {
    const last = table.fields[table.fields.length - 1];
    const closeIndent = indentOfLine(s, table.close);
    const unit = closeIndent.includes("\t") ? "\t" : "    ";
    const spansLines = s.slice(last ? last.valueEnd : table.open, table.close).includes("\n");

    if (!last)
        return spansLines ? `${s.slice(0, table.open + 1)}\n${closeIndent}${unit}${text},\n${closeIndent}${s.slice(table.close)}` : `${s.slice(0, table.open + 1)} ${text} ${s.slice(table.close)}`;

    if (!spansLines) {
        if (last.comma >= 0)
            return `${s.slice(0, last.comma + 1)} ${text},${s.slice(last.comma + 1)}`;
        return `${s.slice(0, last.valueEnd)}, ${text}${s.slice(last.valueEnd)}`;
    }

    const newline = s.indexOf("\n", Math.max(last.comma, last.valueEnd));
    const lineEnd = newline < 0 || newline > table.close ? table.close : newline;
    const written = `${s.slice(0, lineEnd)}\n${indentOfLine(s, last.keyStart)}${text}${last.comma >= 0 ? "," : ""}${s.slice(lineEnd)}`;
    return last.comma >= 0 ? written : `${written.slice(0, last.valueEnd)},${written.slice(last.valueEnd)}`;
}

function nestedField(segments, value) {
    return segments.length === 1 ? `${segments[0]} = ${value}` : `${segments[0]} = { ${nestedField(segments.slice(1), value)} }`;
}

function optionCall(segments, value) {
    const pad = depth => "    ".repeat(depth);
    const lines = ["hl.config({"];
    segments.slice(0, -1).forEach((segment, depth) => lines.push(`${pad(depth + 1)}${segment} = {`));
    lines.push(`${pad(segments.length)}${segments[segments.length - 1]} = ${value},`);
    for (let depth = segments.length - 2; depth >= 0; depth--)
        lines.push(`${pad(depth + 1)}},`);
    lines.push("})");
    return lines;
}

function startsWith(path, prefix) {
    return prefix.length <= path.length && prefix.every((part, n) => part === path[n]);
}

function locateOption(files, request) {
    const segments = optionSegments(request.path);
    const device = request.device ?? "";
    const set = [];
    const blind = [];
    const homes = [];

    for (const file of files) {
        const s = String(file.text ?? "");
        const found = scanOptions(s);
        if (device) {
            for (const call of found.devices) {
                const named = call.table.fields.find(f => f.key === "name" && f.literal);
                if (!named || stringLiteral(s.slice(named.valueStart, named.valueEnd)) !== device)
                    continue;
                const field = call.table.fields.find(f => !f.table && optionSegments(f.key).join(":") === segments[segments.length - 1]);
                if (field)
                    set.push({ file, s, depth: call.depth, field });
                else
                    homes.push({ file, s, depth: call.depth, table: call.table, path: [] });
            }
            continue;
        }
        for (const call of found.configs) {
            const tables = [{ path: [], table: call.table }];
            for (let at = 0; at < tables.length; at++) {
                for (const field of tables[at].table.fields) {
                    const path = tables[at].path.concat(optionSegments(field.key));
                    if (field.table)
                        tables.push({ path, table: field.table });
                    else if (path.join(":") === segments.join(":"))
                        set.push({ file, s, depth: call.depth, field });
                    else if (!field.literal && startsWith(segments, path))
                        blind.push({ file, s, field });
                }
                if (tables[at].path.length > 0 && tables[at].path.length < segments.length && startsWith(segments, tables[at].path))
                    homes.push({ file, s, depth: call.depth, table: tables[at].table, path: tables[at].path });
            }
        }
    }

    const name = request.path;
    const here = w => `${w.file.name}, line ${lineAt(w.s, w.field.keyStart)}`;
    if (set.length > 1)
        return { refusal: `${name} is set in ${set.length} places (${set.map(here).join("; ")}); edit the source.` };
    if (set.length === 1) {
        const w = set[0];
        if (w.depth > 0)
            return { refusal: `${name} is set under a condition or inside a function (${here(w)}); edit the source.` };
        if (!w.field.literal)
            return { refusal: `${name} is generated by code (${here(w)}); edit the source.` };
        return { found: w };
    }
    if (blind.length)
        return { refusal: `${name} may be generated by code (${here(blind[0])}); edit the source.` };
    const home = homes.filter(h => h.depth === 0).sort((a, b) => b.path.length - a.path.length)[0];
    return { home };
}

function optionBlocked(files, path, device) {
    return locateOption(files, { path, device }).refusal ?? "";
}

function planOption(files, request) {
    const value = luaOptionValue(request.value);
    if (value === null)
        return { ok: false, reason: `${request.path} can't be written as ${String(request.value)}.` };
    const located = locateOption(files, request);
    if (located.refusal)
        return { ok: false, reason: located.refusal };

    const segments = optionSegments(request.path);
    const device = request.device ?? "";

    if (located.found) {
        const w = located.found;
        if (w.s.slice(w.field.valueStart, w.field.valueEnd).trim() === value)
            return { ok: true, unchanged: true };
        const next = w.s.slice(0, w.field.valueStart) + value + w.s.slice(w.field.valueEnd);
        return Object.assign({ ok: true, file: w.file.name }, lineDiff(w.s, next));
    }

    if (located.home) {
        const h = located.home;
        const text = device ? `${segments[segments.length - 1]} = ${value}` : nestedField(segments.slice(h.path.length), value);
        return Object.assign({ ok: true, file: h.file.name }, lineDiff(h.s, insertField(h.s, h.table, text)));
    }

    const target = files.find(f => f.name === request.appendTo) ?? files[0];
    if (!target)
        return { ok: false, reason: "there is no config file to write to." };
    const text = String(target.text ?? "");
    const call = device ? [`hl.device({ name = "${luaString(device)}", ${segments[segments.length - 1]} = ${value} })`] : optionCall(segments, value);
    const at = appendSplice(text, text.trim() ? [""].concat(call) : call);
    return {
        ok: true,
        file: target.name,
        startLine: at.startLine,
        endLine: at.endLine,
        replacement: at.replacement
    };
}

function optionValue(files, path, device) {
    const located = locateOption(files, { path, device });
    if (!located.found)
        return undefined;
    const raw = located.found.s.slice(located.found.field.valueStart, located.found.field.valueEnd).trim();
    const text = stringLiteral(raw);
    if (text !== null)
        return text;
    return raw === "true" ? true : raw === "false" ? false : +raw;
}

function chordHolder(binds, chord) {
    const want = parseChord(chord);
    const key = want.key.toLowerCase();
    const same = c => c.mask === want.mask && String(c.key ?? "").toLowerCase() === key;
    return (binds ?? []).find(b => !b.submap && (same(b) || (b.presses ?? []).some(same))) ?? null;
}

function relocateEntry(entries, old) {
    let best = null;
    for (const entry of entries ?? [])
        if (entry.file === old.file && entry.raw === old.raw && (!best || Math.abs(entry.startLine - old.startLine) < Math.abs(best.startLine - old.startLine)))
            best = entry;
    return best;
}

var LUA_COMMENTS = /--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*/g;

function luaLayouts(texts) {
    const out = [];
    const find = /hl\.layout\.register\(\s*["']([^"']+)["']/g;
    for (const text of texts || []) {
        const code = String(text).replace(LUA_COMMENTS, "");
        let m;
        while ((m = find.exec(code)) !== null)
            if (out.indexOf(`lua:${m[1]}`) < 0)
                out.push(`lua:${m[1]}`);
    }
    return out;
}
