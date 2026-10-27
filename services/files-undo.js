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

function pick(items, entry) {
    var taken = [];
    var out = [];
    for (var i = 0; i < entry.paths.length; i++) {
        var best = null;
        for (var j = 0; j < items.length; j++) {
            var item = items[j];
            if (item.path !== entry.paths[i] || taken.indexOf(item) >= 0 || !(item.deleted >= entry.at - SLACK))
                continue;
            if (!best || Math.abs(item.deleted - entry.at) < Math.abs(best.deleted - entry.at))
                best = item;
        }
        if (best)
            taken.push(best);
        out.push(best);
    }
    return out;
}

function command(entry) {
    if (entry.kind === "copy")
        return ["sh", "-c", TRASH_COPIES, "sh"].concat(entry.pairs.map(function (pair) {
            return pair.to;
        }));
    var args = [];
    for (var i = 0; i < entry.pairs.length; i++)
        args.push(entry.pairs[i].to, entry.pairs[i].from);
    return ["sh", "-c", MOVE_BACK, "sh"].concat(args);
}

function items(entry) {
    if (entry.kind === "trash")
        return entry.paths;
    return entry.pairs.map(function (pair) {
        return entry.kind === "copy" ? pair.to : pair.from;
    });
}

function outcome(entry, text) {
    var counts = {ok: 0, gone: 0, taken: 0, failed: 0, done: []};
    var all = items(entry);
    var lines = text.split("\n");
    var at = 0;
    for (var i = 0; i < lines.length; i++) {
        var word = lines[i].trim();
        if (counts[word] === undefined || word === "done")
            continue;
        counts[word] += 1;
        if (word === "ok" && at < all.length)
            counts.done.push(all[at]);
        at += 1;
    }
    return counts;
}

function parentOf(path) {
    var cut = path.lastIndexOf("/");
    return cut <= 0 ? "/" : path.slice(0, cut);
}

function listed(paths, many) {
    if (paths.length === 1)
        return baseName(paths[0]);
    if (paths.length === 2)
        return baseName(paths[0]) + " and " + baseName(paths[1]);
    return paths.length + " " + many;
}

function folder(paths, here, home) {
    var parents = [];
    for (var i = 0; i < paths.length; i++) {
        var parent = parentOf(paths[i]);
        if (parents.indexOf(parent) < 0)
            parents.push(parent);
    }
    if (parents.length === 0 || parents.length === 1 && parents[0] === here)
        return "";
    if (parents.length > 1)
        return parents.length + " folders";
    return parents[0] === home ? "Home" : parents[0] === "/" ? "/" : baseName(parents[0]);
}

function summary(entry, counts, here, home) {
    var total = size(entry);
    var one = total === 1;
    var name = baseName(items(entry)[0]);
    if (entry.kind === "copy")
        name = baseName(entry.pairs[0].from);

    if (counts.ok > 0) {
        var done = counts.done;
        var where = folder(done, here, home);
        var rest = counts.ok < total ? ", " + (total - counts.ok) + " could not be" : "";
        switch (entry.kind) {
        case "trash":
            return listed(done, "files") + " restored" + (where ? " to " + where : "") + rest;
        case "rename":
            return "Renamed back to " + name + (where ? " in " + where : "");
        case "copy":
            var sources = done.map(function (to) {
                return baseName(to);
            });
            return (done.length === 1 ? "Copy of " + sources[0] : done.length === 2 ? "Copies of " + sources[0] + " and " + sources[1] : done.length + " copies") + " moved to the trash" + rest;
        default:
            return listed(done, "files") + " moved back" + (where ? " to " + where : "") + rest;
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

function report(entry, texts, here, home) {
    if (entry.kind !== "batch") {
        var counts = outcome(entry, texts[0] || "");
        return {ok: counts.ok > 0, text: summary(entry, counts, here, home), shown: entry.kind === "copy" ? [] : counts.done};
    }
    var told = entry.parts.map(function (part, i) {
        return report(part, [texts[i] || ""], here, home);
    });
    var ok = told.some(function (one) {
        return one.ok;
    });
    return {
        ok: ok,
        text: ok ? told.map(function (one) {
            return one.text;
        }).join(", ") : told[0].text,
        shown: told.reduce(function (all, one) {
            return all.concat(one.shown);
        }, [])
    };
}
