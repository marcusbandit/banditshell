.pragma library

var READ = 'ls=$1 home=$2; shift 2; uid=$(id -u); '
    + 'one() { [ -d "$1/info" ] || return 0; d=$1; '
    + 'if [ "$ls" != - ]; then printf "L\\037%s\\037" "$d"; "$ls" "$d/files"; printf "\\036"; fi; '
    + "d=$d awk 'BEGIN { for (i = 1; i < ARGC; i++) if ((getline line < ARGV[i]) < 0) delete ARGV[i]; else close(ARGV[i]) } "
    + "FNR == 1 { if (NR > 1) printf \"\\036\"; n = FILENAME; sub(/.*\\//, \"\", n); sub(/\\.trashinfo$/, \"\", n); "
    + "printf \"I\\037%s\\037%s\\037\", ENVIRON[\"d\"], n } { print } END { if (NR > 0) printf \"\\036\" }' \"$d\"/info/*.trashinfo \"$d\"/info/.*.trashinfo < /dev/null; }; "
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

var EMPTY = 'home=$1; shift; uid=$(id -u); rc=0; seen=; '
    + 'for p; do d=${p%/files/*}; n=${p##*/}; t=${d##*/}; u=${d%/*}; ok=; '
    + '[ "$d" = "$home" ] && ok=1; [ "$t" = ".Trash-$uid" ] && ok=1; [ "$t" = "$uid" ] && [ "${u##*/}" = .Trash ] && ok=1; '
    + 'case $n in ""|.|..) ok=;; esac; [ "$p" = "$d/files/$n" ] || ok=; '
    + 'if [ -z "$ok" ]; then echo "not a trash item: $p" >&2; rc=1; continue; fi; '
    + 'rm -rf -- "$p" && rm -f -- "$d/info/$n.trashinfo" || { echo "could not delete $n" >&2; rc=1; }; '
    + 'case "$seen" in *"/$d/"*) continue;; esac; seen="$seen/$d/"; '
    + 'for i in "$d"/info/*.trashinfo "$d"/info/.*.trashinfo; do [ -f "$i" ] || continue; o=${i##*/}; o=${o%.trashinfo}; '
    + '[ -e "$d/files/$o" ] || [ -L "$d/files/$o" ] || [ -n "$(find "$i" -mmin -1)" ] || rm -f -- "$i"; done; done; exit $rc';

var CHUNK = 500;

var SIZE = 'xargs -d "\\n" -r du -s -b -- 2>/dev/null';

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

function trashed(path, files) {
    return within(path, files) || /\/\.Trash(-\d+|\/\d+)\/files\//.test(path);
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

function localSeconds(wall) {
    var d = new Date(wall * 1000);
    return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), d.getUTCHours(), d.getUTCMinutes(), d.getUTCSeconds()).getTime() / 1000;
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
    var known = {};
    for (var n = 0; n < parsed.items.length; n++)
        known[parsed.items[n].dir + "\x1f" + parsed.items[n].name] = parsed.items[n];
    for (var i = 0; i < parsed.listings.length; i++) {
        var listing = parsed.listings[i];
        if (!listing.answer || !listing.answer.ok)
            continue;
        var found = listing.answer.entries || [];
        for (var j = 0; j < found.length; j++) {
            var entry = found[j];
            var item = known[listing.dir + "\x1f" + entry.name] || null;
            var path = item ? item.path : "";
            var name = path ? baseName(path) : entry.name;
            out.push(Object.assign({}, entry, {
                key: listing.dir + "/files/" + entry.name,
                name: name,
                hidden: name.charAt(0) === ".",
                dir: path ? parentOf(path) : "",
                trashed: item && isFinite(item.deleted) ? localSeconds(item.deleted) : entry.mtime,
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

function trashDir(dir, home) {
    return dir === home || /^(\/.*)?\/\.Trash-\d+$/.test(dir) || /^(\/.*)?\/\.Trash\/\d+$/.test(dir);
}

function emptyable(item, home) {
    return !!item && typeof item.dir === "string" && typeof item.name === "string" && trashDir(item.dir, home) && item.name !== "" && item.name !== "." && item.name !== ".." && item.name.indexOf("/") < 0;
}

function emptyCommands(items, home, chunk) {
    var size = chunk || CHUNK;
    var paths = [];
    for (var i = 0; i < items.length; i++)
        if (emptyable(items[i], home))
            paths.push(items[i].dir + "/files/" + items[i].name);
    var out = [];
    for (var at = 0; at < paths.length; at += size)
        out.push(["sh", "-c", EMPTY, "sh", home].concat(paths.slice(at, at + size)));
    return out;
}

function sizeCommand() {
    return ["sh", "-c", SIZE];
}

function sizeInput(items) {
    var out = "";
    for (var i = 0; i < items.length; i++)
        if (items[i] && items[i].name.indexOf("\n") < 0)
            out += items[i].dir + "/files/" + items[i].name + "\n";
    return out;
}

function sizes(text) {
    var out = {};
    var lines = String(text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var cut = lines[i].indexOf("\t");
        if (cut <= 0)
            continue;
        var bytes = Number(lines[i].slice(0, cut));
        if (isFinite(bytes))
            out[lines[i].slice(cut + 1)] = bytes;
    }
    return out;
}
