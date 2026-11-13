.pragma library

function recent(used, byChar, limit) {
    return Object.keys(used || {}).sort(function (a, b) {
        return (used[b].last || 0) - (used[a].last || 0);
    }).map(function (c) {
        return byChar[c];
    }).filter(Boolean).slice(0, limit);
}

function pinned(list, byChar) {
    return (list || []).map(function (c) {
        return byChar[c];
    }).filter(Boolean);
}

function sections(all, groups, group, found, recents, pins) {
    if (found) {
        var kept = group ? found.filter(function (e) {
            return e.group === group;
        }) : found;
        return [
            {
                title: kept.length === 1 ? "1 match" : kept.length + " matches",
                items: kept
            }
        ];
    }
    var out = [];
    if (!group && pins && pins.length)
        out.push({
            title: "Pinned",
            items: pins
        });
    if (!group && recents.length)
        out.push({
            title: "Recently used",
            items: recents
        });
    var by = {};
    for (var i = 0; i < all.length; i++) {
        var g = all[i].group;
        if (!by[g])
            by[g] = [];
        by[g].push(all[i]);
    }
    for (var j = 0; j < groups.length; j++)
        if (by[groups[j]] && (!group || group === groups[j]))
            out.push({
                title: groups[j],
                items: by[groups[j]]
            });
    return out;
}

function layout(parts, columns) {
    var rows = [];
    var items = [];
    var across = Math.max(1, columns);
    for (var i = 0; i < parts.length; i++) {
        if (!parts[i].items.length)
            continue;
        rows.push({
            header: true,
            title: parts[i].title
        });
        for (var at = 0; at < parts[i].items.length; at += across) {
            var cells = parts[i].items.slice(at, at + across);
            rows.push({
                start: items.length,
                cells: cells
            });
            items = items.concat(cells);
        }
    }
    return {
        rows: rows,
        items: items
    };
}

function rowOf(rows, index) {
    for (var i = 0; i < rows.length; i++)
        if (!rows[i].header && index >= rows[i].start && index < rows[i].start + rows[i].cells.length)
            return i;
    return -1;
}

function columnOf(rows, index) {
    var at = rowOf(rows, index);
    return at < 0 ? -1 : index - rows[at].start;
}

function step(rows, count, index, dx, dy, goal) {
    if (count <= 0)
        return -1;
    if (index < 0)
        return 0;
    if (dx)
        return Math.max(0, Math.min(count - 1, index + dx));
    var at = rowOf(rows, index);
    if (at < 0)
        return 0;
    var column = goal >= 0 ? goal : index - rows[at].start;
    var target = at;
    var moved = 0;
    var way = dy > 0 ? 1 : -1;
    while (moved < Math.abs(dy)) {
        var next = target + way;
        while (next >= 0 && next < rows.length && rows[next].header)
            next += way;
        if (next < 0 || next >= rows.length)
            break;
        target = next;
        moved++;
    }
    if (target === at)
        return dy > 0 ? count - 1 : 0;
    return rows[target].start + Math.min(column, rows[target].cells.length - 1);
}
