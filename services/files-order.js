.pragma library

const SORTS = ["name", "size", "mtime", "kind"];
const NATURAL = {numeric: true, sensitivity: "base"};

const SORT_WORDS = { name: "name", mtime: "date", size: "size", kind: "type" };

const ORDER_WORDS = {
    name: ["a to z", "z to a"],
    mtime: ["newest", "oldest"],
    size: ["biggest", "smallest"],
    kind: ["a to z", "z to a"]
};

function foldersNote(key) {
    return key === "size" ? "folders by name" : "folders on top";
}

function orderWords(key) {
    return ORDER_WORDS[key] ?? ORDER_WORDS.name;
}

function merged(list, before) {
    let from = list.slice();
    let to = new Array(from.length);
    for (let width = 1; width < from.length; width *= 2) {
        for (let lo = 0; lo < from.length; lo += 2 * width) {
            const mid = Math.min(lo + width, from.length);
            const hi = Math.min(lo + 2 * width, from.length);
            let i = lo, j = mid, k = lo;
            while (i < mid && j < hi)
                to[k++] = before(from[j], from[i]) < 0 ? from[j++] : from[i++];
            while (i < mid)
                to[k++] = from[i++];
            while (j < hi)
                to[k++] = from[j++];
        }
        [from, to] = [to, from];
    }
    return from;
}

function trashOrder(key, reversed) {
    return key === "size" || key === "kind" ? {key: key, reversed: reversed} : {key: "trashed", reversed: key === "mtime" && reversed};
}

function ordered(entries, key, reversed) {
    const sign = reversed ? -1 : 1;
    const byName = (a, b) => a.name.localeCompare(b.name, undefined, NATURAL);
    const primary = {
        size: (a, b) => b.size - a.size,
        mtime: (a, b) => b.mtime - a.mtime,
        trashed: (a, b) => b.trashed - a.trashed,
        kind: (a, b) => a.class < b.class ? -1 : a.class > b.class ? 1 : 0
    }[key] ?? byName;
    return merged(entries, (a, b) => {
        if (key !== "trashed" && (a.kind === "dir") !== (b.kind === "dir"))
            return a.kind === "dir" ? -1 : 1;
        return sign * primary(a, b) || byName(a, b);
    });
}

const HEADER_LABELS = { name: "Name", kind: "Type", size: "Size", mtime: "Modified", trashed: "Trashed" };

function headers(key, reversed, trash) {
    const how = trash ? trashOrder(key, reversed) : {key: SORTS.indexOf(key) >= 0 ? key : "name", reversed: reversed};
    const dated = trash ? "trashed" : "mtime";
    return ["name", "kind", "size", dated].map(id => {
        const active = how.key === id;
        const words = id === "trashed" ? ORDER_WORDS.mtime : orderWords(id);
        return {
            id: id,
            label: HEADER_LABELS[id],
            active: active,
            words: active ? words[how.reversed ? 1 : 0] : "",
            sortable: !(trash && id === "name")
        };
    });
}

function chosen(id, key, reversed, trash) {
    const sort = id === "trashed" ? "mtime" : id;
    const now = headers(key, reversed, trash).find(h => h.id === id);
    if (!now || !now.sortable)
        return {sort: key, reversed: reversed};
    if (!now.active)
        return {sort: sort, reversed: false};
    const how = trash ? trashOrder(key, reversed) : {reversed: reversed};
    return {sort: sort, reversed: !how.reversed};
}
