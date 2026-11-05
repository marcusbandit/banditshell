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

function chunked(text, fits) {
    const chars = Array.from(text);
    const part = (from, to) => chars.slice(from, to).join("");
    const greedy = [];
    let at = 0;
    while (at < chars.length) {
        let lo = 1;
        let hi = chars.length - at;
        while (lo < hi) {
            const mid = Math.ceil((lo + hi) / 2);
            if (fits(part(at, at + mid)))
                lo = mid;
            else
                hi = mid - 1;
        }
        greedy.push(part(at, at + lo));
        at += lo;
    }
    const size = Math.ceil(chars.length / greedy.length);
    const even = [];
    for (let i = 0; i < chars.length; i += size)
        even.push(part(i, i + size));
    return even.every(piece => fits(piece)) ? even : greedy;
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
        used += unit.length;
        if (fits(trimmed(unit))) {
            line = unit;
            continue;
        }
        const word = trimmed(unit);
        const parts = chunked(word, fits);
        const start = used - unit.length;
        let taken = 0;
        for (let i = 0; i < parts.length - 1; i++) {
            taken += parts[i].length;
            line = parts[i];
            used = start + taken;
            close();
        }
        used = start + unit.length;
        line = parts[parts.length - 1] + unit.slice(word.length);
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
    const least = Math.min(1, stem);
    if (!fits(line(least)))
        return cropped(rest.replace(/^\s+/, ""), fits);
    let lo = least;
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

function heading(name, fits) {
    if (fits(name))
        return [name];
    let lo = 1;
    let hi = name.length - 1;
    while (lo < hi) {
        const mid = Math.ceil((lo + hi) / 2);
        if (fits(name.slice(0, mid)))
            lo = mid;
        else
            hi = mid - 1;
    }
    const soft = Math.max(name.lastIndexOf("-", lo - 1), name.lastIndexOf("_", lo - 1), name.lastIndexOf(" ", lo - 1), name.lastIndexOf(".", lo - 1)) + 1;
    const cut = soft > lo / 2 && soft < lo ? soft : lo;
    const first = trimmed(name.slice(0, cut));
    const rest = name.slice(cut).replace(/^\s+/, "");
    if (fits(rest))
        return [first, rest];
    return [first, squeezed(rest, rest.length - extensionAt(rest), fits, false)];
}
