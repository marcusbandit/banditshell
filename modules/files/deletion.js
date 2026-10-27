.pragma library

var WORD = "delete";
var REST = "will be deleted and cannot be brought back.";

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
