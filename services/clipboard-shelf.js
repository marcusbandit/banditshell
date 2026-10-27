.pragma library

function identity(e) {
    if (e.file)
        return "file:" + e.file;
    if ((e.paths || []).length)
        return "paths:" + e.paths.join("\u0000");
    return "text:" + (e.text || "");
}

function shelve(entries) {
    var all = entries || [];
    return {
        before: all.map(function (e) {
            return {
                id: e.id,
                recorded: e.recorded
            };
        }),
        entries: all.filter(function (e) {
            return !e.pinned;
        })
    };
}

function kept(entries) {
    return (entries || []).filter(function (e) {
        return e.pinned;
    });
}

function restored(current, shelf) {
    var at = {};
    shelf.before.forEach(function (b, i) {
        at[b.id] = {
            index: i,
            recorded: b.recorded
        };
    });
    var taken = {};
    var fresh = [];
    var old = [];
    current.forEach(function (e) {
        taken[identity(e)] = true;
        var was = at[e.id];
        if (was && was.recorded === e.recorded)
            old.push(e);
        else
            fresh.push(e);
    });
    shelf.entries.forEach(function (e) {
        var key = identity(e);
        if (at[e.id] && !taken[key]) {
            taken[key] = true;
            old.push(e);
        }
    });
    old.sort(function (a, b) {
        return at[a.id].index - at[b.id].index;
    });
    return fresh.concat(old);
}

function salvage(text) {
    var s = String(text || "");
    var key = s.indexOf('"entries"');
    var open = key < 0 ? -1 : s.indexOf("[", key);
    if (open < 0)
        return [];
    var found = [];
    var depth = 0;
    var start = -1;
    var quoted = false;
    var escaped = false;
    for (var i = open + 1; i < s.length; i++) {
        var c = s[i];
        if (quoted) {
            if (escaped)
                escaped = false;
            else if (c === "\\")
                escaped = true;
            else if (c === '"')
                quoted = false;
            continue;
        }
        if (c === '"') {
            quoted = true;
        } else if (c === "{") {
            if (depth === 0)
                start = i;
            depth++;
        } else if (c === "}") {
            depth--;
            if (depth < 0)
                break;
            if (depth === 0 && start >= 0) {
                try {
                    var e = JSON.parse(s.slice(start, i + 1));
                    if (e && typeof e === "object" && !Array.isArray(e))
                        found.push(e);
                } catch (err) {}
                start = -1;
            }
        } else if (c === "]" && depth === 0) {
            break;
        }
    }
    return found;
}

function survivors(current, salvaged) {
    var taken = {};
    var out = (current || []).slice();
    out.forEach(function (e) {
        taken[identity(e)] = true;
    });
    (salvaged || []).forEach(function (e) {
        if (!e.pinned || !(e.text || e.file || (e.paths || []).length))
            return;
        var key = identity(e);
        if (taken[key])
            return;
        taken[key] = true;
        out.push(e);
    });
    return out;
}
