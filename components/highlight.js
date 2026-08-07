.pragma library

// SYNTAX COLOUR AS DATA. Never as markup, and never as a colour.
//
// This returns spans: a kind and the literal characters it covers. What a
// `keyword` looks like is decided in the view, because the only file in this
// shell allowed to know a colour is config/Appearance.qml, and a highlighter
// that emitted <font color="#..."> would be a second palette hiding in
// components/. See DESIGN.md 8: components may read config and nothing else,
// and this file sits below even that, so it reads nothing at all.
//
// THE ROUND-TRIP CONTRACT, which is the entire correctness story:
//
//     tokenize(t, lang).map(l => l.map(s => s.s).join("")).join("\n") === t
//     tokenize(t, lang).length === t.split("\n").length
//
// Concatenating every span of every line reproduces the input EXACTLY, and there
// is one line out per line in. Nothing is rewritten, nothing is dropped, nothing
// is inserted, not even a space. A highlighter that breaks that does not
// mis-colour a document, it silently corrupts one, and the reader has no way to
// notice: the text on screen simply is not the text that was copied. So it is
// structural rather than tested-for. `Lex.emit` is the only way a span is ever
// created, it takes OFFSETS rather than strings, and it fills the gap since the
// last token with `plain` before it writes anything. Coverage is therefore total
// by construction, and the harness in the commit message checks it anyway.
//
// ONE PASS OVER THE WHOLE TEXT, split at the newlines afterwards. Tokenizing
// line by line is the obvious first shape and it cannot be made right: a block
// comment, a template literal and a Python docstring are all states that outlive
// the line that opened them, so a per-line lexer either forgets them at every
// newline or carries a state vector between lines, which is the whole-text scan
// again with extra bookkeeping and one more thing to get wrong.
//
// A HAND-WRITTEN CHARACTER SCANNER, not a table of regexes. A regex big enough
// to describe a string literal with escapes is also big enough to backtrack
// catastrophically, and the input here is arbitrary: whatever was on the
// clipboard. A scanner that only ever moves forward cannot hang, and an
// unterminated quote or comment at the end of the buffer runs to the end and
// stops instead of throwing. The regexes that remain are in detect(), are
// anchored, and are matched against one line at a time.

// ------------------------------------------------------------------ the kinds
//
// plain keyword string number comment key punct operator boolean null type
// function added removed
//
// `key` is an object or map key, which is the one distinction JSON actually
// needs: "name" before a colon is the index into the document and "name"
// anywhere else is its content, and a highlighter that paints both the same has
// thrown away the only structure JSON has.

// ------------------------------------------------------------------- the sets
//
// Object.create(null) rather than {}. A plain object inherits from
// Object.prototype, so `words["constructor"]`, `words["toString"]` and
// `words["__proto__"]` are all truthy in a set that contains none of them, and
// `constructor` is a perfectly ordinary word to find in JavaScript.
function set(words) {
    const out = Object.create(null);
    const list = words.split(" ");
    for (let i = 0; i < list.length; i++)
        if (list[i].length > 0)
            out[list[i]] = true;
    return out;
}

function quote(open, close, multi, escape) {
    return {
        open: open,
        close: close,
        multi: multi,
        escape: escape
    };
}

// A quote list is tried IN ORDER, so the long delimiters come first: """ has to
// be recognised before ", or every Python docstring is an empty string followed
// by the docstring as code.
const PY_QUOTES = [quote('"""', '"""', true, true), quote("'''", "'''", true, true), quote('"', '"', false, true), quote("'", "'", false, true)];
const JS_QUOTES = [quote("`", "`", true, true), quote('"', '"', false, true), quote("'", "'", false, true)];
const SH_QUOTES = [quote("'", "'", true, false), quote('"', '"', true, true), quote("`", "`", true, true)];

const PUNCT = "{}[](),;:";
const OPERATOR = "+-*/%<>=!&|^~?.@#";

