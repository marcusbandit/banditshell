.pragma library

var NOTE_EXTENSION = /\.md$/i;

var FORBIDDEN = /[\\/:*?"<>|#^\[\]]+/g;

var SPACES = /\s+/g;

var LEADING_DOTS = /^\.+/;

var CREATE = /^note\s+(.+)$/i;

var SEARCH = /^(?:notes|obsidian|vault)(?:\s+(.*))?$/i;

function baseName(path) {
    var s = String(path || "").replace(/\/+$/, "");
    return s.slice(s.lastIndexOf("/") + 1);
}

function registered(text) {
    var parsed = null;
    try {
        parsed = JSON.parse(text);
    } catch (e) {
        return [];
    }
    var vaults = parsed && typeof parsed.vaults === "object" && parsed.vaults ? parsed.vaults : {};
    return Object.keys(vaults).map(id => vaults[id]).filter(v => v && typeof v.path === "string" && v.path).map(v => ({
                path: v.path.replace(/(.)\/+$/, "$1"),
                ts: Number(v.ts) || 0,
                open: !!v.open,
                registered: true
            }));
}

function vaultsFrom(registries, found) {
    var byPath = {};
    var out = [];
    var add = v => {
        var known = byPath[v.path];
        if (known) {
            known.ts = Math.max(known.ts, v.ts || 0);
            known.open = known.open || !!v.open;
            known.registered = known.registered || !!v.registered;
            return;
        }
        var vault = {
            path: v.path,
            name: baseName(v.path),
            ts: v.ts || 0,
            open: !!v.open,
            registered: !!v.registered
        };
        byPath[v.path] = vault;
        out.push(vault);
    };
    (registries || []).forEach(text => registered(text).forEach(add));
    String(found || "").split("\n").map(l => l.trim().replace(/\/\.obsidian\/?$/, "")).filter(Boolean).forEach(path => add({
            path: path
        }));
    return out.sort((a, b) => (b.open ? 1 : 0) - (a.open ? 1 : 0) || b.ts - a.ts || (a.name < b.name ? -1 : a.name > b.name ? 1 : 0));
}

function defaultVault(vaults, chosen) {
    var want = String(chosen || "").trim();
    if (want) {
        var hit = vaults.find(v => v.path === want || v.name === want);
        if (hit)
            return hit;
    }
    return vaults[0] || null;
}

function vaultOf(vaults, path) {
    var best = null;
    for (var i = 0; i < vaults.length; i++) {
        var v = vaults[i];
        if (path.indexOf(`${v.path}/`) === 0 && (!best || v.path.length > best.path.length))
            best = v;
    }
    return best;
}

function readIndex(text, vaults) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i];
        var tab = line.indexOf("\t");
        if (tab < 0)
            continue;
        var path = line.slice(tab + 1);
        if (!NOTE_EXTENSION.test(path))
            continue;
        var vault = vaultOf(vaults, path);
        if (!vault)
            continue;
        var relative = path.slice(vault.path.length + 1).replace(NOTE_EXTENSION, "");
        out.push({
            path: path,
            vault: vault.path,
            vaultName: vault.name,
            name: baseName(relative),
            lower: baseName(relative).toLowerCase(),
            relative: relative,
            modified: (Number(line.slice(0, tab)) || 0) * 1000
        });
    }
    return out;
}

function search(notes, text, place, limit) {
    var want = String(text || "").trim().toLowerCase();
    var hits = [];
    for (var i = 0; i < notes.length; i++) {
        var n = notes[i];
        if (want && n.lower.indexOf(want) < 0)
            continue;
        hits.push({
            note: n,
            score: want ? place(n.lower, want) : 1
        });
    }
    hits.sort((a, b) => b.score - a.score || b.note.modified - a.note.modified);
    return hits.slice(0, limit || 8);
}

function openUri(vaultName, relative) {
    return `obsidian://open?vault=${encodeURIComponent(vaultName)}&file=${encodeURIComponent(relative)}`;
}

function newUri(vaultName, name) {
    return `obsidian://new?vault=${encodeURIComponent(vaultName)}&name=${encodeURIComponent(name)}`;
}

function fileNameFor(title) {
    return String(title || "").replace(FORBIDDEN, " ").replace(SPACES, " ").trim().replace(LEADING_DOTS, "");
}

function notesAsk(text) {
    var t = String(text || "").trim();
    var m = CREATE.exec(t);
    if (m)
        return {
            create: fileNameFor(m[1]),
            text: m[1].trim()
        };
    m = SEARCH.exec(t);
    return m ? {
        create: "",
        text: (m[1] || "").trim()
    } : null;
}

var INDEX = `max=$1; shift
if command -v fd >/dev/null 2>&1; then
    fd --type f --extension md --max-results "$max" --absolute-path --print0 . "$@" 2>/dev/null | xargs -0 -r stat --printf '%Y\\t%n\\n' 2>/dev/null
else
    find "$@" -name '.*' -prune -o -type f -name '*.md' -printf '%T@\\t%p\\n' 2>/dev/null | head -n "$max"
fi`;

function indexCommand(vaults, limit) {
    return ["nice", "-n", "10", "sh", "-c", INDEX, "sh", String(limit)].concat(vaults.map(v => v.path));
}

function findCommand(roots) {
    return ["sh", "-c", 'for r in "$@"; do for d in "$r"/*/.obsidian; do [ -d "$d" ] && printf "%s\\n" "$d"; done; done', "sh"].concat(roots);
}
