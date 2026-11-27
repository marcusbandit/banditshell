.pragma library

function scrolls(item) {
    return item.contentY !== undefined && item.contentHeight !== undefined && item.interactive !== false && item.contentHeight + (item.topMargin || 0) + (item.bottomMargin || 0) > item.height + 0.5;
}

function scrollerAbove(item) {
    for (var p = item ? item.parent : null; p; p = p.parent)
        if (scrolls(p))
            return p;
    return null;
}

function passes(item, focused, held) {
    return !focused && !held && scrollerAbove(item) !== null;
}