// One language is one row of data. The scanner below is the same for all of
// them; every difference between C and YAML that matters here is a field.
//
//   line/block   comment delimiters
//   quotes       string delimiters, longest first, and whether they may span lines
//   keyChar      what turns a name into a KEY: ":" for JSON and YAML, "=" for TOML
//   keyRule      strict = the name must also FOLLOW a "{" or a ","  (JSON, JS)
//                loose  = the trailing keyChar is enough        (QML, YAML, CSS)
//                none   = this language has no map keys         (C, shell, SQL)
//   call         a name followed by "(" is a function
//   fold         lower-case a word before looking it up (SQL, where SELECT and
//                select are the same keyword)
//   preproc      "#" at the head of a line begins a directive (C)
//   sections     "[...]" at the head of a line is a section header (TOML)
//   spacedHash   "#" only opens a comment at a line head or after a space, so a
//                URL fragment in a YAML value does not comment out the rest
//   hashColour   "#abc" is a colour literal rather than anything else (CSS)
//   dash         a hyphen is part of a name (see isName)
//   signed       a leading "-" belongs to the number after it, which is true of
//                a data format and false of anything with subtraction in it
const SPECS = Object.create(null);

function spec(id, fields) {
    const s = {
        line: [],
        block: [],
        quotes: [],
        keywords: set(""),
        types: set(""),
        booleans: set(""),
        nulls: set(""),
        keyChar: "",
        keyRule: "none",
        call: false,
        fold: false,
        preproc: false,
        sections: false,
        spacedHash: false,
        hashColour: false,
        dash: false,
        signed: false,
        punct: PUNCT,
        operator: OPERATOR
    };
    for (const k in fields)
        s[k] = fields[k];
    SPECS[id] = s;
    return s;
}

spec("json", {
    quotes: [quote('"', '"', false, true)],
    booleans: set("true false"),
    nulls: set("null"),
    keyChar: ":",
    keyRule: "strict",
    signed: true,
    operator: "-+."
});

spec("javascript", {
    line: ["//"],
    block: [["/*", "*/"]],
    quotes: JS_QUOTES,
    keywords: set("async await break case catch class const continue debugger default delete do else export extends finally for from function get if import in instanceof let new of return set static super switch this throw try typeof var void while with yield"),
    types: set("Array Boolean Date Error Function JSON Map Math Number Object Promise Proxy Reflect RegExp Set String Symbol WeakMap WeakSet BigInt Infinity NaN"),
    booleans: set("true false"),
    nulls: set("null undefined"),
    keyChar: ":",
    keyRule: "strict",
    call: true
});

spec("python", {
    line: ["#"],
    quotes: PY_QUOTES,
    keywords: set("and as assert async await break class continue def del elif else except finally for from global if import in is lambda match nonlocal not or pass raise return try while with yield"),
    types: set("bool bytearray bytes cls complex dict float frozenset int list object self set str tuple type Exception ValueError TypeError KeyError IndexError RuntimeError"),
    booleans: set("True False"),
    nulls: set("None"),
    keyChar: ":",
    keyRule: "strict",
    call: true
});

spec("shell", {
    line: ["#"],
    quotes: SH_QUOTES,
    keywords: set("alias case do done elif else esac eval exec exit export fi for function if in local readonly return select set shift source then trap unalias unset until while declare typeset"),
    types: set("echo printf read cd pwd test command builtin"),
    call: false,
    operator: "+-*/%<>=!&|^~?.$"
});

spec("c", {
    line: ["//"],
    block: [["/*", "*/"]],
    quotes: [quote('"', '"', false, true), quote("'", "'", false, true)],
    keywords: set("auto break case const continue default do else enum extern for goto if inline register restrict return sizeof static struct switch typedef union volatile while class namespace template public private protected virtual override new delete using constexpr noexcept"),
    types: set("bool char double float int long short signed unsigned void size_t ssize_t uint8_t uint16_t uint32_t uint64_t int8_t int16_t int32_t int64_t FILE va_list wchar_t"),
    booleans: set("true false"),
    nulls: set("NULL nullptr"),
    call: true,
    preproc: true
});

spec("qml", {
    line: ["//"],
    block: [["/*", "*/"]],
    quotes: JS_QUOTES,
    keywords: set("import pragma property readonly required default signal function component on as const let var return if else for while new delete typeof in of enum"),
    types: set("int real double string bool var alias color url date font point rect size vector2d vector3d vector4d matrix4x4 list QtObject Item Math JSON Qt"),
    booleans: set("true false"),
    nulls: set("null undefined"),
    keyChar: ":",
    keyRule: "loose",
    call: true
});

