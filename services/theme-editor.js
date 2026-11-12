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
            return `${KEYS[i]} needs a six digit hex colour`;
    }
    return "";
}

function setKey(text, key, value) {
    var quoted = `"${value.trim().toUpperCase()}"`;
    var line = new RegExp(`^(${key}\\s*=\\s*)(?:"[^"]*"|'[^']*')`, "m");
    var table = text.search(/^\s*\[/m);
    var topEnd = table < 0 ? text.length : table;
    var found = line.exec(text);
    if (found && found.index < topEnd)
        return text.slice(0, found.index) + found[1] + quoted + text.slice(found.index + found[0].length);
    var head = text.slice(0, topEnd);
    var glue = head.length === 0 || head.endsWith("\n") ? "" : "\n";
    return `${head}${glue}${key} = ${quoted}\n${text.slice(topEnd)}`;
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

function overridesFrom(colours, current) {
    var next = {};
    var any = false;
    for (var i = 0; i < KEYS.length; i++) {
        var value = String(colours[KEYS[i]] || "").trim();
        if (isHex(value) && value.toLowerCase() !== String(current[KEYS[i]] || "").toLowerCase()) {
            next[KEYS[i]] = value;
            any = true;
        }
    }
    return any ? next : null;
}
