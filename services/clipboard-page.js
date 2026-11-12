.pragma library

var FILTERS = [
    {
        key: "all",
        label: "All types",
        icon: "list"
    },
    {
        key: "text",
        label: "Text",
        icon: "notes"
    },
    {
        key: "image",
        label: "Images",
        icon: "image"
    },
    {
        key: "link",
        label: "Links",
        icon: "link"
    },
    {
        key: "colour",
        label: "Colours",
        icon: "palette"
    },
    {
        key: "code",
        label: "Code",
        icon: "code"
    },
    {
        key: "file",
        label: "Files",
        icon: "folder"
    }
];

var SHAPES = {
    text: {
        title: "Text",
        icon: "notes",
        filter: "text"
    },
    speech: {
        title: "Dictation",
        icon: "mic",
        filter: "text"
    },
    image: {
        title: "Image",
        icon: "image",
        filter: "image"
    },
    link: {
        title: "Link",
        icon: "link",
        filter: "link"
    },
    email: {
        title: "Email address",
        icon: "alternate_email",
        filter: "link"
    },
    colour: {
        title: "Colour",
        icon: "palette",
        filter: "colour"
    },
    code: {
        title: "Code",
        icon: "code",
        filter: "code"
    },
    json: {
        title: "JSON",
        icon: "data_object",
        filter: "code"
    },
    file: {
        title: "File",
        icon: "draft",
        filter: "file"
    },
    files: {
        title: "Files",
        icon: "folder",
        filter: "file"
    }
};

var EMAIL = /^(?:mailto:)?[^\s@<>()"',;]+@[^\s@<>()"',;]+\.[a-z]{2,}$/i;
var COLOURISH = /^(?:#|rgba?\s*\(|hsla?\s*\()/i;
var BARE_HEX = /^(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i;
var FILE_KINDS = ["files", "document", "audio", "video"];
var DAY = 86400000;

function colourOf(entry, parseColour) {
    var text = String(entry.text || "").trim();
    if (!text || entry.file || (entry.paths || []).length)
        return null;
    if (COLOURISH.test(text))
        return parseColour(text);
    return BARE_HEX.test(text) && /[a-f]/i.test(text) ? parseColour("#" + text) : null;
}

function swatchOf(c) {
    if (!c)
        return "transparent";
    var two = function (n) {
        return Math.round(Math.min(255, Math.max(0, n))).toString(16).padStart(2, "0");
    };
    return "#" + (c.a < 1 ? two(c.a * 255) : "") + two(c.r) + two(c.g) + two(c.b);
}

function shapeOf(entry, parseColour) {
    var kind = entry.kind || "text";
    var text = String(entry.text || "").trim();
    var paths = entry.paths || [];
    if (kind === "image")
        return paths.length > 1 ? "files" : "image";
    if (FILE_KINDS.indexOf(kind) >= 0)
        return paths.length === 1 || (!paths.length && text.indexOf("\n") < 0) ? "file" : "files";
    if (colourOf(entry, parseColour))
        return "colour";
    if (EMAIL.test(text))
        return "email";
    if (kind === "url")
        return "link";
    if (kind === "json")
        return "json";
    if (kind === "code")
        return "code";
    if (kind === "speech")
        return "speech";
    return "text";
}

function passes(shape, filter) {
    return !filter || filter === "all" || (SHAPES[shape] || SHAPES.text).filter === filter;
}

function midnight(time) {
    var d = new Date(time);
    d.setHours(0, 0, 0, 0);
    return d.getTime();
}

function dayOf(recorded, now) {
    var days = Math.round((midnight(now) - midnight(recorded)) / DAY);
    if (days <= 0)
        return "Today";
    if (days === 1)
        return "Yesterday";
    if (days < 7)
        return "This week";
    if (days < 31)
        return "This month";
    return "Older";
}

function sections(items, now) {
    var out = [];
    var last = "";
    var pinned = items.filter(function (it) {
        return it.entry.pinned;
    });
    var loose = items.filter(function (it) {
        return !it.entry.pinned;
    });
    if (pinned.length) {
        out.push({
            header: true,
            title: "Pinned"
        });
        last = "Pinned";
    }
    for (var i = 0; i < pinned.length; i++)
        out.push(pinned[i]);
    for (var j = 0; j < loose.length; j++) {
        var title = dayOf(loose[j].entry.recorded || 0, now);
        if (title !== last) {
            out.push({
                header: true,
                title: title
            });
            last = title;
        }
        out.push(loose[j]);
    }
    return out;
}

function counts(text) {
    var t = String(text || "");
    var trimmed = t.trim();
    return {
        characters: t.length,
        words: trimmed ? trimmed.split(/\s+/).length : 0,
        lines: trimmed ? t.replace(/\s+$/, "").split(/\r?\n/).length : 0
    };
}

function plural(n, one) {
    return n + " " + one + (n === 1 ? "" : "s");
}

function linkParts(text) {
    var m = /^([a-z][a-z0-9+.-]*):(?:\/\/)?([^/?#\s]*)([^\s]*)$/i.exec(String(text || "").trim());
    if (!m)
        return null;
    return {
        scheme: m[1].toLowerCase(),
        host: m[2].replace(/^[^@]*@/, "").replace(/^www\./i, ""),
        rest: m[3]
    };
}

function emailOf(text) {
    return String(text || "").trim().replace(/^mailto:/i, "");
}

function facts(entry, shape, colour, forms) {
    var out = [];
    var text = String(entry.text || "");
    var add = function (label, value) {
        if (value !== "" && value !== undefined && value !== null)
            out.push({
                label: label,
                value: String(value)
            });
    };
    add("Kind", (SHAPES[shape] || SHAPES.text).title);
    switch (shape) {
    case "image":
        if (entry.w > 0)
            add("Dimensions", entry.w + " × " + entry.h);
        break;
    case "colour":
        if (colour && forms) {
            add("Hex", forms.hex(colour).toUpperCase());
            add("RGB", forms.rgb(colour));
            add("HSL", forms.hsl(colour));
        }
        break;
    case "link":
        var link = linkParts(text);
        if (link) {
            add("Site", link.host);
            add("Scheme", link.scheme);
        }
        break;
    case "email":
        var address = emailOf(text);
        add("Domain", address.slice(address.indexOf("@") + 1));
        break;
    case "file":
    case "files":
        var paths = entry.paths && entry.paths.length ? entry.paths : entry.file ? [entry.file] : text.trim() ? [text.trim()] : [];
        if (paths.length > 1)
            add("Items", String(paths.length));
        else if (paths.length)
            add("Path", paths[0]);
        break;
    default:
        var c = counts(text);
        add("Characters", String(c.characters));
        add("Words", String(c.words));
        add("Lines", String(c.lines));
    }
    return out;
}
