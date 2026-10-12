.pragma library

var BREAK = "​";

function inert(text) {
    return text.replace(/<(?=[A-Za-z!?\/])/g, "<" + BREAK).replace(/!\[/g, "!" + BREAK + "[");
}
