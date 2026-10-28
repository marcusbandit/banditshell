.pragma library

var SCRIPT = [
    'dir=$1; history=$2; purge=$3; shift 3',
    'if [ "$purge" = 1 ]; then rm -f -- "$history".damaged-*; fi',
    '[ -d "$dir" ] || exit 0',
    'keep=$(mktemp) || exit 0',
    "printf '%s\\n' \"$@\" > \"$keep\"",
    'newest=',
    'for b in "$history".damaged-*; do',
    '    [ -e "$b" ] || continue',
    '    if [ -z "$newest" ] || [ "$b" -nt "$newest" ]; then newest=$b; fi',
    'done',
    'if [ -n "$newest" ]; then set -- -newer "$newest"; else set --; fi',
    "find \"$dir\" -maxdepth 1 -type f \"$@\" -printf '%f\\n' 2>/dev/null \\",
    '    | grep -vxF -f "$keep" \\',
    '    | while IFS= read -r n; do rm -f -- "$dir/$n"; done',
    'rm -f "$keep"',
    'exit 0'
].join("\n");

function basename(p) {
    var s = String(p || "");
    var cut = s.lastIndexOf("/");
    return cut < 0 ? s : s.slice(cut + 1);
}

function wanted(entries) {
    var out = [];
    for (var i = 0; i < (entries || []).length; i++) {
        var e = entries[i];
        if (e && e.file)
            out.push(basename(e.file));
    }
    return out;
}

function command(blobs, history, entries, readable, purge) {
    if (!readable || !blobs || !history)
        return null;
    return ["sh", "-c", SCRIPT, "sh", blobs, history, purge ? "1" : "0"].concat(wanted(entries));
}
