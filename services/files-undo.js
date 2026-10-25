.pragma library

var LIMIT = 50;
var SLACK = 2;

var EXISTS = 'i=0; for p; do i=$((i+1)); if [ -e "$p" ] || [ -L "$p" ]; then echo "$i"; fi; done';

var MOVE_BACK = 'while [ $# -gt 1 ]; do '
    + 'if [ ! -e "$1" ] && [ ! -L "$1" ]; then echo gone; '
    + 'elif [ -e "$2" ] || [ -L "$2" ]; then echo taken; '
    + 'elif mv -n -- "$1" "$2"; then echo ok; '
    + 'else echo failed; fi; shift 2; done';

var TRASH_COPIES = 'for p; do '
    + 'if [ ! -e "$p" ] && [ ! -L "$p" ]; then echo gone; '
    + 'elif gio trash -- "$p"; then echo ok; '
    + 'else echo failed; fi; done';

var RESTORE = 'for u; do '
    + 'if [ "$u" = - ]; then echo gone; '
    + 'elif gio trash --restore -- "$u"; then echo ok; '
    + 'else echo taken; fi; done';

var TRASH_LISTING = ["gio", "list", "-u", "-a", "trash::orig-path,trash::deletion-date", "trash:///"];

function baseName(path) {
    var trimmed = path.length > 1 ? path.replace(/\/+$/, "") : path;
    return trimmed.slice(trimmed.lastIndexOf("/") + 1);
}

function join(dir, name) {
    return dir === "/" ? "/" + name : dir + "/" + name;
}

function into(paths, dir) {
    var out = [];
    for (var i = 0; i < paths.length; i++) {
        var to = join(dir, baseName(paths[i]));
        if (to !== paths[i])
            out.push({from: paths[i], to: to});
    }
    return out;
}

function moved(pairs) {
    return {kind: "move", pairs: pairs};
}

function renamed(from, to) {
    return {kind: "rename", pairs: from === to ? [] : [{from: from, to: to}]};
}

function copied(pairs) {
    return {kind: "copy", pairs: pairs};
}

function fresh(entry, existing) {
    return {kind: entry.kind, pairs: entry.pairs.filter(function (pair) {
        return existing.indexOf(pair.to) < 0;
    })};
}

function wallClock(seconds) {
    var d = new Date(seconds * 1000);
    return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds(), d.getMilliseconds()) / 1000;
}

function trashed(paths, now) {
    return {kind: "trash", paths: paths.slice(), at: wallClock(now)};
}

function batch(parts) {
    var kept = parts.filter(function (part) {
        return part && size(part) > 0;
    });
    return kept.length === 1 ? kept[0] : {kind: "batch", parts: kept};
}

function size(entry) {
    if (entry.kind === "batch")
        return entry.parts.reduce(function (sum, part) {
            return sum + size(part);
        }, 0);
    return entry.kind === "trash" ? entry.paths.length : entry.pairs.length;
}

function remember(stack, entry) {
    if (!entry || size(entry) === 0)
        return stack;
    var next = stack.concat([entry]);
    return next.length > LIMIT ? next.slice(next.length - LIMIT) : next;
}

function existsCommand(paths) {
    return ["sh", "-c", EXISTS, "sh"].concat(paths);
}

function existing(paths, text) {
    var out = [];
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var at = parseInt(lines[i], 10);
        if (at >= 1 && at <= paths.length)
            out.push(paths[at - 1]);
    }
    return out;
}

function unescapeBytes(text) {
    if (text.indexOf("\\x") < 0)
        return text;
    var encoded = text.replace(/\\x([0-9a-fA-F]{2})|[^\\]+|\\/g, function (piece, hex) {
        return hex !== undefined ? "%" + hex : encodeURIComponent(piece);
    });
    try {
        return decodeURIComponent(encoded);
    } catch (e) {
        return text;
    }
}

function stampSeconds(stamp) {
    var m = /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/.exec(stamp);
    if (!m)
        return NaN;
    return Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) / 1000;
}