spec("css", {
    block: [["/*", "*/"]],
    quotes: [quote('"', '"', false, true), quote("'", "'", false, true)],
    keywords: set("important inherit initial unset revert none auto"),
    types: set("rgb rgba hsl hsla var calc url clamp min max"),
    keyChar: ":",
    keyRule: "loose",
    hashColour: true,
    dash: true,
    operator: "+-*/><=~^$|!@."
});

spec("sql", {
    line: ["--"],
    block: [["/*", "*/"]],
    quotes: [quote("'", "'", false, false), quote('"', '"', false, false), quote("`", "`", false, false)],
    keywords: set("add all alter and as asc begin between by cascade case check column commit constraint create cross default delete desc distinct drop else end exists foreign from full group having if in index inner insert into is join key left like limit not offset on or order outer primary references returning right rollback select set table then union unique update using values view when where with"),
    types: set("bigint blob boolean char date datetime decimal double float int integer numeric real serial smallint text time timestamp uuid varchar"),
    booleans: set("true false"),
    nulls: set("null"),
    fold: true,
    call: true
});

spec("yaml", {
    line: ["#"],
    quotes: [quote('"', '"', false, true), quote("'", "'", false, false)],
    booleans: set("true false yes no on off True False Yes No On Off"),
    nulls: set("null Null ~"),
    keyChar: ":",
    keyRule: "loose",
    spacedHash: true,
    dash: true,
    signed: true,
    punct: "{}[],:-",
    operator: "&*>|?!"
});

spec("toml", {
    line: ["#"],
    quotes: [quote('"""', '"""', true, true), quote("'''", "'''", true, false), quote('"', '"', false, true), quote("'", "'", false, false)],
    booleans: set("true false"),
    keyChar: "=",
    keyRule: "loose",
    sections: true,
    dash: true,
    signed: true,
    punct: "{}[],",
    operator: "=+-.:"
});

// ------------------------------------------------------------------ the lexer

function Lex(text) {
    this.text = text;
    this.n = text.length;
    // Where the pending `plain` run started. Everything between `mark` and the
    // next token is unclaimed text, and emit() hands it over before it writes
    // the token, which is what makes coverage total without anyone counting.
    this.mark = 0;
    this.spans = [];
}

Lex.prototype.emit = function (kind, from, to) {
    if (to <= from)
        return;
    if (from > this.mark)
        this.spans.push({
            k: "plain",
            s: this.text.slice(this.mark, from)
        });
    this.spans.push({
        k: kind,
        s: this.text.slice(from, to)
    });
    this.mark = to;
};

Lex.prototype.done = function () {
    if (this.n > this.mark)
        this.spans.push({
            k: "plain",
            s: this.text.slice(this.mark)
        });
    return this.spans;
};

// ------------------------------------------------------------- character work

function isDigit(c) {
    return c >= "0" && c <= "9";
}

function isHexDigit(c) {
    return isDigit(c) || (c >= "a" && c <= "f") || (c >= "A" && c <= "F");
}

function isSpace(c) {
    return c === " " || c === "\t" || c === "\r" || c === "\n";
}

// Anything above ASCII counts as a letter. Guessing which of the several
// thousand unicode identifier characters a language allows is not this file's
// job, and treating an accented name as three tokens looks broken in a way that
// treating a stray glyph as a name does not.
function isNameStart(c) {
    return c === "_" || c === "$" || (c >= "a" && c <= "z") || (c >= "A" && c <= "Z") || (c !== undefined && c > "\u007f");
}

// The hyphen is a language's CHOICE, not a fact about names. `background-color`
// and `my-key` are one name each in CSS, YAML and TOML; `a - b` is a subtraction
// everywhere else, and folding the hyphen in there loses the operator and welds
// two identifiers into one that exists nowhere.
function isName(c, dash) {
    return isNameStart(c) || isDigit(c) || (dash === true && c === "-");
}

// The first of `list` that the text starts with at i, or "".
function matchAt(text, i, list) {
    for (let j = 0; j < list.length; j++)
        if (text.startsWith(list[j], i))
            return list[j];
    return "";
}

function matchPair(text, i, pairs) {
    for (let j = 0; j < pairs.length; j++)
        if (text.startsWith(pairs[j][0], i))
            return pairs[j];
    return null;
}

function matchQuote(text, i, quotes) {
    for (let j = 0; j < quotes.length; j++)
        if (text.startsWith(quotes[j].open, i))
            return quotes[j];
    return null;
}

