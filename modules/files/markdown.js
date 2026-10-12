.pragma library

var BREAK = "​";

function inert(text) {
    return text.replace(/<(?=[A-Za-z!?\/])/g, "<" + BREAK).replace(/!\[/g, "!" + BREAK + "[");
}

var CONTAINER = /^((?: {0,3}(?:>[ \t]?|(?:[-+*]|\d{1,9}[.)])(?:[ \t]|$)))*)(.*)$/;
var ATX = /^( {0,3})#{1,6}(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$/;
var UNDERLINE = /^( {0,3})(?:=+|-+)[ \t]*$/;
var FENCE = /^ {0,3}(`{3,}|~{3,})/;
var RULE = /^ {0,3}([-*_])(?:[ \t]*\1){2,}[ \t]*$/;
var INDENTED = /^(?: {4}|\t)/;

function split(line) {
    const parts = CONTAINER.exec(line);
    return {prefix: parts[1], content: parts[2]};
}

function blank(line) {
    return split(line).content.trim() === "";
}

function closes(fence, line) {
    const closing = new RegExp("^ {0,3}" + (fence.charAt(0) === "`" ? "`" : "~") + "{" + fence.length + ",}[ \\t]*$");
    return closing.test(line) || closing.test(split(line).content);
}

function bold(out, prefix, indent, text) {
    const gap = prefix.replace(/[^>]/g, "");
    const listed = /[^> \t]/.test(prefix);
    if (!listed && out.length > 0 && !blank(out[out.length - 1]))
        out.push(gap);
    out.push(text === "" ? gap : prefix + indent + "**" + text + "**");
    out.push(gap);
}

function flattenHeadings(text) {
    const out = [];
    let fence = "";
    let paragraph = -1;
    let paragraphPrefix = "";
    for (const line of text.split("\n")) {
        if (fence !== "") {
            out.push(line);
            if (closes(fence, line))
                fence = "";
            continue;
        }
        const parts = split(line);
        const opening = FENCE.exec(parts.content);
        if (opening) {
            fence = opening[1];
            paragraph = -1;
            out.push(line);
            continue;
        }
        const heading = ATX.exec(parts.content);
        if (heading) {
            bold(out, parts.prefix, heading[1], (heading[2] || "").trim());
            paragraph = -1;
            continue;
        }
        const listed = /[^> \t]/.test(parts.prefix);
        if (paragraph >= 0 && !listed && parts.prefix === paragraphPrefix && UNDERLINE.test(parts.content)) {
            const lines = out.splice(paragraph);
            const first = split(lines[0]);
            const words = lines.map(l => split(l).content.trim()).join(" ");
            bold(out, first.prefix, /^ */.exec(first.content)[0], words);
            paragraph = -1;
            continue;
        }
        if (parts.content.trim() === "" || RULE.test(parts.content)) {
            out.push(line);
            paragraph = -1;
            continue;
        }
        if (paragraph < 0 || listed || parts.prefix !== paragraphPrefix) {
            if (paragraph < 0 && !listed && INDENTED.test(parts.content)) {
                out.push(line);
                continue;
            }
            paragraph = out.length;
            paragraphPrefix = parts.prefix;
        }
        out.push(line);
    }
    return out.join("\n");
}
