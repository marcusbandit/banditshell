function splitFromRight(line, count) {
    const parts = [];
    let rest = line;
    for (let i = 0; i < count; i++) {
        const cut = rest.lastIndexOf(":");
        if (cut < 0)
            return null;
        parts.unshift(rest.slice(cut + 1));
        rest = rest.slice(0, cut);
    }
    parts.unshift(rest);
    return parts;
}

function connections(text) {
    const found = [];
    for (const line of String(text ?? "").split("\n")) {
        const parts = splitFromRight(line, 3);
        if (!parts || !parts[0])
            continue;
        found.push({
            name: parts[0],
            uuid: parts[1],
            type: parts[2],
            active: parts[3] === "yes"
        });
    }
    return found;
}

function fields(text) {
    const found = {};
    for (const line of String(text ?? "").split("\n")) {
        const cut = line.indexOf(":");
        if (cut > 0)
            found[line.slice(0, cut)] = line.slice(cut + 1);
    }
    return found;
}
