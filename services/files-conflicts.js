.pragma library

var PROBE = 'n=$1; shift; i=0; '
    + 'for p; do i=$((i+1)); '
    + 'if [ "$i" -le "$n" ]; then if [ -e "$p" ] || [ -L "$p" ]; then echo "t$i"; fi; '
    + 'elif [ -d "$p" ] && [ ! -L "$p" ]; then echo "d$((i-n))"; fi; done';

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
    + 'elif [ "$said" = replaced ]; then echo half; else echo failed; fi; done';

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
        out.push({from: from, to: to, name: name, dir: dir, folder: false, taken: false, self: to === from, twin: false, holds: inside(from, to)});
    }
    return out;
}

function probeCommand(list) {
    return ["sh", "-c", PROBE, "sh", String(list.length)].concat(list.map(function (item) {
        return item.to;
    }), list.map(function (item) {
        return item.from;
    }));
}

function probed(list, text) {
    var marks = text.split("\n");
    var seen = [];
    return list.map(function (item, i) {
        var copy = Object.assign({}, item);
        copy.taken = marks.indexOf("t" + (i + 1)) >= 0;
        copy.folder = marks.indexOf("d" + (i + 1)) >= 0;
        copy.twin = seen.indexOf(item.to) >= 0;
        seen.push(item.to);
        return copy;
    });
}

function asks(item) {
    return item.taken && !item.self && !item.twin;
}

function choices(list) {
    return list.map(function (item) {
        if (item.self || item.twin)
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
        if (chosen[i] === "skip" || chosen[i] === null)
            continue;
        var parts = split(list[i].name, list[i].folder);
        out.push({mode: chosen[i], from: list[i].from, to: list[i].to, name: list[i].name, folder: list[i].folder, stem: join(list[i].dir, parts.stem), ext: parts.ext});
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
    var out = {pairs: [], replaced: [], done: [], gone: [], failed: [], kept: []};
    for (var i = 0; i < ops.length; i++) {
        var words = (lines[i] || "failed").trim().split(" ");
        var op = ops[i];
        var n = parseInt(words[1], 10) || 0;
        var to = n > 0 ? op.stem + " (" + n + ")" + op.ext : op.to;
        if (words[0] === "ok" || words[0] === "replaced") {
            out.pairs.push({from: op.from, to: to});
            out.done.push(op.from);
            if (n > 0)
                out.kept.push(baseName(to));
        }
        if (words[0] === "replaced" || words[0] === "half")
            out.replaced.push(op.to);
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

function failure(outcome, cut, total) {
    var count = outcome.failed.length;
    if (count === 0)
        return "";
    var verb = cut ? "moved" : "copied";
    return count === 1 ? outcome.failed[0] + " could not be " + verb : count + " of " + total + " could not be " + verb;
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
