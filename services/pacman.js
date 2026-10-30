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
    return `${version ?? ""}`.replace(/^\d+:/, "").replace(/\+.*$/, "").replace(/-[^-]*$/, "").replace(/[.-][a-z]+\d*$/i, "");
}

function pending(list, name) {
    return (list ?? []).find(u => u.name === name) ?? null;
}

function verdict(tool, code) {
    const n = Number(code);
    if (code === "" || code === undefined || !Number.isFinite(n))
        return "error";
    switch (tool) {
    case "apt":
        return n === 0 ? "updates" : "error";
    case "dnf":
        return n === 100 ? "updates" : n === 0 ? "none" : "error";
    case "zypper":
        return n === 0 || n >= 100 ? "updates" : "error";
    }
    return n === 0 ? "updates" : n === 2 ? "none" : "error";
}

function listed(tool, lines) {
    const out = [];
    const all = lines ?? [];
    switch (tool) {
    case "apt":
        for (const line of all) {
            const found = /^([^\s\/]+)\/\S+\s+(\S+)\s+\S+\s+\[upgradable from: ([^\]\s]+)\]\s*$/.exec(line);
            if (found)
                out.push({ name: found[1], from: found[3], to: found[2] });
        }
        return out;
    case "dnf":
        for (let i = 0; i < all.length; i++) {
            if (/^Obsoleting/.test(all[i]))
                break;
            let line = all[i];
            if (/^\S+\.\S+$/.test(line.trim()) && i + 1 < all.length && /^\s+\S+\s+\S+\s*$/.test(all[i + 1]))
                line = `${line.trim()} ${all[++i].trim()}`;
            const found = /^(\S+)\.([A-Za-z0-9_]+)\s+(\S+)\s+(\S+)\s*$/.exec(line);
            if (found && /\d/.test(found[3]))
                out.push({ name: found[1], from: "", to: found[3] });
        }
        return out;
    case "zypper":
        for (const line of all) {
            const cells = line.split("|").map(c => c.trim());
            if (cells.length >= 6 && cells[0] === "v" && cells[2] && cells[4])
                out.push({ name: cells[2], from: cells[3], to: cells[4] });
        }
        return out;
    }
    return updates(all);
}

function kernelUpdate(list, tool, kernel) {
    const names = {
        apt: /^linux-image-/,
        dnf: /^kernel(-core)?$/,
        zypper: /^kernel-(default|longterm|preempt|vanilla|64kb)$/
    };
    if (!names[tool])
        return pending(list, kernel);
    const found = (list ?? []).filter(u => names[tool].test(u.name));
    return found.find(u => !/\d+\.\d+/.test(u.name) && u.name !== "kernel-core") ?? found[0] ?? null;
}

function terminalCommand(tool, configured, rolling) {
    const text = `${configured ?? ""}`.trim();
    if (tool === "pacman" || (text !== "" && text.replace(/\s+/g, " ") !== "sudo pacman -Syu"))
        return text || "sudo pacman -Syu";
    switch (tool) {
    case "apt":
        return "sudo sh -c 'apt-get update && apt-get full-upgrade'";
    case "dnf":
        return "sudo dnf upgrade --refresh";
    case "zypper":
        return rolling ? "sudo zypper dist-upgrade" : "sudo zypper update";
    }
    return text || "sudo pacman -Syu";
}
