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

function emptyLine(item) {
    var line = item.name;
    if (item.origin)
        line += " from " + item.origin;
    if (item.drive)
        line += " on " + item.drive;
    if (item.hidden)
        line += ", hidden";
    return line;
}

function emptyList(items, most) {
    var shown = items.length > most + 1 ? most : items.length;
    var lines = [];
    for (var i = 0; i < shown; i++)
        lines.push(emptyLine(items[i]));
    if (shown < items.length)
        lines.push("and " + (items.length - shown).toLocaleString() + " more");
    return lines;
}

function emptying(count, size) {
    var items = count === 1 ? "1 item" : count.toLocaleString() + " items";
    return size ? items + ", " + size + " in all, " + REST : items + " " + REST;
}

function emptied(answer, items) {
    return typeof answer === "string" && answer.trim().toLowerCase() === EMPTY_WORD ? items.slice() : [];
}
