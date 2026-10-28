.pragma library

var WORD = "delete";
var REST = "will be deleted and cannot be brought back.";
var EMPTY_WORD = "empty";

function named(item) {
    return item.origin ? item.name + " from " + item.origin : item.name;
}

function what(items) {
    if (items.length === 1)
        return named(items[0]);
    if (items.length === 2)
        return named(items[0]) + " and " + named(items[1]);
    return items[0].name + ", " + items[1].name + " and " + (items.length - 2) + " more";
}

function question(items) {
    return what(items) + " " + REST;
}

function approved(answer, paths) {
    return typeof answer === "string" && answer.trim().toLowerCase() === WORD ? paths.slice() : [];
}

function emptying(count, elsewhere, hidden) {
    var items = count === 1 ? "1 item" : count.toLocaleString() + " items";
    var also = [];
    if (hidden > 0)
        also.push(count === 1 ? "hidden" : hidden === count ? "all hidden" : hidden.toLocaleString() + " hidden");
    if (elsewhere > 0)
        also.push(count === 1 ? "from another drive" : elsewhere === count ? "all from other drives" : elsewhere === 1 ? "1 from another drive" : elsewhere.toLocaleString() + " from other drives");
    if (also.length === 0)
        return items + " " + REST;
    return items + ", " + also.join(" and ") + ", " + REST;
}

function emptied(answer, items) {
    return typeof answer === "string" && answer.trim().toLowerCase() === EMPTY_WORD ? items.slice() : [];
}