// The nearest non-blank character BEFORE i, skipping newlines too: a key in a
// pretty-printed document is on its own line and the "{" that proves it is a key
// is on the line above.
function prevSolid(text, i) {
    let j = i - 1;
    while (j >= 0 && isSpace(text[j]))
        j--;
    return j >= 0 ? text[j] : "";
}

// The nearest character after i, skipping spaces and tabs but NOT newlines. A
// colon that makes a name a key always sits on the same line as the name; going
// past the newline would make the first word of every paragraph a key the moment
// a colon appeared anywhere below it.
function nextSolid(text, i) {
    let j = i;
    while (j < text.length && (text[j] === " " || text[j] === "\t"))
        j++;
    return j < text.length ? text[j] : "";
}

function atLineHead(text, i) {
    let j = i - 1;
    while (j >= 0 && (text[j] === " " || text[j] === "\t"))
        j--;
    return j < 0 || text[j] === "\n";
}

// Where a string ends. Three ways out, and the last two are why a truncated
// paste cannot hang or swallow the rest of the file:
//   the closing delimiter,
//   the end of the line, for a quote that is not allowed to span lines,
//   the end of the buffer.
function endOfString(text, i, q) {
    const n = text.length;
    let j = i + q.open.length;
    while (j < n) {
        const c = text[j];
        if (q.escape && c === "\\") {
            j += 2;
            continue;
        }
        if (!q.multi && c === "\n")
            return j;
        if (text.startsWith(q.close, j))
            return j + q.close.length;
        j++;
    }
    return n;
}

// Numbers, generously: hex, binary and octal prefixes, digit separators, a
// fraction, an exponent, and whatever suffix the language puts on the end (10px,
// 0xFFul, 100n). Being greedy about the suffix costs nothing, because a suffix
// is glued to the digits and a real name never starts with one.
function endOfNumber(text, i) {
    const n = text.length;
    let j = i;
    const lead = text[j + 1];

    if (text[j] === "0" && (lead === "x" || lead === "X" || lead === "b" || lead === "B" || lead === "o" || lead === "O")) {
        j += 2;
        while (j < n && (isHexDigit(text[j]) || text[j] === "_"))
            j++;
        return j;
    }

    while (j < n && (isDigit(text[j]) || text[j] === "_"))
        j++;
    if (text[j] === "." && isDigit(text[j + 1])) {
        j++;
        while (j < n && (isDigit(text[j]) || text[j] === "_"))
            j++;
    }
    if (text[j] === "e" || text[j] === "E") {
        let k = j + 1;
        if (text[k] === "+" || text[k] === "-")
            k++;
        if (isDigit(text[k])) {
            j = k;
            while (j < n && isDigit(text[j]))
                j++;
        }
    }
    while (j < n && isNameStart(text[j]))
        j++;
    return j;
}

// Is this quoted run a KEY or a value? Both tests are needed and each kills a
// different mistake. The trailing colon alone reads the "x" in `cond ? "x" : "y"`
// as a key; the leading brace alone reads every element of ["a", "b"] as one.
function quotedKind(text, from, to, s) {
    if (s.keyRule === "none" || s.keyChar === "")
        return "string";
    if (s.keyRule === "strict") {
        const p = prevSolid(text, from);
        if (p !== "{" && p !== ",")
            return "string";
    }
    return nextSolid(text, to) === s.keyChar ? "key" : "string";
}

function nameKind(text, from, to, word, s) {
    const w = s.fold ? word.toLowerCase() : word;

    if (s.keywords[w])
        return "keyword";
    if (s.types[w])
        return "type";
    if (s.booleans[w])
        return "boolean";
    if (s.nulls[w])
        return "null";

    const next = nextSolid(text, to);

    if (s.keyChar !== "" && next === s.keyChar) {
        if (s.keyRule === "loose")
            return "key";
        if (s.keyRule === "strict") {
            const p = prevSolid(text, from);
            if (p === "{" || p === ",")
                return "key";
        }
    }
    if (s.call && next === "(")
        return "function";
    return "plain";
}

// --------------------------------------------------------- the generic pass

