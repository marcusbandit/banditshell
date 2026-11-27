.pragma library

function placeOf(item) {
    var x = 0;
    var y = 0;
    var scale = 1;
    var beneath = false;
    for (var p = item; p; p = p.parent) {
        x += p.x;
        y += p.y;
        scale *= p.scale === undefined ? 1 : p.scale;
        if (p !== item && p.glassBeneath === true)
            beneath = true;
    }
    return { x: x, y: y, scale: scale, beneath: beneath };
}

function sourceIn(entries, win) {
    for (var i = 0; i < entries.length; i++)
        if (entries[i].window === win)
            return entries[i].source;
    return null;
}
