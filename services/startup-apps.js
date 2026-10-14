const WRAPPER = "shell-up";
const PLUMBING = ["dbus-update-activation-environment", "systemctl"];
const OFF_MARKER = /^off:\s*(.*)$/;
const EXEC_LINE = /^(\s*)(--\s?)?hl\.exec_cmd\(\s*(["'])((?:\\.|(?!\3)[^\\])*)\3\s*\)\s*(?:--\s?(.*))?$/;

function luaUnescape(s) {
    let out = "";
    for (let i = 0; i < s.length; i++) {
        if (s[i] !== "\\") {
            out += s[i];
            continue;
        }
        const c = s[++i];
        out += c === "n" ? "\n" : c === "r" ? "\r" : c === "t" ? "\t" : c ?? "";
    }
    return out;
}

function luaEscape(s, quote) {
    return String(s).replace(/\\/g, "\\\\").split(quote).join(`\\${quote}`).replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/\t/g, "\\t");
}

function shellWords(text) {
    const words = [];
    let i = 0;
    while (i < text.length) {
        while (i < text.length && /\s/.test(text[i]))
            i++;
        if (i >= text.length)
            break;
        const start = i;
        let word = "";
        while (i < text.length && !/\s/.test(text[i])) {
            const c = text[i];
            if (c === "'") {
                const close = text.indexOf("'", i + 1);
                const stop = close < 0 ? text.length : close;
                word += text.slice(i + 1, stop);
                i = close < 0 ? text.length : close + 1;
            } else if (c === "\"") {
                i++;
                while (i < text.length && text[i] !== "\"") {
                    if (text[i] === "\\" && i + 1 < text.length)
                        i++;
                    word += text[i++];
                }
                i++;
            } else if (c === "\\" && i + 1 < text.length) {
                word += text[i + 1];
                i += 2;
            } else {
                word += c;
                i++;
            }
        }
        words.push({ text: word, start, end: Math.min(i, text.length) });
    }
    return words;
}

function quoteWord(word) {
    const w = String(word);
    return /^~?[A-Za-z0-9_\/.:@%+=,-]+$/.test(w) ? w : `'${w.replace(/'/g, "'\\''")}'`;
}

function baseName(path) {
    return String(path).split("/").pop();
}

function parseExecLines(text) {
    const out = [];
    const lines = String(text ?? "").split("\n");
    for (let i = 0; i < lines.length; i++) {
        const m = EXEC_LINE.exec(lines[i].replace(/\r$/, ""));
        if (!m)
            continue;
        out.push({
            line: i + 1,
            raw: lines[i],
            indent: m[1],
            off: !!m[2],
            quote: m[3],
            command: luaUnescape(m[4]),
            comment: m[5] ?? ""
        });
    }
    return out;
}

function wrapperOf(command) {
    const words = shellWords(command);
    if (!words.length || baseName(words[0].text) !== WRAPPER)
        return null;
    return { prefix: command.slice(0, words[0].end), args: words.slice(1).map(w => w.text) };
}

function offMarker(comment) {
    const m = OFF_MARKER.exec(String(comment ?? "").trim());
    if (!m)
        return { args: [], foreign: String(comment ?? "").trim() };
    const words = shellWords(m[1]).map(w => w.text);
    const bar = words.indexOf("|");
    return bar < 0 ? { args: words, foreign: "" } : { args: words.slice(0, bar), foreign: words.slice(bar + 1).join(" ") };
}

function hyprlandApps(files) {
    const out = [];
    const seen = new Set();
    const add = row => {
        if (seen.has(row.id))
            return;
        seen.add(row.id);
        out.push(row);
    };
    for (const file of files) {
        for (const line of parseExecLines(file.text)) {
            const first = shellWords(line.command)[0]?.text ?? "";
            if (!first || PLUMBING.includes(baseName(first)))
                continue;
            const wrapper = wrapperOf(line.command);
            const base = { file: file.name, startLine: line.line, endLine: line.line, line };
            if (!wrapper) {
                add(Object.assign(base, { id: `hyprland:${line.command}`, command: line.command, on: !line.off, wrapped: false }));
                continue;
            }
            if (line.off)
                continue;
            const marker = offMarker(line.comment);
            for (const arg of wrapper.args)
                add(Object.assign({}, base, { id: `hyprland:${arg}`, command: arg, on: true, wrapped: true, wrapper, marker }));
            for (const arg of marker.args)
                add(Object.assign({}, base, { id: `hyprland:${arg}`, command: arg, on: false, wrapped: true, wrapper, marker }));
        }
    }
    return out;
}

function wrapperLine(row, args, offArgs) {
    const line = row.line;
    const command = row.wrapper.prefix + args.map(a => ` ${quoteWord(a)}`).join("");
    const foreign = row.marker.foreign;
    const tail = offArgs.length ? ` -- off: ${offArgs.map(quoteWord).join(" ")}${foreign ? ` | ${foreign}` : ""}` : foreign ? ` -- ${foreign}` : "";
    return `${line.indent}hl.exec_cmd(${line.quote}${luaEscape(command, line.quote)}${line.quote})${tail}`;
}

function toggleReplacement(row, on) {
    const line = row.line;
    if (!row.wrapped) {
        const body = line.raw.slice(line.indent.length);
        return [on ? line.indent + body.replace(/^--\s?/, "") : `${line.indent}-- ${body}`];
    }
    const rest = row.wrapper.args.filter(a => a !== row.command);
    const away = row.marker.args.filter(a => a !== row.command);
    return [wrapperLine(row, on ? rest.concat([row.command]) : rest, on ? away : away.concat([row.command]))];
}

function parseUnitFiles(text) {
    const out = [];
    for (const line of String(text ?? "").split("\n")) {
        const [unit, state] = line.trim().split(/\s+/);
        if (!unit || !unit.endsWith(".service") || unit.includes("@") || !state)
            continue;
        out.push({ unit, state });
    }
    return out;
}

function candidateUnits(unitFiles) {
    return unitFiles.filter(u => u.state === "enabled" || u.state === "disabled").map(u => u.unit);
}

function parseUnitShow(text) {
    const out = [];
    for (const block of String(text ?? "").split(/\n\s*\n/)) {
        const fields = {};
        for (const line of block.split("\n")) {
            const eq = line.indexOf("=");
            if (eq > 0)
                fields[line.slice(0, eq)] = line.slice(eq + 1);
        }
        if (!fields.Id)
            continue;
        const path = /path=([^;]+?) ;/.exec(fields.ExecStart ?? "");
        out.push({ unit: fields.Id, description: fields.Description ?? "", fragment: fields.FragmentPath ?? "", program: path ? baseName(path[1]) : "" });
    }
    return out;
}

function systemdApps(unitFiles, shows, programs, userUnitDir) {
    const states = {};
    for (const u of unitFiles)
        states[u.unit] = u.state;
    const out = [];
    for (const show of shows) {
        const state = states[show.unit];
        const owned = show.fragment.startsWith(`${userUnitDir}/`);
        if ((state !== "enabled" && !(state === "disabled" && owned)) || !(show.program in programs))
            continue;
        out.push({ id: `systemd:${show.unit}`, unit: show.unit, program: show.program, description: show.description, on: state === "enabled" });
    }
    return out;
}

function autostartApps(files, desktops, shownIn) {
    const out = [];
    for (const file of files) {
        const e = file.entry;
        if (!e || e.type !== "Application" || !e.exec || !shownIn(e, desktops))
            continue;
        const name = baseName(file.path);
        out.push({ id: `autostart:${name}`, file: name, path: file.path, text: file.text, entry: e, on: !e.hidden && e.autostartEnabled });
    }
    return out;
}

function startSummary(rows) {
    if (!rows.length)
        return "nothing to start yet";
    const on = rows.filter(r => r.on).length;
    return on === rows.length ? `all ${on} start` : `${on} of ${rows.length} start`;
}
