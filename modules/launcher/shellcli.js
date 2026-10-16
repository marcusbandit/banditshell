.pragma library

var ABOUT_COLUMN = 31;

function tokensOf(usage) {
    const out = [];
    const parts = String(usage).match(/\[[^\]]*\]|<[^>]*>|\S+/g) || [];
    for (const part of parts) {
        if (part[0] === "[") {
            const inner = part.slice(1, -1);
            const options = inner.split("|");
            out.push((options.length > 1 || /^--/.test(inner)) && options.every(o => /^[a-z0-9-]+$|^--[a-z-]+$/.test(o)) ? {
                kind: "choice",
                options: options,
                optional: true
            } : {
                kind: "slot",
                name: inner.replace(/[<>]/g, ""),
                optional: true
            });
        } else if (part[0] === "<") {
            out.push({
                kind: "slot",
                name: part.slice(1, -1),
                optional: false
            });
        } else {
            out.push({
                kind: "word",
                text: part
            });
        }
    }
    return out;
}

function parseHelp(text) {
    const usages = [];
    const values = {};
    let pending = [];
    let describing = false;
    let valuesFor = "";
    const lines = String(text || "").split("\n");
    for (let i = 1; i < lines.length; i++) {
        const raw = lines[i];
        if (raw[0] !== "#")
            break;
        const line = raw.replace(/^# ?/, "");
        const use = /^  banditshell(?: (.*))?$/.exec(line);
        if (use) {
            if (describing) {
                pending = [];
                describing = false;
            }
            valuesFor = "";
            const rest = line.length > ABOUT_COLUMN && /^\S/.test(line.slice(ABOUT_COLUMN)) && /\s\s$/.test(line.slice(0, ABOUT_COLUMN)) ? line.slice(ABOUT_COLUMN).trim() : "";
            const usage = (rest ? line.slice(0, ABOUT_COLUMN) : line).trim().replace(/^banditshell\s*/, "");
            const entry = {
                usage: usage,
                tokens: tokensOf(usage),
                about: rest
            };
            usages.push(entry);
            if (rest) {
                pending = [entry];
                describing = true;
            } else {
                pending.push(entry);
            }
            continue;
        }
        const kinds = /^  <([a-z-]+)>: (.*?)\s*$/.exec(line);
        if (kinds) {
            valuesFor = kinds[1];
            values[valuesFor] = kinds[2].split(/\s{2,}/)[0].split("|").filter(Boolean);
            continue;
        }
        if (valuesFor && /^ {4,}[a-z|]+/.test(line) && !/^ {31}/.test(line)) {
            values[valuesFor] = values[valuesFor].concat(line.trim().split(/\s{2,}/)[0].split("|").filter(Boolean));
            continue;
        }
        if (/^ {31}\S/.test(line) && pending.length) {
            for (const entry of pending) {
                entry.about = entry.about ? `${entry.about} ${line.trim()}` : line.trim();
                entry.shared = pending.length > 1;
            }
            describing = true;
            continue;
        }
        if (!line.trim() || /^\S/.test(line)) {
            pending = [];
            describing = false;
            valuesFor = "";
        }
    }
    return {
        usages: usages,
        values: values
    };
}

function walk(tokens, typed, values) {
    let t = 0;
    for (const word of typed) {
        let used = false;
        while (t < tokens.length && !used) {
            const token = tokens[t];
            if (token.kind === "word") {
                if (token.text !== word)
                    return null;
                t++;
                used = true;
                continue;
            }
            if (token.kind === "choice") {
                if (token.options.indexOf(word) >= 0) {
                    t++;
                    used = true;
                    continue;
                }
                if (token.optional) {
                    t++;
                    continue;
                }
                return null;
            }
            const known = values[token.name];
            if (known && known.indexOf(word) < 0) {
                if (token.optional) {
                    t++;
                    continue;
                }
                return null;
            }
            t++;
            used = true;
        }
        if (!used)
            return null;
    }
    return t;
}

function nextWords(help, line) {
    const text = String(line || "");
    const typed = text.trim() ? text.trim().split(/\s+/) : [];
    const partial = /\s$/.test(text) || !typed.length ? "" : typed.pop();
    const out = [];
    for (const entry of help.usages) {
        const at = walk(entry.tokens, typed, help.values);
        if (at === null)
            continue;
        for (let t = at; t < entry.tokens.length; t++) {
            const token = entry.tokens[t];
            const options = token.kind === "word" ? [token.text] : token.kind === "choice" ? token.options : help.values[token.name] || [];
            for (const option of options)
                if (option.indexOf(partial) === 0 && option !== partial && !out.some(o => o.word === option))
                    out.push({
                        word: option,
                        about: entry.shared ? "" : entry.about
                    });
            if (token.kind === "word" || !token.optional)
                break;
        }
    }
    return {
        typed: typed,
        partial: partial,
        words: out
    };
}

function usageFor(help, line) {
    const typed = String(line || "").trim().split(/\s+/).filter(Boolean);
    let best = null;
    for (const entry of help.usages) {
        const at = walk(entry.tokens, typed, help.values);
        if (at === null)
            continue;
        const needs = entry.tokens.slice(at).some(t => t.kind === "word" || !t.optional);
        if (!needs && (!best || entry.tokens.length < best.tokens.length))
            best = entry;
    }
    return best;
}

function ask(text) {
    const m = /^(?:banditshell|bandit shell|bandit)(?:\s+([\s\S]*))?$/i.exec(String(text || "").replace(/^\s+/, ""));
    return m ? m[1] || "" : null;
}

var DETACHED = /^(?:start|stop|restart|dev\s+(?:try|back|tidy|run))\b/;

function detached(line) {
    return DETACHED.test(String(line || "").trim());
}