function scanGeneric(lex, s) {
    const t = lex.text;
    const n = lex.n;
    let i = 0;

    while (i < n) {
        const c = t[i];

        if (isSpace(c)) {
            i++;
            continue;
        }

        // A comment to the end of the line. `spacedHash` is YAML's rule: a "#"
        // glued to the end of a word is part of the word, so a URL fragment in a
        // value does not comment out the rest of the line.
        const lc = matchAt(t, i, s.line);
        if (lc !== "" && (!s.spacedHash || i === 0 || isSpace(t[i - 1]))) {
            let j = t.indexOf("\n", i);
            if (j < 0)
                j = n;
            lex.emit("comment", i, j);
            i = j;
            continue;
        }

        // A comment that runs until it is closed, or until the buffer ends.
        const bc = matchPair(t, i, s.block);
        if (bc) {
            let j = t.indexOf(bc[1], i + bc[0].length);
            j = j < 0 ? n : j + bc[1].length;
            lex.emit("comment", i, j);
            i = j;
            continue;
        }

        const q = matchQuote(t, i, s.quotes);
        if (q) {
            const end = endOfString(t, i, q);
            lex.emit(quotedKind(t, i, end, s), i, end);
            i = end;
            continue;
        }

        // A preprocessor directive is the "#" and the word after it, not the
        // whole line: `#define WIDTH 40` still has a name and a number in it.
        if (s.preproc && c === "#" && atLineHead(t, i)) {
            let j = i + 1;
            while (j < n && isNameStart(t[j]))
                j++;
            lex.emit("keyword", i, j);
            i = j;
            continue;
        }

        // A TOML table header. The whole bracketed run, because [tool.uv.sources]
        // is one name with dots in it rather than three names and two dots.
        if (s.sections && c === "[" && atLineHead(t, i)) {
            let j = t.indexOf("]", i);
            const nl = t.indexOf("\n", i);
            if (j >= 0 && (nl < 0 || j < nl)) {
                lex.emit("type", i, j + 1);
                i = j + 1;
                continue;
            }
        }

        // A CSS colour, and ONLY a colour: three, four, six or eight hex digits
        // and then something that is not a name character. Without the length
        // test `#bar` becomes the number `#ba` followed by the letter r, because
        // b and a are perfectly good hex digits.
        if (s.hashColour && c === "#" && isHexDigit(t[i + 1])) {
            let j = i + 1;
            while (j < n && isHexDigit(t[j]))
                j++;
            const digits = j - i - 1;
            if ((digits === 3 || digits === 4 || digits === 6 || digits === 8) && !isName(t[j], s.dash)) {
                lex.emit("number", i, j);
                i = j;
                continue;
            }
        }

        // A sign belongs to the literal in a data format and to the expression
        // in a language, so `signed` decides rather than the scanner.
        const signed = s.signed && (c === "-" || c === "+") && isDigit(t[i + 1]) && !isName(t[i - 1], s.dash);

        if (isDigit(c) || signed || (c === "." && isDigit(t[i + 1]) && !isName(t[i - 1], s.dash))) {
            const end = endOfNumber(t, signed ? i + 1 : i);
            lex.emit("number", i, end);
            i = end;
            continue;
        }

        if (isNameStart(c)) {
            let j = i + 1;
            while (j < n && isName(t[j], s.dash))
                j++;
            lex.emit(nameKind(t, i, j, t.slice(i, j), s), i, j);
            i = j;
            continue;
        }

        if (s.punct.indexOf(c) >= 0) {
            lex.emit("punct", i, i + 1);
            i++;
            continue;
        }

        if (s.operator.indexOf(c) >= 0) {
            let j = i;
            while (j < n && s.operator.indexOf(t[j]) >= 0)
                j++;
            lex.emit("operator", i, j);
            i = j;
            continue;
        }

        // Unclaimed. It stays plain, and emit() will pick it up with whatever
        // else was skipped before the next token.
        i++;
    }

    return lex.done();
}

// ------------------------------------------------------------------- markup

