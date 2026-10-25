.pragma library

var PROBE = 'i=0; while [ $# -ge 2 ]; do i=$((i+1)); to=$1 from=$2; shift 2; '
    + 'if [ -e "$to" ] || [ -L "$to" ]; then echo "t$i"; fi; '
    + 'if [ -d "$from" ] && [ ! -L "$from" ]; then echo "d$i"; fi; '
    + 'if [ -e "$to" ] && [ "$from" -ef "$to" ]; then echo "s$i"; fi; '
    + 'if [ -d "$to" ] && [ -e "$from" ]; then '
    + 'r=$(realpath -- "$to") && f=$(realpath -- "$(dirname -- "$from")") && '
    + 'case "$f/${from##*/}" in "$r"/*) echo "h$i";; esac; fi; done';

var PASTE = 'verb=$1; shift; '
    + 'while [ $# -ge 5 ]; do mode=$1 from=$2 to=$3 stem=$4 ext=$5; shift 5; '
    + 'if [ ! -e "$from" ] && [ ! -L "$from" ]; then echo gone; continue; fi; '
    + 'n=0; said=ok; '
    + 'if [ "$mode" = both ]; then n=2; '
    + 'while [ -e "$stem ($n)$ext" ] || [ -L "$stem ($n)$ext" ]; do n=$((n+1)); done; '
    + 'to="$stem ($n)$ext"; '
    + 'elif [ -e "$to" ] || [ -L "$to" ]; then '
    + 'if [ "$mode" != replace ]; then echo taken; continue; fi; '
    + 'gio trash -- "$to" || { echo failed; continue; }; said=replaced; fi; '
    + 'if [ "$verb" = mv ]; then mv -n -T -- "$from" "$to"; else cp -r -T -- "$from" "$to"; fi; '
    + 'if [ $? -eq 0 ] && { [ -e "$to" ] || [ -L "$to" ]; }; then echo "$said $n"; '
    + 'elif [ "$said" = replaced ]; then { [ ! -e "$to" ] && [ ! -L "$to" ]; } || gio trash -- "$to"; echo half; '
    + 'else echo failed; fi; done';

function baseName(path) {
    var trimmed = path.length > 1 ? path.replace(/\/+$/, "") : path;
    return trimmed.slice(trimmed.lastIndexOf("/") + 1);
}

function join(dir, name) {
    return dir === "/" ? "/" + name : dir + "/" + name;
}

function inside(path, dir) {
    return dir === "/" ? path !== "/" : path.indexOf(dir + "/") === 0;
}

function split(name, folder) {
    var dot = name.lastIndexOf(".");
    if (folder || dot <= 0 || dot === name.length - 1)
        return {stem: name, ext: ""};
    return {stem: name.slice(0, dot), ext: name.slice(dot)};
}

function numbered(name, folder, n) {
    var parts = split(name, folder);
    return parts.stem + " (" + n + ")" + parts.ext;
}

function items(paths, dir, cut) {
    var out = [];
    for (var i = 0; i < paths.length; i++) {
        var from = paths[i].length > 1 ? paths[i].replace(/\/+$/, "") : paths[i];
        var name = baseName(from);
        var to = join(dir, name);
        if (to === from && cut)
            continue;
        out.push({from: from, to: to, name: name, dir: dir, cut: cut, folder: false, taken: false, self: to === from, twin: -1, holds: inside(from, to), loop: inside(to, from)});
    }
    return out;
}

function loops(list) {
    return list.filter(function (item) {
        return item.loop;
    });
}

function placeable(list) {
    return list.filter(function (item) {
        return !item.loop;
    });
}

function loopRefusal(list) {
    return list.length === 1 ? list[0].name + " cannot go inside itself" : list.length + " folders cannot go inside themselves";
}

function probeCommand(list) {
    var args = ["sh", "-c", PROBE, "sh"];
    for (var i = 0; i < list.length; i++)
        args.push(list[i].to, list[i].from);
    return args;
}

function probed(list, text) {
    var marks = text.split("\n");
    var seen = [];
    return list.map(function (item, i) {
        var copy = Object.assign({}, item);
        var has = function (letter) {
            return marks.indexOf(letter + (i + 1)) >= 0;
        };
        copy.taken = has("t");
        copy.folder = has("d");
        copy.self = item.self || has("s");
        copy.holds = item.holds || has("h");
        copy.twin = seen.indexOf(item.to);
        seen.push(item.to);
        return copy;
    });
}

