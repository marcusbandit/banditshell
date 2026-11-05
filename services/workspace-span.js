.pragma library

function span(persistent, first, ceiling, busyIds, activeId) {
    var last = first + persistent - 1;
    var top = Math.min(ceiling, Math.max(first + persistent - 1, first + 9));
    var all = busyIds.concat([activeId]);
    for (var i = 0; i < all.length; i++) {
        var id = all[i];
        if (id >= first && id <= top && id > last)
            last = id;
    }
    return last - first + 1;
}
