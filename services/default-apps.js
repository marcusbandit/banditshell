const TERMINAL_SCHEME = "x-scheme-handler/terminal";

const GROUPS = {
    defBrowser: { types: ["x-scheme-handler/http", "x-scheme-handler/https"] },
    defFiles: { types: ["inode/directory"] },
    defTerm: { types: [TERMINAL_SCHEME], category: "TerminalEmulator" },
    defMail: { types: ["x-scheme-handler/mailto"] },
    defImages: { types: ["image/png", "image/jpeg", "image/webp", "image/gif"] },
    defVideo: { types: ["video/mp4", "video/webm", "video/x-matroska"] }
};

function allTypes() {
    const out = [];
    for (const key in GROUPS)
        for (const type of GROUPS[key].types)
            if (!out.includes(type))
                out.push(type);
    return out;
}

function typeMatches(declared, wanted) {
    if (declared === wanted)
        return true;
    return declared.endsWith("/*") && wanted.startsWith(declared.slice(0, -1));
}

function handledTypes(entry, group) {
    return group.types.filter(t => entry.mimeTypes.some(d => typeMatches(d, t)));
}

function offers(entries, group, currentId) {
    const enough = Math.ceil(group.types.length / 2);
    const ranked = [];
    for (const entry of entries) {
        const covers = handledTypes(entry, group).length;
        const wanted = group.category ? entry.categories.includes(group.category) && !entry.noDisplay : covers >= enough;
        if (entry.id !== currentId && (!wanted || entry.type !== "Application"))
            continue;
        ranked.push({ id: entry.id, name: entry.name || entry.id.replace(/\.desktop$/, ""), covers });
    }
    ranked.sort((a, b) => b.covers - a.covers || a.name.localeCompare(b.name));
    const out = ranked.map(r => [r.id, r.name]);
    if (currentId && !out.some(o => o[0] === currentId))
        out.push([currentId, currentId.replace(/\.desktop$/, "")]);
    return out;
}

function firstId(value) {
    return String(value ?? "").split(";")[0].trim();
}

function parseDefaults(text) {
    const out = {};
    for (const line of String(text ?? "").split("\n")) {
        const eq = line.indexOf("=");
        if (eq < 1)
            continue;
        out[line.slice(0, eq)] = firstId(line.slice(eq + 1));
    }
    return out;
}

function groupValue(group, defaults) {
    const votes = {};
    for (const type of group.types) {
        const id = defaults[type];
        if (id)
            votes[id] = (votes[id] ?? 0) + 1;
    }
    let best = "";
    for (const type of group.types) {
        const id = defaults[type];
        if (id && (!best || votes[id] > votes[best]))
            best = id;
    }
    return best;
}

function subtypeOf(type) {
    return type.split("/").pop().replace(/^x-/, "");
}

function strays(group, defaults, chosen) {
    const byApp = {};
    for (const type of group.types) {
        const id = defaults[type];
        if (!id || id === chosen)
            continue;
        (byApp[id] = byApp[id] ?? []).push(subtypeOf(type));
    }
    return Object.keys(byApp).map(id => ({ id, types: byApp[id] }));
}

function terminalListEntries(text) {
    const out = [];
    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.trim();
        if (!line || line.startsWith("#"))
            continue;
        out.push(line);
    }
    return out;
}

function terminalListFirst(text) {
    const first = terminalListEntries(text)[0] ?? "";
    return first.replace(/^[+-]/, "").split(":")[0];
}

function terminalListSet(text, id) {
    const kept = String(text ?? "").split("\n").filter(raw => {
        const line = raw.trim().replace(/^[+-]/, "").split(":")[0];
        return line !== id;
    });
    while (kept.length && kept[kept.length - 1] === "")
        kept.pop();
    return [id].concat(kept).join("\n") + "\n";
}
