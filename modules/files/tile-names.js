.pragma library

const ELLIPSIS = "\u2026";

function extensionAt(name) {
    const dot = name.lastIndexOf(".");
    const extension = name.slice(dot);
    if (dot <= 0 || extension.length < 2 || extension.length > 10 || /\s/.test(extension))
        return name.length;
    return dot;
}

function trimmed(text) {
    return text.replace(/\s+$/, "");
}

function pieces(text) {
    return text.match(/[^\s\-_.]*(?:[\s\-_.]+|$)/g).filter(p => p !== "");
}

function wrapped(units, fits) {
    const lines = [];
    let line = "";
    let used = 0;
    const close = () => {
        if (trimmed(line) !== "")
            lines.push({text: trimmed(line), end: used});
        line = "";
    };
    for (const unit of units) {
        if (fits(trimmed(line + unit))) {
            line += unit;
            used += unit.length;
            continue;
        }
        if (line !== "")
            close();
        for (const ch of fits(trimmed(unit)) ? [unit] : unit) {
            if (line !== "" && !fits(trimmed(line + ch)))
                close();
            line += ch;
            used += ch.length;
        }
    }
    if (line !== "")
        close();
    return lines;
}

function squeezed(rest, extension, fits, headed) {
    const stem = rest.length - extension;
    const line = shown => {
        const head = headed ? Math.ceil(shown / 2) : 0;
        return rest.slice(0, head).replace(/^\s+/, "") + ELLIPSIS + rest.slice(rest.length - extension - (shown - head));
    };
    if (!fits(line(0)))
        return cropped(rest.replace(/^\s+/, ""), fits);
    let lo = 0;
    let hi = stem;
    while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (fits(line(mid)))
            lo = mid;
        else
            hi = mid - 1;
    }
    return line(lo);
}

function cropped(text, fits) {
    let lo = 0;
    let hi = text.length;
    while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (fits(text.slice(0, mid) + ELLIPSIS))
            lo = mid;
        else
            hi = mid - 1;
    }
    return text.slice(0, lo) + ELLIPSIS;
}

function lines(name, most, fits) {
    if (fits(name))
        return [name];
    const cut = extensionAt(name);
    const units = pieces(name.slice(0, cut));
    if (cut < name.length)
        units.push(name.slice(cut));
    const laid = wrapped(units, fits);
    if (laid.length <= most)
        return laid.map(l => l.text);
    const kept = laid.slice(0, most - 1);
    const rest = name.slice(kept.length > 0 ? kept[kept.length - 1].end : 0);
    return kept.map(l => l.text).concat(squeezed(rest, name.length - cut, fits, kept.length === 0));
}
