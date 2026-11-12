var KEYS = ["dim", "mid", "bright", "alarm"];

function isHex(value) {
    return /^#[0-9a-fA-F]{6}$/.test(String(value || "").trim());
}

function slug(name) {
    return String(name || "").trim().toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "");
}

function problem(name, colours, taken) {
    var id = slug(name);
    if (!id)
        return "give it a name";
    if (taken.indexOf(id) >= 0)
        return `${id} already exists`;
    for (var i = 0; i < KEYS.length; i++) {
        if (!isHex(colours[KEYS[i]]))
            return `${KEYS[i]} needs a colour like #7fb3d4`;
    }
    return "";
}

function setKey(text, key, value) {
    var line = new RegExp(`^(${key}\\s*=\\s*)"[^"]*"`, "m");
    var quoted = `"${value.trim().toUpperCase()}"`;
    if (line.test(text))
        return text.replace(line, (all, head) => head + quoted);
    return `${text}${text.endsWith("\n") ? "" : "\n"}${key} = ${quoted}\n`;
}

function editedToml(text, colours) {
    var out = String(text || "");
    out = setKey(out, "accent_dim", colours.dim);
    out = setKey(out, "accent_mid", colours.mid);
    out = setKey(out, "accent", colours.mid);
    out = setKey(out, "accent_bright", colours.bright);
    out = setKey(out, "orange", colours.alarm);
    return out;
}

function previewFrom(current, colours) {
    var next = Object.assign({}, current);
    for (var i = 0; i < KEYS.length; i++) {
        if (isHex(colours[KEYS[i]]))
            next[KEYS[i]] = colours[KEYS[i]].trim();
    }
    return next;
}
