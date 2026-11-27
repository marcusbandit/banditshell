.pragma library

function placeOf(item) {
    var x = 0;
    var y = 0;
    var beneath = false;
    for (var p = item; p; p = p.parent) {
        x += p.x;
        y += p.y;
        if (p !== item && p.glassBeneath === true)
            beneath = true;
    }
    return { x: x, y: y, beneath: beneath };
}

function originOn(itemPlace, sourcePlace) {
    return { x: itemPlace.x - sourcePlace.x, y: itemPlace.y - sourcePlace.y };
}

function sourceIn(entries, win) {
    for (var i = 0; i < entries.length; i++)
        if (entries[i].window === win)
            return entries[i].source;
    return null;
}
