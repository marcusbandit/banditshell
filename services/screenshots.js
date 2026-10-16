.pragma library

var ASK = /^(?:screenshots?|screen shots?|recent screenshots?|last screenshot)(?:\s+(.*))?$/i;

function ask(text) {
    var m = ASK.exec(String(text || "").trim());
    return m ? String(m[1] || "").trim().toLowerCase() : null;
}

function readListing(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var tab = lines[i].indexOf("\t");
        if (tab < 0)
            continue;
        var path = lines[i].slice(tab + 1);
        if (!path)
            continue;
        out.push({
            path: path,
            name: path.slice(path.lastIndexOf("/") + 1),
            modified: Math.round((Number(lines[i].slice(0, tab)) || 0) * 1000)
        });
    }
    return out;
}

function matching(shots, words, limit) {
    var want = String(words || "").toLowerCase();
    var out = [];
    for (var i = 0; i < shots.length && out.length < limit; i++)
        if (!want || shots[i].name.toLowerCase().indexOf(want) >= 0)
            out.push(shots[i]);
    return out;
}
