const ENTRY_HEADER = "[Desktop Entry]";
const BUNDLE_MARK = "@@@";

function unescapeValue(value) {
    let out = "";
    for (let i = 0; i < value.length; i++) {
        if (value[i] !== "\\" || i === value.length - 1) {
            out += value[i];
            continue;
        }
        const c = value[++i];
        out += c === "n" ? "\n" : c === "t" ? "\t" : c === "r" ? "\r" : c === "s" ? " " : c;
    }
    return out;
}

function splitList(value) {
    const out = [];
    let current = "";
    for (let i = 0; i < value.length; i++) {
        if (value[i] === "\\" && value[i + 1] === ";") {
            current += ";";
            i++;
        } else if (value[i] === ";") {
            out.push(current);
            current = "";
        } else {
            current += value[i];
        }
    }
    out.push(current);
    return out.map(s => s.trim()).filter(Boolean);
}

function truthy(value) {
    return String(value ?? "").trim().toLowerCase() === "true";
}

function parseEntry(text) {
    const keys = {};
    let inside = false;
    let seen = false;
    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.replace(/\r$/, "").trim();
        if (line.startsWith("[")) {
            if (seen)
                break;
            inside = line === ENTRY_HEADER;
            seen = inside;
            continue;
        }
        if (!inside || !line || line.startsWith("#"))
            continue;
        const eq = line.indexOf("=");
        if (eq < 1)
            continue;
        const key = line.slice(0, eq).trim();
        if (key.includes("["))
            continue;
        if (!(key in keys))
            keys[key] = line.slice(eq + 1).trim();
    }
    if (!seen)
        return null;
    return {
        type: keys.Type ?? "Application",
        name: unescapeValue(keys.Name ?? ""),
        exec: keys.Exec ?? "",
        tryExec: keys.TryExec ?? "",
        icon: keys.Icon ?? "",
        terminal: truthy(keys.Terminal),
        noDisplay: truthy(keys.NoDisplay),
        hidden: truthy(keys.Hidden),
        onlyShowIn: splitList(keys.OnlyShowIn ?? ""),
        notShowIn: splitList(keys.NotShowIn ?? ""),
        mimeTypes: splitList(keys.MimeType ?? ""),
        categories: splitList(keys.Categories ?? ""),
        autostartEnabled: keys["X-GNOME-Autostart-enabled"] === undefined ? true : truthy(keys["X-GNOME-Autostart-enabled"])
    };
}

function parseBundle(text) {
    const files = [];
    let current = null;
    for (const line of String(text ?? "").split("\n")) {
        if (line.startsWith(BUNDLE_MARK)) {
            current = { path: line.slice(BUNDLE_MARK.length).trim(), lines: [] };
            files.push(current);
        } else if (current) {
            current.lines.push(line);
        }
    }
    return files.map(f => {
        const body = f.lines.join("\n");
        return { path: f.path, text: body, entry: parseEntry(body) };
    });
}

function idOf(path) {
    return String(path).split("/").pop();
}

function indexEntries(bundle) {
    const seen = new Set();
    const out = [];
    for (const file of bundle) {
        const id = idOf(file.path);
        if (!file.entry || seen.has(id))
            continue;
        seen.add(id);
        if (file.entry.hidden)
            continue;
        out.push(Object.assign({ id }, file.entry));
    }
    return out;
}

function stripFieldCodes(exec) {
    return String(exec ?? "")
        .replace(/%%/g, "\u0000")
        .replace(/\s*%[a-zA-Z]/g, "")
        .replace(/\u0000/g, "%")
        .trim();
}

const PREFIX_PROGRAMS = ["env", "setsid", "nohup", "exec"];
const GENERIC_PROGRAMS = ["env", "sh", "bash", "zsh", "dash", "python", "python3", "flatpak"];

