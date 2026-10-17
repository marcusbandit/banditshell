function parseDetect(text) {
    const found = [];
    let current = null;

    for (const raw of String(text ?? "").split("\n")) {
        const line = raw.trim();
        if (!line)
            continue;

        if (!/^\s/.test(raw)) {
            const header = /^Display (\d+)\b/.exec(line);
            current = header ? {
                index: header[1],
                bus: "",
                name: "",
                model: "",
                max: 100
            } : null;
            if (current)
                found.push(current);
            continue;
        }

        if (!current)
            continue;

        const bus = /^I2C bus:\s*\/dev\/i2c-(\d+)$/.exec(line);
        if (bus) {
            current.bus = bus[1];
            continue;
        }

        const connector = /^DRM connector:\s*card\d+-(\S+)$/.exec(line);
        if (connector) {
            current.name = connector[1];
            continue;
        }

        const monitor = /^Monitor:\s*(.+)$/.exec(line);
        if (monitor) {
            const parts = monitor[1].split(":");
            current.model = parts.length > 1 ? parts[1] : monitor[1];
        }
    }

    return found.filter(display => display.name);
}

function parseVcp(text) {
    const match = /^VCP\s+10\s+C\s+(\d+)\s+(\d+)\s*$/m.exec(String(text ?? ""));
    if (!match || !(Number(match[2]) > 0))
        return null;
    return {
        current: Number(match[1]),
        max: Number(match[2])
    };
}

function staleDisplays(displays, readAt, now, windowMs) {
    return (displays ?? []).filter(display => !(now - (readAt?.[display.index] ?? -Infinity) < windowMs));
}

function target(display) {
    return display?.bus ? ["--bus", display.bus] : ["--display", String(display?.index ?? "")];
}

function rawLevel(fraction, max) {
    const top = Number(max) > 0 ? Number(max) : 100;
    const f = Number(fraction);
    return Math.max(0, Math.min(top, Math.round((isFinite(f) ? Math.max(0, Math.min(1, f)) : 0) * top)));
}

function restAfter(previous, floor, ceiling) {
    return Math.min(ceiling, Math.max(floor, (Number(previous) || 0) * 2));
}
