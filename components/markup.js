.pragma library

var KEPT = ["b", "i", "u"];

var NAMED = {
    amp: "&",
    lt: "<",
    gt: ">",
    quot: "\"",
    apos: "'",
    nbsp: " "
};

function isNameCharacter(c) {
    return /[a-zA-Z0-9]/.test(c);
}

function readTag(text, start) {
    var i = start + 1;
    var closing = false;
    if (text.charAt(i) === "/") {
        closing = true;
        i++;
    }
    if (!/[a-zA-Z]/.test(text.charAt(i)))
        return null;
    var nameStart = i;
    while (i < text.length && isNameCharacter(text.charAt(i)))
        i++;
    var name = text.slice(nameStart, i).toLowerCase();
    var after = text.charAt(i);
    if (after !== ">" && after !== "/" && !/\s/.test(after))
        return null;

    var quote = "";
    for (; i < text.length; i++) {
        var c = text.charAt(i);
        if (quote) {
            if (c === quote)
                quote = "";
            continue;
        }
        if (c === "\"" || c === "'") {
            quote = c;
            continue;
        }
        if (c === "<")
            return null;
        if (c === ">")
            return {
                name: name,
                closing: closing,
                empty: text.charAt(i - 1) === "/",
                end: i + 1
            };
    }
    return null;
}

function characterFor(code) {
    if (code < 0x10000)
        return String.fromCharCode(code);
    code -= 0x10000;
    return String.fromCharCode(0xd800 + (code >> 10), 0xdc00 + (code & 0x3ff));
}

function readEntity(text, start) {
    var semicolon = text.indexOf(";", start);
    if (semicolon < 0 || semicolon - start > 12)
        return null;
    var name = text.slice(start + 1, semicolon);
    var code = NaN;
    if (/^#[0-9]+$/.test(name))
        code = parseInt(name.slice(1), 10);
    else if (/^#[xX][0-9a-fA-F]+$/.test(name))
        code = parseInt(name.slice(2), 16);
    else if (Object.prototype.hasOwnProperty.call(NAMED, name))
        return {
            text: NAMED[name],
            end: semicolon + 1
        };
    else
        return null;
    if (!(code > 0 && code <= 0x10ffff) || (code >= 0xd800 && code < 0xe000))
        return null;
    return {
        text: characterFor(code),
        end: semicolon + 1
    };
}

function escapeCharacter(c) {
    if (c === "&")
        return "&amp;";
    if (c === "<")
        return "&lt;";
    if (c === ">")
        return "&gt;";
    if (c === "\n")
        return "<br>";
    return c;
}

function escape(text) {
    var out = "";
    for (var i = 0; i < text.length; i++)
        out += escapeCharacter(text.charAt(i));
    return out;
}

function placeTag(tag, open) {
    if (tag.name === "br")
        return tag.closing ? "" : "<br>";
    if (KEPT.indexOf(tag.name) < 0 || tag.empty)
        return "";
    if (!tag.closing) {
        open.push(tag.name);
        return "<" + tag.name + ">";
    }
    var at = open.lastIndexOf(tag.name);
    if (at < 0)
        return "";
    var closed = "";
    while (open.length > at)
        closed += "</" + open.pop() + ">";
    return closed;
}

function closeAll(open) {
    var closed = "";
    while (open.length)
        closed += "</" + open.pop() + ">";
    return closed;
}

function sanitise(text) {
    text = text === undefined || text === null ? "" : String(text);
    var out = "";
    var open = [];
    var i = 0;
    while (i < text.length) {
        var c = text.charAt(i);
        if (c === "<") {
            var tag = readTag(text, i);
            if (tag) {
                out += placeTag(tag, open);
                i = tag.end;
                continue;
            }
        } else if (c === "&") {
            var entity = readEntity(text, i);
            if (entity) {
                out += escape(entity.text);
                i = entity.end;
                continue;
            }
        } else if (c === "\r") {
            out += "<br>";
            i += text.charAt(i + 1) === "\n" ? 2 : 1;
            continue;
        }
        out += escapeCharacter(c);
        i++;
    }
    return out + closeAll(open);
}

function pieces(markup) {
    var out = [];
    var i = 0;
    while (i < markup.length) {
        var c = markup.charAt(i);
        if (c === "<") {
            var tag = readTag(markup, i);
            if (tag) {
                out.push({
                    markup: markup.slice(i, tag.end),
                    shown: tag.name === "br" ? "\n" : "",
                    tag: tag.name === "br" ? null : tag
                });
                i = tag.end;
                continue;
            }
        } else if (c === "&") {
            var entity = readEntity(markup, i);
            if (entity) {
                out.push({
                    markup: markup.slice(i, entity.end),
                    shown: entity.text,
                    tag: null
                });
                i = entity.end;
                continue;
            }
        }
        out.push({
            markup: c,
            shown: c,
            tag: null
        });
        i++;
    }
    return out;
}

function shorten(markup, limit) {
    var all = pieces(markup);
    var shown = "";
    for (var k = 0; k < all.length; k++)
        shown += all[k].shown;
    if (shown.length <= limit)
        return markup;

    var cut = shown.slice(0, limit);
    var space = cut.lastIndexOf(" ");
    var keep = space > limit * 0.6 ? space : limit;
    while (keep > 0 && /\s/.test(cut.charAt(keep - 1)))
        keep--;

    var out = "";
    var open = [];
    var placed = 0;
    for (var j = 0; j < all.length && placed < keep; j++) {
        var piece = all[j];
        if (piece.tag) {
            if (piece.tag.closing) {
                var at = open.lastIndexOf(piece.tag.name);
                if (at >= 0)
                    open.splice(at, 1);
            } else {
                open.push(piece.tag.name);
            }
        }
        out += piece.markup;
        placed += piece.shown.length;
    }
    return out + "…" + closeAll(open);
}
