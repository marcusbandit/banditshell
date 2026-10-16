.pragma library

var SHELVES = [
    {
        key: "screenshots",
        title: "Screenshots",
        icon: "screenshot_monitor",
        pictures: true,
        ask: /^(?:screenshots?|screen shots?|recent screenshots?|last screenshot)(?:\s+(.*))?$/i
    },
    {
        key: "downloads",
        title: "Downloads",
        icon: "download",
        pictures: false,
        ask: /^(?:download|(?:downloads|recent downloads?|last download|downloaded)(?:\s+(.*))?)$/i
    }
];

var PARTIAL = /\.(?:part|crdownload|download|partial|tmp|filepart|opdownload|aria2|!qb)$/i;

function ask(text) {
    var t = String(text || "").trim();
    for (var i = 0; i < SHELVES.length; i++) {
        var m = SHELVES[i].ask.exec(t);
        if (m)
            return {
                shelf: SHELVES[i],
                words: String(m[1] || "").trim().toLowerCase()
            };
    }
    return null;
}

function readListing(text) {
    var out = [];
    var lines = String(text || "").split("\n");
    for (var i = 0; i < lines.length; i++) {
        var parts = lines[i].split("\t");
        if (parts.length < 3 || !parts[2])
            continue;
        var path = parts[2];
        var name = path.slice(path.lastIndexOf("/") + 1);
        if (name.charAt(0) === "." || PARTIAL.test(name))
            continue;
        out.push({
            path: path,
            name: name,
            dir: parts[1] === "d",
            modified: Math.round((Number(parts[0]) || 0) * 1000)
        });
    }
    return out;
}

function matching(files, words, limit) {
    var want = String(words || "").toLowerCase();
    var out = [];
    for (var i = 0; i < files.length && out.length < limit; i++)
        if (!want || files[i].name.toLowerCase().indexOf(want) >= 0)
            out.push(files[i]);
    return out;
}
