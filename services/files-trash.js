.pragma library

var READ = 'ls=$1 home=$2; shift 2; uid=$(id -u); '
    + 'one() { [ -d "$1/info" ] || return 0; '
    + 'if [ "$ls" != - ]; then printf "L\\037%s\\037" "$1"; "$ls" "$1/files"; printf "\\036"; fi; '
    + 'for f in "$1"/info/*.trashinfo; do [ -f "$f" ] || continue; n=${f##*/}; '
    + 'printf "I\\037%s\\037%s\\037" "$1" "${n%.trashinfo}"; cat -- "$f"; printf "\\036"; done; }; '
    + 'one "$home"; '
    + 'for t; do t=${t%/}; '
    + 'if [ -d "$t/.Trash" ] && [ -k "$t/.Trash" ] && [ ! -L "$t/.Trash" ]; then one "$t/.Trash/$uid"; fi; '
    + 'one "$t/.Trash-$uid"; done';

var RESTORE = 'while [ $# -gt 2 ]; do d=$1 n=$2 o=$3; shift 3; '
    + 'f="$d/files/$n"; up=${o%/*}; [ -n "$up" ] || up=/; '
    + 'if [ -z "$d" ] || { [ ! -e "$f" ] && [ ! -L "$f" ]; }; then echo gone; '
    + 'elif [ -z "$o" ]; then echo failed; '
    + 'elif [ -e "$o" ] || [ -L "$o" ]; then echo taken; '
    + 'elif mkdir -p -- "$up" && mv -n -- "$f" "$o" && { [ -e "$o" ] || [ -L "$o" ]; } && [ ! -e "$f" ] && [ ! -L "$f" ]; then '
    + 'rm -f -- "$d/info/$n.trashinfo"; echo ok; '
    + 'else echo failed; fi; done';

function baseName(path) {
    return path.slice(path.lastIndexOf("/") + 1);
}

function parentOf(path) {
    var cut = path.lastIndexOf("/");
    return cut <= 0 ? "/" : path.slice(0, cut);
}

function within(path, files) {
    return path === files || path.indexOf(files + "/") === 0;
}

function topdirs(paths) {
    var out = [];
    for (var i = 0; i < paths.length; i++) {
        var at = paths[i];
        while (at !== "/") {
            at = parentOf(at);
            if (out.indexOf(at) < 0)
                out.push(at);
        }
    }
    return out;
}

function readCommand(ls, home, tops) {
    return ["sh", "-c", READ, "sh", ls || "-", home].concat(tops);
}

function stampSeconds(stamp) {
    var m = /^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)/.exec(stamp);
    if (!m)
        return NaN;
    return Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]) / 1000;
}

function topOf(dir) {
    var named = /^(.*)\/\.Trash-\d+$/.exec(dir) || /^(.*)\/\.Trash\/\d+$/.exec(dir);
    return named ? named[1] || "/" : null;
}

function origin(dir, raw) {
    var path;
    try {
        path = decodeURIComponent(raw);
    } catch (e) {
        return "";
    }
    if (path === "")
        return "";
    if (path.charAt(0) === "/")
        return path;
    var top = topOf(dir);
    if (top === null)
        return "";
    return top === "/" ? "/" + path : top + "/" + path;
}

function readInfo(dir, content) {
    var path = "";
    var deleted = NaN;
    var group = "";
    var lines = content.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].replace(/\r$/, "");
        if (line.charAt(0) === "[") {
            group = line;
            continue;
        }
        if (group !== "[Trash Info]")
            continue;
        if (line.indexOf("Path=") === 0 && !path)
            path = origin(dir, line.slice(5));
        else if (line.indexOf("DeletionDate=") === 0 && isNaN(deleted))
            deleted = stampSeconds(line.slice(13));
    }
    return {path: path, deleted: deleted};
}

function parse(text) {
    var items = [];
    var listings = [];
    var records = text.split("\x1e");
    for (var i = 0; i < records.length; i++) {
        var fields = records[i].split("\x1f");
        if (fields[0] === "L" && fields.length >= 3) {
            try {
                listings.push({dir: fields[1], answer: JSON.parse(fields.slice(2).join("\x1f"))});
            } catch (e) {}
        } else if (fields[0] === "I" && fields.length >= 4) {
            var info = readInfo(fields[1], fields.slice(3).join("\x1f"));
            items.push({dir: fields[1], name: fields[2], path: info.path, deleted: info.deleted});
        }
    }
    return {items: items, listings: listings};
}

function entries(parsed) {
    var out = [];
    for (var i = 0; i < parsed.listings.length; i++) {
        var listing = parsed.listings[i];
        if (!listing.answer || !listing.answer.ok)
            continue;
        var found = listing.answer.entries || [];
        for (var j = 0; j < found.length; j++) {
            var entry = found[j];
            var item = null;
            for (var k = 0; k < parsed.items.length && !item; k++) {
                if (parsed.items[k].dir === listing.dir && parsed.items[k].name === entry.name)
                    item = parsed.items[k];
            }
            var path = item ? item.path : "";
            var name = path ? baseName(path) : entry.name;
            out.push(Object.assign({}, entry, {
                key: listing.dir + "/files/" + entry.name,
                name: name,
                hidden: name.charAt(0) === ".",
                dir: path ? parentOf(path) : "",
                trash: {dir: listing.dir, name: entry.name, path: path, deleted: item ? item.deleted : NaN}
            }));
        }
    }
    return out;
}

function infoPath(item) {
    return item.dir + "/info/" + item.name + ".trashinfo";
}

function restoreCommand(items) {
    var args = [];
    for (var i = 0; i < items.length; i++) {
        var item = items[i];
        args.push(item ? item.dir : "", item ? item.name : "", item ? item.path : "");
    }
    return ["sh", "-c", RESTORE, "sh"].concat(args);
}