function asks(item) {
    return item.taken && !item.self && item.twin < 0;
}

function choices(list) {
    return list.map(function (item) {
        if (item.self)
            return item.cut ? "skip" : "both";
        if (item.twin >= 0)
            return "both";
        return item.taken ? null : "fresh";
    });
}

function settle(item, choice) {
    return choice === "replace" && item.holds ? "both" : choice;
}

function answer(list, chosen, at, choice, all) {
    return chosen.map(function (was, i) {
        if (i === at || (all && i > at && was === null && asks(list[i])))
            return settle(list[i], choice);
        return was;
    });
}

function next(chosen) {
    return chosen.indexOf(null);
}

function waiting(list, chosen) {
    var count = 0;
    for (var i = 0; i < chosen.length; i++)
        if (chosen[i] === null && asks(list[i]))
            count++;
    return count;
}

function operations(list, chosen) {
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var mode = list[i].twin >= 0 && chosen[list[i].twin] === "skip" ? "skip" : chosen[i];
        if (mode === "skip" || mode === null)
            continue;
        var parts = split(list[i].name, list[i].folder);
        out.push({mode: mode, from: list[i].from, to: list[i].to, name: list[i].name, folder: list[i].folder, dir: list[i].dir, stem: join(list[i].dir, parts.stem), ext: parts.ext});
    }
    return out;
}

function command(ops, cut) {
    var args = ["sh", "-c", PASTE, "sh", cut ? "mv" : "cp"];
    for (var i = 0; i < ops.length; i++)
        args.push(ops[i].mode, ops[i].from, ops[i].to, ops[i].stem, ops[i].ext);
    return args;
}

function results(ops, text) {
    var lines = text.split("\n").filter(function (line) {
        return line.trim() !== "";
    });
    var out = {pairs: [], replaced: [], done: [], gone: [], failed: [], half: [], kept: []};
    for (var i = 0; i < ops.length; i++) {
        var words = (lines[i] || "failed").trim().split(" ");
        var op = ops[i];
        var n = parseInt(words[1], 10) || 0;
        var to = n > 0 ? join(op.dir, numbered(op.name, op.folder, n)) : op.to;
        if (words[0] === "ok" || words[0] === "replaced") {
            out.pairs.push({from: op.from, to: to});
            out.done.push(op.from);
            if (n > 0)
                out.kept.push(baseName(to));
        }
        if (words[0] === "replaced" || words[0] === "half")
            out.replaced.push(op.to);
        if (words[0] === "half")
            out.half.push(op.name);
        if (words[0] === "gone")
            out.gone.push(op.from);
        if (words[0] !== "ok" && words[0] !== "replaced" && words[0] !== "gone")
            out.failed.push(op.name);
    }
    return out;
}

function leftover(clipboard, outcome) {
    return clipboard.filter(function (path) {
        var bare = path.length > 1 ? path.replace(/\/+$/, "") : path;
        return outcome.done.indexOf(bare) < 0 && outcome.gone.indexOf(bare) < 0;
    });
}

function reason(errors) {
    var lines = (errors || "").split("\n").filter(function (line) {
        return line.trim() !== "";
    });
    if (lines.length === 0)
        return "";
    var cut = lines[0].lastIndexOf(": ");
    return cut >= 0 ? lines[0].slice(cut + 2).trim() : "";
}

function failure(outcome, cut, total, errors) {
    var count = outcome.failed.length;
    if (count === 0)
        return "";
    var verb = cut ? "moved" : "copied";
    var why = reason(errors);
    var said = count === 1 ? outcome.failed[0] + " could not be " + verb : count + " of " + total + " could not be " + verb;
    if (why)
        said += ": " + why;
    if (outcome.half.length > 0)
        said += outcome.half.length === 1 && count === 1 ? ", the old one is in the trash" : ", the old ones are in the trash";
    return said;
}

function notice(outcome) {
    if (outcome.kept.length === 1)
        return "Kept both, the new one is " + outcome.kept[0];
    if (outcome.kept.length > 1)
        return "Kept both for " + outcome.kept.length + " files, the new ones are numbered";
    return "";
}

function renameRefusal(name, original, names) {
    if (name === original || names.indexOf(name) < 0)
        return "";
    return name + " is already here";
}
