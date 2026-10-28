.pragma library

var NAMES = {
    DESKTOP: "Desktop",
    DOCUMENTS: "Documents",
    DOWNLOAD: "Downloads",
    MUSIC: "Music",
    PICTURES: "Pictures",
    VIDEOS: "Videos",
    PUBLICSHARE: "Public",
    TEMPLATES: "Templates"
};

function unescape(value) {
    return value.replace(/\\(.)/g, "$1");
}

function parse(text, home) {
    const found = {};
    for (const line of String(text ?? "").split("\n")) {
        const match = /^\s*XDG_([A-Z]+)_DIR\s*=\s*"((?:[^"\\]|\\.)*)"\s*$/.exec(line);
        if (!match || !NAMES[match[1]])
            continue;
        let value = match[2];
        if (value === "$HOME" || value.lastIndexOf("$HOME/", 0) === 0)
            value = home + unescape(value.slice(5));
        else if (value[0] === "/")
            value = unescape(value);
        else
            continue;
        value = value.replace(/\/+$/, "");
        if (value !== "" && value !== home)
            found[NAMES[match[1]]] = value;
    }
    const folders = {};
    for (const key in NAMES)
        folders[NAMES[key]] = found[NAMES[key]] ?? `${home}/${NAMES[key]}`;
    return folders;
}

function byPath(folders) {
    const named = {};
    for (const name in folders)
        named[folders[name]] = name;
    return named;
}

function shown(path, home) {
    if (path === home)
        return "~";
    return path.lastIndexOf(home + "/", 0) === 0 ? `~${path.slice(home.length)}` : path;
}
