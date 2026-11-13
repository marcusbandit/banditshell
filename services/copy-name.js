.pragma library

function next(names, base) {
    var taken = {};
    for (var i = 0; i < (names || []).length; i++)
        taken[String(names[i] || "").toLowerCase()] = true;
    var out = base;
    for (var n = 2; taken[out.toLowerCase()]; n++)
        out = base + " " + n;
    return out;
}
