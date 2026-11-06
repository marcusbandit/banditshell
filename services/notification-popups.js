function fit(list, max, critical) {
    const items = list ?? [];
    const room = Math.max(0, max - items.filter(critical).length);
    let ordinary = 0;
    const shown = [];
    const dropped = [];
    for (const item of items)
        if (critical(item) || ordinary++ < room)
            shown.push(item);
        else
            dropped.push(item);
    return { shown, dropped };
}

function delivery(held, rule, silenced, covered) {
    const open = !held && !silenced;
    return {
        popup: open && !!rule?.pop && !covered,
        sound: open && !!rule?.snd,
        waiting: open && !!rule?.pop && !!covered
    };
}

function textChanged(before, after) {
    return before.summary !== after.summary || before.body !== after.body;
}