function parseTrash(text) {
    var out = [];
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var fields = lines[i].split("\t");
        if (fields.length < 4 || fields[0].indexOf("trash:///") !== 0)
            continue;
        var attributes = fields.slice(3).join("\t");
        var date = /(?:^| )trash::deletion-date=(\S+)/.exec(attributes);
        if (!date)
            continue;
        var rest = attributes.slice(0, date.index) + attributes.slice(date.index + date[0].length);
        var origin = /(?:^| )trash::orig-path=(.*)$/.exec(rest);
        if (!origin)
            continue;
        out.push({uri: fields[0], path: unescapeBytes(origin[1].replace(/ +$/, "")), deleted: stampSeconds(date[1])});
    }
    return out;
}

function pick(items, entry) {
    var taken = [];
    var out = [];
    for (var i = 0; i < entry.paths.length; i++) {
        var best = null;
        for (var j = 0; j < items.length; j++) {
            var item = items[j];
            if (item.path !== entry.paths[i] || taken.indexOf(item.uri) >= 0 || !(item.deleted >= entry.at - SLACK))
                continue;
            if (!best || Math.abs(item.deleted - entry.at) < Math.abs(best.deleted - entry.at))
                best = item;
        }
        if (best)
            taken.push(best.uri);
        out.push(best ? best.uri : "-");
    }
    return out;
}

function command(entry, uris) {
    if (entry.kind === "trash")
        return ["sh", "-c", RESTORE, "sh"].concat(uris);
    if (entry.kind === "copy")
        return ["sh", "-c", TRASH_COPIES, "sh"].concat(entry.pairs.map(function (pair) {
            return pair.to;
        }));
    var args = [];
    for (var i = 0; i < entry.pairs.length; i++)
        args.push(entry.pairs[i].to, entry.pairs[i].from);
    return ["sh", "-c", MOVE_BACK, "sh"].concat(args);
}

function outcome(text) {
    var counts = {ok: 0, gone: 0, taken: 0, failed: 0};
    var lines = text.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var word = lines[i].trim();
        if (counts[word] !== undefined)
            counts[word] += 1;
    }
    return counts;
}

function firstName(entry) {
    return baseName(entry.kind === "trash" ? entry.paths[0] : entry.pairs[0].from);
}

function summary(entry, counts) {
    var total = size(entry);
    var one = total === 1;
    var name = firstName(entry);
    var some = counts.ok === total ? String(total) : counts.ok + " of " + total;

    if (counts.ok > 0) {
        switch (entry.kind) {
        case "trash":
            return (one ? name : some + " files") + " restored";
        case "rename":
            return "Renamed back to " + name;
        case "copy":
            return (one ? "Copy of " + name : some + " copies") + " moved to the trash";
        default:
            return (one ? name : some + " files") + " moved back";
        }
    }

    if (counts.taken > 0)
        return one ? name + " not brought back, the name is taken" : "Nothing brought back, the names are taken";
    if (counts.gone > 0 && entry.kind === "trash")
        return one ? name + " is no longer in the trash" : "Nothing restored, no longer in the trash";
    if (counts.gone > 0 && entry.kind === "copy")
        return one ? "The copy of " + name + " is already gone" : "Nothing to take back, the copies are gone";
    if (counts.gone > 0)
        return one ? name + " is no longer where it was moved" : "Nothing moved back, the files are gone";
    return one ? name + " could not be brought back" : "Nothing could be brought back";
}

function report(entry, texts) {
    if (entry.kind !== "batch") {
        var counts = outcome(texts[0] || "");
        return {ok: counts.ok > 0, text: summary(entry, counts)};
    }
    var told = entry.parts.map(function (part, i) {
        return report(part, [texts[i] || ""]);
    });
    var ok = told.some(function (one) {
        return one.ok;
    });
    return {ok: ok, text: ok ? told.map(function (one) {
        return one.text;
    }).join(", ") : told[0].text};
}
