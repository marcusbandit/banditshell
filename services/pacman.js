function report(text) {
    const values = {};
    const lines = [];
    for (const line of `${text ?? ""}`.split("\n")) {
        if (line.startsWith("|")) {
            lines.push(line.slice(1));
            continue;
        }
        const at = line.indexOf("=");
        if (at > 0)
            values[line.slice(0, at)] = line.slice(at + 1);
    }
    return { values, lines };
}

function updates(lines) {
    const out = [];
    for (const line of lines ?? []) {
        const found = /^(\S+)\s+(\S+)\s+->\s+(\S+)\s*$/.exec(line);
        if (found)
            out.push({ name: found[1], from: found[2], to: found[3] });
    }
    return out;
}

function pretty(version) {
    return `${version ?? ""}`.replace(/^\d+:/, "").replace(/-[^-]*$/, "").replace(/[.-][a-z]+\d*$/i, "");
}

function pending(list, name) {
    return (list ?? []).find(u => u.name === name) ?? null;
}
