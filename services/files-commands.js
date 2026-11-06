.pragma library

.import "quoting.js" as Quoting

const SIZE_UNITS = ["kB", "MB", "GB", "TB", "PB"];

function sizeDigits(value) {
    return value < 10 ? value.toFixed(1) : `${Math.round(value)}`;
}

function humanSize(bytes) {
    if (bytes < 1024)
        return `${bytes} B`;

    let step = 0;
    let value = bytes;
    while (value >= 1024 && step < SIZE_UNITS.length) {
        value /= 1024;
        step++;
    }
    if (Math.round(value) >= 1024 && step < SIZE_UNITS.length) {
        value /= 1024;
        step++;
    }

    return `${sizeDigits(value)} ${SIZE_UNITS[step - 1]}`;
}

function progressLine(title, copied, total) {
    if (!(total > 0))
        return `${title}, ${humanSize(copied)} so far`;
    const percent = Math.min(99, Math.floor(copied / total * 100));
    return `${title}, ${humanSize(copied)} of ${humanSize(total)} (${percent}%)`;
}

function join(dir, name) {
    return dir === "/" ? `/${name}` : `${dir}/${name}`;
}

function clearLine(shell) {
    return shell === "zsh" ? "\x1bq" : "\x05\x15";
}

function typed(shell, paths) {
    const out = [];
    for (const path of paths) {
        const quoted = Quoting.forShell(shell, path);
        if (quoted === null)
            return null;
        out.push(quoted);
    }
    return out;
}

function refusal(shell, path) {
    return `cannot type this path into ${shell || "the shell"}: ${Quoting.visible(path)}`;
}

function runPlan(shell, live, command) {
    const quoted = live ? typed(shell, command.paths) : null;
    if (quoted === null)
        return {mode: "spawn", argv: [...command.words, ...command.paths]};
    return {mode: "type", text: `${clearLine(shell)}${[...command.words, ...quoted].join(" ")}\r`};
}

function cdLine(shell, path) {
    const quoted = typed(shell, [path]);
    return quoted === null ? null : `${clearLine(shell)}cd ${quoted[0]}\r`;
}

function cdPlan(shell, running, busy, path) {
    if (!running)
        return {mode: "local"};
    const text = cdLine(shell, path);
    if (text === null)
        return {mode: "refuse", failure: refusal(shell, path)};
    if (busy)
        return {mode: "desync"};
    return {mode: "type", text: text};
}

function folderCommand(dir, name) {
    return {words: ["mkdir", "-p", "--"], paths: [join(dir, name)]};
}

function fileCommand(dir, name) {
    return {words: ["touch", "--"], paths: [join(dir, name)]};
}

function moveCommand(from, to) {
    return {words: ["mv", "-i", "--"], paths: [from, to]};
}

function trashCommand(paths) {
    return {words: ["gio", "trash", "--"], paths: paths};
}

function removeCommand(paths, infos) {
    return {words: ["rm", "-rf", "--"], paths: [...paths, ...infos]};
}

function leftChild(from, to) {
    var base = to === "/" ? "" : to;
    if (from.length <= base.length + 1 || from.indexOf(base + "/") !== 0)
        return "";
    return from.slice(base.length + 1).split("/")[0];
}

var TOTALS = 'printf "token %s\\n" "$2"; printf "size %s\\n" "$(du -s -b -- "$1/" 2>/dev/null | cut -f1)"; printf "items %s\\n" "$(ls -A -- "$1/" 2>/dev/null | wc -l)"';

function totalsCommand(path, token) {
    return ["sh", "-c", TOTALS, "sh", path, String(token)];
}

function totals(text) {
    var out = {token: "", bytes: null, items: null};
    var lines = String(text).split("\n");
    for (var i = 0; i < lines.length; i++) {
        var space = lines[i].indexOf(" ");
        if (space < 0)
            continue;
        var key = lines[i].slice(0, space);
        var value = lines[i].slice(space + 1);
        if (key === "token")
            out.token = value;
        else if (value !== "" && isFinite(Number(value)) && key === "size")
            out.bytes = Number(value);
        else if (value !== "" && isFinite(Number(value)) && key === "items")
            out.items = Number(value);
    }
    return out;
}

var OPENERS_QUERY = [
    'kind=$(xdg-mime query filetype "$1" 2>/dev/null)',
    'printf "%s\\n" "$kind"',
    '[ -n "$kind" ] || exit 0',
    'preferred=$(xdg-mime query default "$kind" 2>/dev/null)',
    'printf "%s\\n" "$preferred"',
    'dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"',
    '{ printf "%s\\n" "$preferred"; gio mime "$kind" 2>/dev/null | awk \'/^[ \\t]+[^ \\t]+\\.desktop$/ { gsub(/^[ \\t]+/, ""); print }\'; } | awk \'NF && !seen[$0]++\' | while IFS= read -r id; do',
    '  nested=$(printf "%s" "$id" | sed "s,-,/,")',
    '  IFS=:; for d in $dirs; do',
    '    f="$d/applications/$id"',
    '    [ -f "$f" ] || f="$d/applications/$nested"',
    '    [ -f "$f" ] || continue',
    '    [ "$id" = "$preferred" ] || ! grep -qi "^NoDisplay=true" "$f" || break',
    '    printf "%s\\t%s\\n" "$id" "$(grep -m1 "^Name=" "$f" | cut -d= -f2-)"',
    '    break',
    '  done',
    '  IFS=',
    'done'
].join("\n");

function openersCommand(path) {
    return ["sh", "-c", OPENERS_QUERY, "sh", path];
}

function desktopId(id) {
    return String(id || "").replace(/\.desktop$/, "");
}

function openers(answer) {
    var lines = String(answer).split("\n");
    var kind = lines[0].trim();
    var preferred = desktopId(lines[1] ? lines[1].trim() : "");
    if (!kind)
        return {kind: "", apps: []};

    var apps = [];
    var seen = {};
    for (var i = 2; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t");
        if (tab < 0)
            continue;
        var id = desktopId(lines[i].slice(0, tab));
        if (!id || seen[id])
            continue;
        seen[id] = true;
        apps.push({id: id, name: lines[i].slice(tab + 1).trim() || id});
    }
    apps.sort(function (a, b) {
        var first = (a.id === preferred ? 0 : 1) - (b.id === preferred ? 0 : 1);
        var left = a.name.toLowerCase();
        var right = b.name.toLowerCase();
        return first || (left < right ? -1 : left > right ? 1 : 0);
    });
    return {kind: kind, apps: apps};
}

function launchCommand(id, path) {
    return ["gtk-launch", desktopId(id), path];
}