// Markup is a shape, not a grammar, so it gets its own pass rather than a spec:
// what a character means here depends on where it is on the line, which is the
// one thing the generic scanner deliberately does not look at.
function scanHtml(lex) {
    const t = lex.text;
    const n = lex.n;
    let i = 0;

    while (i < n) {
        if (t[i] !== "<") {
            i++;
            continue;
        }

        if (t.startsWith("<!--", i)) {
            let j = t.indexOf("-->", i);
            j = j < 0 ? n : j + 3;
            lex.emit("comment", i, j);
            i = j;
            continue;
        }

        // A doctype or a processing instruction: one declaration, one colour.
        if (t.startsWith("<!", i) || t.startsWith("<?", i)) {
            let j = t.indexOf(">", i);
            j = j < 0 ? n : j + 1;
            lex.emit("keyword", i, j);
            i = j;
            continue;
        }

        let j = i + 1;
        if (t[j] === "/")
            j++;
        if (!isNameStart(t[j])) {
            i++;
            continue;
        }

        lex.emit("punct", i, j);
        let k = j;
        while (k < n && (isName(t[k], true) || t[k] === ":"))
            k++;
        lex.emit("type", j, k);
        i = k;

        // Attributes, until the tag closes or the buffer runs out.
        while (i < n && t[i] !== ">") {
            const c = t[i];
            if (isSpace(c)) {
                i++;
                continue;
            }
            if (c === '"' || c === "'") {
                const end = endOfString(t, i, quote(c, c, true, false));
                lex.emit("string", i, end);
                i = end;
                continue;
            }
            if (isNameStart(c)) {
                let a = i + 1;
                while (a < n && (isName(t[a], true) || t[a] === ":"))
                    a++;
                lex.emit("key", i, a);
                i = a;
                continue;
            }
            lex.emit(c === "=" ? "operator" : "punct", i, i + 1);
            i++;
        }
        if (i < n) {
            lex.emit("punct", i, i + 1);
            i++;
        }
    }

    return lex.done();
}

// ------------------------------------------------------- line-shaped formats

// Walk the text a line at a time WITHOUT splitting it. `fn` is handed the
// absolute offsets of one line's contents, so every span it emits is still a
// slice of the original buffer at its original position and the contract holds
// for free.
function eachLine(lex, fn) {
    const t = lex.text;
    const n = lex.n;
    let i = 0;
    while (i <= n) {
        let e = t.indexOf("\n", i);
        if (e < 0)
            e = n;
        fn(i, e);
        if (e === n)
            break;
        i = e + 1;
    }
    return lex.done();
}

// A diff is the one format where the FIRST CHARACTER of a line is the whole
// meaning, so nothing inside a line is tokenized at all: colouring the contents
// of a removed line would fight the one thing the reader is here to see.
function scanDiff(lex) {
    const t = lex.text;
    return eachLine(lex, (from, to) => {
        if (to <= from)
            return;
        const head = t.slice(from, Math.min(from + 4, to));

        if (head.startsWith("+++") || head.startsWith("---"))
            lex.emit("key", from, to);
        else if (head.startsWith("@@"))
            lex.emit("keyword", from, to);
        else if (head.startsWith("diff ") || head.startsWith("inde") || head.startsWith("new ") || head.startsWith("dele") || head.startsWith("simi") || head.startsWith("rena") || head.startsWith("\\"))
            lex.emit("comment", from, to);
        else if (head[0] === "+")
            lex.emit("added", from, to);
        else if (head[0] === "-")
            lex.emit("removed", from, to);
    });
}

// Enough Markdown to read a pasted README by shape: headings, fences, quotes,
// list markers and inline code. Emphasis is deliberately left alone. A single
// asterisk is ambiguous without a full inline parser, and getting it wrong
// swallows the rest of a paragraph into a colour, which is far worse than
// leaving bold text the same weight as the rest of the prose.
function scanMarkdown(lex) {
    const t = lex.text;
    let fenced = false;

    return eachLine(lex, (from, to) => {
        if (to <= from)
            return;

        let i = from;
        while (i < to && (t[i] === " " || t[i] === "\t"))
            i++;

        if (t.startsWith("```", i) || t.startsWith("~~~", i)) {
            lex.emit("keyword", i, to);
            fenced = !fenced;
            return;
        }
        if (fenced) {
            lex.emit("string", from, to);
            return;
        }
        if (t[i] === "#") {
            lex.emit("key", i, to);
            return;
        }
        if (t[i] === ">") {
            lex.emit("comment", i, to);
            return;
        }

        // A list marker, and only a marker: "- " and "1. " count, a hyphen with a
        // word stuck to it does not.
        if ((t[i] === "-" || t[i] === "*" || t[i] === "+") && t[i + 1] === " ") {
            lex.emit("punct", i, i + 1);
            i++;
        } else if (isDigit(t[i])) {
            let j = i;
            while (j < to && isDigit(t[j]))
                j++;
            if (t[j] === "." && t[j + 1] === " ") {
                lex.emit("punct", i, j + 1);
                i = j + 1;
            }
        }

        // Inline code, which is the one inline form a backtick cannot be
        // mistaken about.
        while (i < to) {
            if (t[i] === "`") {
                let j = t.indexOf("`", i + 1);
                if (j < 0 || j >= to)
                    break;
                lex.emit("string", i, j + 1);
                i = j + 1;
                continue;
            }
            i++;
        }
    });
}

