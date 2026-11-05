.pragma library

var SAFE_FILE_NAME = /^[a-z0-9_-]+$/;

function nameTaken(layouts, name, previous) {
    return layouts.some(function (layout) {
        return layout.name !== previous && layout.name === name;
    });
}

function isRename(previous, name) {
    return !!previous && previous !== name;
}

function renamedInUse(previous, name, current) {
    return isRename(previous, name) && current === "lua:" + previous;
}

function placed(layouts, model, previous) {
    var next = layouts.filter(function (layout) {
        return layout.name !== previous && layout.name !== model.name;
    });
    var at = layouts.findIndex(function (layout) {
        return layout.name === (previous || model.name);
    });
    next.splice(at < 0 ? next.length : Math.min(at, next.length), 0, model);
    return next;
}

function without(layouts, name) {
    return layouts.filter(function (layout) {
        return layout.name !== name;
    });
}

function removeCommand(folder, names) {
    var safe = names.filter(function (name) {
        return SAFE_FILE_NAME.test(name);
    });
    return ["sh", "-c", 'cd -- "$1" 2>/dev/null || exit 0; shift; for name in "$@"; do rm -f -- "$name.lua"; done', "sh", folder].concat(safe);
}

function writeCommand(folder, files, code) {
    var pairs = [];
    files.forEach(function (file) {
        pairs.push(file.name, file.text);
    });
    return ["sh", "-c", 'exec 2>&1; dir=$1; code=$2; shift 2; mkdir -p -- "$dir" || exit 1; while [ $# -gt 1 ]; do printf %s "$2" > "$dir/$1.lua.part" && mv -f -- "$dir/$1.lua.part" "$dir/$1.lua" || exit 1; shift 2; done; [ -n "$code" ] || exit 0; command -v hyprctl > /dev/null || { echo "hyprctl is not installed"; exit 3; }; exec hyprctl eval "$code"', "sh", folder, code].concat(pairs);
}

function outcome(input) {
    var text = String(input.output || "").trim();
    var evalError = text.indexOf("error:") === 0;
    var answered = input.possible && (text === "ok" || evalError);
    var broken = evalError && !input.named.length ? input.names : input.named;
    var ready = Object.assign({}, input.ready);
    input.names.forEach(function (name) {
        ready[name] = answered && broken.indexOf(name) < 0;
    });
    var failed = input.possible ? text !== "ok" : input.code !== 0;
    var trouble = text.replace(/^error:\s*/, "") || "could not write " + input.folder;
    var said;
    if (failed)
        said = trouble;
    else if (!input.possible)
        said = "saved · loading needs Hyprland with a Lua config";
    else
        said = input.names.length === 1 ? "lua:" + input.names[0] + " is loaded" : input.names.length + " layouts loaded";
    return { ready: ready, failed: failed, said: said };
}
