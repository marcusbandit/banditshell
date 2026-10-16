.pragma library

var TERMINAL_EDITORS = ["vi", "vim", "nvim", "nano", "hx", "helix", "micro", "kak", "ne", "joe", "mg", "mcedit", "vis", "amp", "emacsclient -t", "emacs -nw"];

var GUI_EDITORS = ["code", "codium", "zed", "zeditor", "subl", "cursor"];

var FALLBACK_TERMINAL_EDITORS = ["nvim", "vim", "nano"];

var ASK = /^(?:projects?|repos?|repositories)(?:\s+(.*))?$/i;

function expand(path, home) {
    var p = String(path || "").trim();
    if (p === "~")
        return home;
    if (p.indexOf("~/") === 0)
        return `${home}${p.slice(1)}`;
    return p;
}

function listFrom(text, home) {
    var seen = {};
    return String(text || "").split(/[,\n]/).map(p => expand(p, home).replace(/(.)\/+$/, "$1")).filter(p => {
        if (!p || seen[p])
            return false;
        seen[p] = true;
        return true;
    });
}

function namesFrom(text) {
    return String(text || "").split(/[,\n]/).map(n => n.trim()).filter(Boolean);
}

function baseName(path) {
    var s = String(path || "").replace(/\/+$/, "");
    return s.slice(s.lastIndexOf("/") + 1);
}

var SCAN = `depth=$1; skips=$2; shift 2
tab=$(printf '\\t')
git=0; command -v git >/dev/null 2>&1 && git=1
prune=""
for s in $skips; do prune="$prune -o -name $s"; done
for root in "$@"; do
    [ -d "$root" ] || continue
    find -H "$root" -mindepth 1 -maxdepth $((depth + 1)) \\( -name .git -print -prune \\) -o \\( \\( -name '.*' $prune \\) -prune \\) 2>/dev/null
done | while IFS= read -r dot; do
    repo=\${dot%/.git}
    line=""
    [ "$git" = 1 ] && line=$(git -C "$repo" log -1 --format='%ct%x09%D' 2>/dev/null)
    case $line in
    *"$tab"*) ;;
    *) line="0$tab" ;;
    esac
    printf '%s\\t%s\\n' "$line" "$repo"
done`;

function scanCommand(roots, depth, skips) {
    var safe = namesFrom(skips).filter(n => /^[A-Za-z0-9._-]+$/.test(n)).join(" ");
    return ["nice", "-n", "10", "sh", "-c", SCAN, "sh", String(Math.max(1, Math.min(6, Math.round(depth) || 2))), safe].concat(roots);
}

function branchOf(refs) {
    var m = /HEAD -> ([^,]+)/.exec(String(refs || ""));
    return m ? m[1].trim() : "";
}

function readScan(text) {
    var seen = {};
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t");
        if (parts.length < 3)
            continue;
        var path = parts.slice(2).join("\t");
        if (!path || seen[path])
            continue;
        seen[path] = true;
        out.push({
            path: path,
            name: baseName(path),
            committed: (Number(parts[0]) || 0) * 1000,
            branch: branchOf(parts[1])
        });
    }
    return out;
}

function lastTouched(project, opened) {
    return Math.max(project.committed || 0, (opened && opened[project.path]) || 0);
}

function rank(projects, opened, text, place, limit) {
    var want = String(text || "").trim();
    var scored = [];
    for (var i = 0; i < projects.length; i++) {
        var p = projects[i];
        var score = want ? place(p.name, want) : 1;
        if (score <= 0)
            continue;
        scored.push({
            project: p,
            score: score,
            last: lastTouched(p, opened)
        });
    }
    scored.sort((a, b) => b.score - a.score || b.last - a.last);
    return limit ? scored.slice(0, limit) : scored;
}

function ago(when, now) {
    if (!when)
        return "";
    var minutes = Math.max(0, Math.floor((now - when) / 60000));
    if (minutes < 1)
        return "just now";
    if (minutes < 60)
        return `${minutes} min ago`;
    var hours = Math.round(minutes / 60);
    if (hours < 24)
        return `${hours} h ago`;
    var days = Math.round(hours / 24);
    if (days === 1)
        return "yesterday";
    if (days < 14)
        return `${days} days ago`;
    if (days < 60)
        return `${Math.round(days / 7)} weeks ago`;
    if (days < 730)
        return `${Math.round(days / 30)} months ago`;
    return `${Math.round(days / 365)} years ago`;
}

function words(command) {
    return String(command || "").trim().split(/\s+/).filter(Boolean);
}

function inTerminal(command) {
    var w = words(command);
    if (!w.length)
        return false;
    var name = baseName(w[0]);
    var joined = [name].concat(w.slice(1)).join(" ");
    return TERMINAL_EDITORS.some(t => t === name || joined === t || joined.indexOf(`${t} `) === 0);
}

function editorFor(visual, editor, found) {
    var chosen = [visual, editor].map(c => String(c || "").trim()).find(Boolean);
    if (chosen)
        return {
            command: words(chosen),
            terminal: inTerminal(chosen),
            name: baseName(words(chosen)[0])
        };
    var gui = GUI_EDITORS.find(e => found.indexOf(e) >= 0);
    if (gui)
        return {
            command: [gui],
            terminal: false,
            name: gui
        };
    var term = FALLBACK_TERMINAL_EDITORS.find(e => found.indexOf(e) >= 0);
    if (term)
        return {
            command: [term],
            terminal: true,
            name: term
        };
    return null;
}

function ambientScore(place) {
    return place >= 2 ? 0.25 + place * 0.05 : 0;
}

function quote(text) {
    return "'" + String(text).replace(/'/g, "'\\''") + "'";
}

function terminalLine(folder, command, target) {
    return `cd ${quote(folder)} && exec ${command.map(quote).join(" ")} ${target ? quote(target) : "."}`;
}

function shellLine(folder) {
    return `cd ${quote(folder)} && exec "\${SHELL:-sh}"`;
}

function projectAsk(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? {
        text: (m[1] || "").trim()
    } : null;
}

function parentWithin(roots, path) {
    var root = (roots || []).filter(r => path.indexOf(`${r}/`) === 0).sort((a, b) => b.length - a.length)[0];
    if (!root)
        return "";
    var inside = path.slice(root.length + 1);
    var cut = inside.lastIndexOf("/");
    return cut > 0 ? inside.slice(0, cut) : "";
}