// ---------------------------------------------------------------- the front

function toLines(text, spans) {
    const lines = [[]];
    for (let i = 0; i < spans.length; i++) {
        const span = spans[i];
        const parts = span.s.split("\n");
        for (let j = 0; j < parts.length; j++) {
            if (j > 0)
                lines.push([]);
            if (parts[j].length > 0)
                lines[lines.length - 1].push({
                    k: span.k,
                    s: parts[j]
                });
        }
    }
    return lines;
}

// text -> an array of LINES, each an array of {k, s} spans.
//
// An unknown or empty language is not an error and does not throw: it returns
// the text as one plain span per line, which is exactly what a viewer wants for
// something it could not identify.
function tokenize(text, language) {
    if (typeof text !== "string")
        return [[]];

    const lex = new Lex(text);
    let spans;

    if (language === "html")
        spans = scanHtml(lex);
    else if (language === "diff")
        spans = scanDiff(lex);
    else if (language === "markdown")
        spans = scanMarkdown(lex);
    else if (SPECS[language])
        spans = scanGeneric(lex, SPECS[language]);
    else
        spans = lex.done();

    return toLines(text, spans);
}

// ------------------------------------------------------------------- detect

// WHAT IT IS, and "" when it is not sure.
//
// Conservative on purpose. A wrong guess is worse than no guess: unhighlighted
// text reads as text, whereas prose lexed as C has half its words in the keyword
// colour and the reader is left doing the parsing the highlighter was there to
// do. So every rule here is either a signal nothing else produces (a shebang, a
// doctype, an #include, a diff hunk header, a document that JSON.parse accepts)
// or it needs two independent witnesses before it will answer.

const SAMPLE = 65536;
const HEAD_LINES = 400;

function countLines(lines, re) {
    let hits = 0;
    for (let i = 0; i < lines.length; i++)
        if (re.test(lines[i]))
            hits++;
    return hits;
}

function anyLine(lines, re) {
    for (let i = 0; i < lines.length; i++)
        if (re.test(lines[i]))
            return true;
    return false;
}

function score(text, tests) {
    let hits = 0;
    for (let i = 0; i < tests.length; i++)
        if (tests[i].test(text))
            hits++;
    return hits;
}

// The whole document, not the sample: JSON is the one language with a decider
// rather than a heuristic, and a decider that only reads the first 64k would
// call a truncated object valid.
function looksLikeJson(text) {
    const trimmed = text.trim();
    if (trimmed.length < 2)
        return false;
    const open = trimmed[0];
    const close = trimmed[trimmed.length - 1];
    if (!((open === "{" && close === "}") || (open === "[" && close === "]")))
        return false;
    try {
        JSON.parse(trimmed);
        return true;
    } catch (e) {
        return false;
    }
}