function programOf(command) {
    const words = String(command ?? "").trim().match(/"[^"]*"|'[^']*'|\S+/g) ?? [];
    const plain = w => w.replace(/^["']|["']$/g, "");
    for (const raw of words) {
        const word = plain(raw);
        const base = word.split("/").pop();
        if (/^[A-Za-z_][A-Za-z0-9_]*=/.test(word) || PREFIX_PROGRAMS.includes(base))
            continue;
        if (base === "flatpak") {
            const run = words.findIndex(w => plain(w) === "run");
            const app = run < 0 ? undefined : words.slice(run + 1).map(plain).find(w => !w.startsWith("-"));
            return app ?? base;
        }
        return base;
    }
    return "";
}

function absolutePrograms(command) {
    const words = String(command ?? "").trim().match(/"[^"]*"|'[^']*'|\S+/g) ?? [];
    return words.slice(1).map(w => w.replace(/^["']|["']$/g, "")).filter(w => w.startsWith("/")).map(w => w.split("/").pop());
}

function indexPrograms(entries) {
    const out = {};
    const put = (key, entry) => {
        if (key && !GENERIC_PROGRAMS.includes(key) && !(key in out))
            out[key] = entry;
    };
    for (const entry of entries)
        put(programOf(entry.exec), entry);
    for (const entry of entries)
        for (const program of absolutePrograms(entry.exec))
            put(program, entry);
    for (const entry of entries)
        put(entry.id.replace(/\.desktop$/, ""), entry);
    return out;
}

function shownIn(entry, desktops) {
    const here = (desktops ?? []).map(d => d.toLowerCase());
    if (entry.onlyShowIn.length && !entry.onlyShowIn.some(d => here.includes(d.toLowerCase())))
        return false;
    return !entry.notShowIn.some(d => here.includes(d.toLowerCase()));
}

function setHidden(text, hidden) {
    const lines = String(text ?? "").split("\n");
    const start = lines.findIndex(l => l.trim() === ENTRY_HEADER);
    if (start < 0)
        return text;
    let end = lines.length;
    for (let i = start + 1; i < lines.length; i++)
        if (lines[i].trim().startsWith("[")) {
            end = i;
            break;
        }
    let wrote = false;
    for (let i = start + 1; i < end; i++) {
        if (/^\s*Hidden\s*=/.test(lines[i])) {
            lines[i] = `Hidden=${hidden}`;
            wrote = true;
        } else if (/^\s*X-GNOME-Autostart-enabled\s*=/.test(lines[i])) {
            lines[i] = `X-GNOME-Autostart-enabled=${!hidden}`;
        }
    }
    if (!wrote)
        lines.splice(start + 1, 0, `Hidden=${hidden}`);
    return lines.join("\n");
}

function oneLine(value) {
    return String(value ?? "").replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/\r/g, "\\r");
}

function autostartText(app) {
    const lines = [
        ENTRY_HEADER,
        "Type=Application",
        `Name=${oneLine(app.name)}`,
        `Exec=${oneLine(stripFieldCodes(app.exec))}`
    ];
    if (app.icon)
        lines.push(`Icon=${oneLine(app.icon)}`);
    lines.push(`Terminal=${app.terminal ? "true" : "false"}`);
    lines.push("Hidden=false");
    return lines.join("\n") + "\n";
}

function autostartName(id) {
    const base = String(id ?? "").replace(/\.desktop$/i, "").replace(/[\/\0]/g, "-");
    return base ? `${base}.desktop` : "";
}

function quoteWord(word) {
    return `'${String(word).replace(/'/g, "'\\''")}'`;
}

function sessionLaunches(files, desktops) {
    const out = [];
    for (const file of files) {
        const e = file.entry;
        if (!e || e.type !== "Application" || e.hidden || !e.autostartEnabled || e.terminal)
            continue;
        if (!shownIn(e, desktops))
            continue;
        const exec = stripFieldCodes(e.exec);
        if (!exec)
            continue;
        const guard = e.tryExec ? `command -v ${quoteWord(e.tryExec)} >/dev/null 2>&1 || exit 0; ` : "";
        out.push(`${guard}exec ${exec}`);
    }
    return out;
}
