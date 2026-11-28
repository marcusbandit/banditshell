.pragma library

function clampRect(x, y, w, h, width, height) {
    var left = Math.max(0, Math.min(width, x));
    var top = Math.max(0, Math.min(height, y));
    var right = Math.max(left, Math.min(width, x + w));
    var bottom = Math.max(top, Math.min(height, y + h));
    return { x: left, y: top, width: right - left, height: bottom - top };
}

function span(fromX, fromY, toX, toY, width, height) {
    var x = Math.max(0, Math.min(width, toX));
    var y = Math.max(0, Math.min(height, toY));
    return { x: Math.min(fromX, x), y: Math.min(fromY, y), width: Math.abs(x - fromX), height: Math.abs(y - fromY) };
}

function readoutAt(sel, w, h, width, height, gap) {
    var x = Math.max(gap, Math.min(width - w - gap, sel.x + sel.width / 2 - w / 2));
    var below = sel.y + sel.height + gap;
    var above = sel.y - h - gap;
    var y;
    if (below + h <= height - gap)
        y = below;
    else if (above >= gap)
        y = above;
    else
        y = sel.y + sel.height - h - gap * 2;
    return { x: x, y: Math.max(gap, Math.min(height - h - gap, y)) };
}