function detect(text) {
    if (typeof text !== "string" || text.length === 0)
        return "";

    const head = text.length > SAMPLE ? text.slice(0, SAMPLE) : text;
    const all = head.split("\n");
    const lines = all.length > HEAD_LINES ? all.slice(0, HEAD_LINES) : all;
    const lead = head.replace(/^\s+/, "");

    // 1. A shebang says it outright, and says it about the file rather than
    //    about a line of it.
    const bang = /^#!.*?\b(bash|zsh|sh|dash|ksh|python[0-9.]*|node|deno)\b/.exec(lines[0] || "");
    if (bang) {
        const who = bang[1];
        if (who === "node" || who === "deno")
            return "javascript";
        if (who.indexOf("python") === 0)
            return "python";
        return "shell";
    }

    // 2. A declaration at the very top of the document.
    if (/^<\?xml\b/i.test(lead) || /^<!doctype\s+html\b/i.test(lead) || /^<html\b/i.test(lead))
        return "html";

    // 3. A diff carries its own frame.
    if (anyLine(lines, /^diff --git /) || anyLine(lines, /^@@ .* @@/) || (anyLine(lines, /^--- /) && anyLine(lines, /^\+\+\+ /)))
        return "diff";

    // 4. The only test in here that is a proof rather than a guess.
    if (text.length <= 4 * 1024 * 1024 && looksLikeJson(text))
        return "json";

    // 5. QML announces itself in its first two lines, and its imports are not
    //    shaped like anyone else's.
    if (anyLine(lines, /^\s*import Qt[A-Za-z.]*\s*$/) || anyLine(lines, /^pragma (Singleton|ComponentBehavior)\b/))
        return "qml";

    if (anyLine(lines, /^\s*#include\s*[<"]/))
        return "c";

    // 6. A def or a class with a colon on the end of the line is not a shape any
    //    of the others make.
    if (anyLine(lines, /^\s*(def|class)\s+\w+.*:\s*$/) || anyLine(lines, /^\s*from\s+[\w.]+\s+import\s/) || anyLine(lines, /^\s*if\s+__name__\s*==/))
        return "python";

    // 7. Two witnesses from here down.
    const cssRule = countLines(lines, /^\s*[\w.#\[:*>&-][^{};]*\{\s*$/);
    const cssDecl = countLines(lines, /^\s*[-\w]+\s*:\s*[^;{}]+;\s*$/);
    if (cssRule >= 1 && cssDecl >= 2 && anyLine(lines, /^\s*\}\s*$/))
        return "css";

    if (/<[a-zA-Z][\w-]*(\s[^<>]*)?>/.test(head) && /<\/[a-zA-Z][\w-]*>/.test(head))
        return "html";

    if (anyLine(lines, /^\s*(select|insert\s+into|update|delete\s+from|create\s+(table|view|index)|alter\s+table|drop\s+table)\b/i) && score(head, [/\bfrom\b/i, /\bwhere\b/i, /\bvalues\b/i, /\bjoin\b/i, /\bset\b/i, /\bgroup\s+by\b/i]) >= 1)
        return "sql";

    if (score(head, [/^\s*(if|while|for)\b[^\n]*;\s*(then|do)\b/m, /^\s*(fi|done|esac)\s*$/m, /\$\{[\w#!]/, /\$\([^)]/, /^\s*(export|local|readonly)\s+\w+=/m, /^\s*\w+\(\)\s*\{\s*$/m]) >= 2)
        return "shell";

    if (score(head, [/^\s*(const|let|var)\s+[\w{[]/m, /=>\s*[{(\w'"`]/, /\bfunction\s*\w*\s*\(/, /\brequire\s*\(\s*['"]/, /^\s*import\s.+\sfrom\s+['"]/m, /\bmodule\.exports\b/, /\bconsole\.(log|error|warn)\s*\(/]) >= 2)
        return "javascript";

    const tomlSection = countLines(lines, /^\s*\[[\w.\-"']+\]\s*$/);
    const tomlPair = countLines(lines, /^\s*[\w.\-"']+\s*=\s*\S/);
    if ((tomlSection >= 1 && tomlPair >= 1) || (tomlPair >= 3 && !/[{};]/.test(head)))
        return "toml";

    // 8. YAML has no delimiters to find, so the test is that MOST of the
    //    document is shaped like YAML rather than that some of it is. Two keys
    //    alone would call an HTTP header dump, an ini file and half the prose in
    //    the world a config.
    const solid = lines.filter(l => l.trim().length > 0);
    if (solid.length >= 2) {
        const yamlish = countLines(solid, /^\s*(#|-\s|-$|---|\.\.\.|[\w.$/\\'"-]+\s*:(\s|$))/);
        const keys = countLines(solid, /^\s*[\w.$/\\'"-]+\s*:(\s|$)/);
        if (keys >= 2 && yamlish >= solid.length * 0.7 && !/[{};]/.test(head))
            return "yaml";
    }

    if (score(head, [/^#{1,6}\s+\S/m, /^```/m, /^\s*[-*+]\s+\S/m, /\[[^\]\n]+\]\([^)\n]+\)/, /^\s*\|.+\|\s*$/m, /^(=|-){3,}\s*$/m]) >= 2)
        return "markdown";

    return "";
}
