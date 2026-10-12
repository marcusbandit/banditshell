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
