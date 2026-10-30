.pragma library

function wholeCards(tops, limit, count) {
    let k = 1;
    while (k + 1 < tops.length && tops[k + 1] <= limit + 0.5)
        k++;
    return Math.max(0, Math.min(k, count));
}

function clippedEntries(groups, hidden) {
    let sum = 0;
    for (const group of groups) {
        const standing = group.entries.filter(e => !e.leaving);
        sum += hidden.includes(group.entries[0]) ? standing.length : standing.filter(e => hidden.includes(e)).length;
    }
    return sum;
}
