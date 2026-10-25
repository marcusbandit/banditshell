.pragma library

var SCRIPT = [
    'dir=$1; shift',
    '[ -d "$dir" ] || exit 0',
    'keep=$(mktemp) || exit 0',
    "printf '%s\\n' \"$@\" > \"$keep\"",
    "find \"$dir\" -maxdepth 1 -type f -printf '%f\\n' 2>/dev/null \\",
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

function command(blobs, entries, readable) {
    if (!readable || !blobs)
        return null;
    return ["sh", "-c", SCRIPT, "sh", blobs].concat(wanted(entries));
}
