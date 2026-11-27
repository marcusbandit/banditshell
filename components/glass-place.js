.pragma library

function windowOffset(win, ignoreMode) {
    if (!win || !win.anchors || !win.margins || !win.screen || win.exclusionMode !== ignoreMode)
        return null;
    var a = win.anchors;
    var m = win.margins;
    var x = a.left ? m.left : a.right ? win.screen.width - win.width - m.right : (win.screen.width - win.width) / 2;
    var y = a.top ? m.top : a.bottom ? win.screen.height - win.height - m.bottom : (win.screen.height - win.height) / 2;
    return { x: x, y: y };
}

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

function originOn(itemWindow, itemPlace, sourceWindow, sourcePlace) {
    if (!itemWindow || !itemPlace || !sourceWindow || !sourcePlace)
        return null;
    return {
        x: itemWindow.x + itemPlace.x - sourceWindow.x - sourcePlace.x,
        y: itemWindow.y + itemPlace.y - sourceWindow.y - sourcePlace.y
    };
}
