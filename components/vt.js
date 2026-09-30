var BOLD = 1, DIM = 2, ITALIC = 4, UNDERLINE = 8, BLINK = 16, REVERSE = 32,
    HIDDEN = 64, STRIKE = 128;

var ANSI16 = ["#000000", "#cd0000", "#00cd00", "#cdcd00", "#0000ee", "#cd00cd",
    "#00cdcd", "#e5e5e5", "#7f7f7f", "#ff0000", "#00ff00", "#ffff00",
    "#5c5cff", "#ff00ff", "#00ffff", "#ffffff"];

function charWidth(cp) {
    if (cp === 0)
        return 0;
    if (cp < 0x300)
        return 1;

    if (cp >= 0x300 && cp <= 0x36f || cp >= 0x200b && cp <= 0x200f
        || cp >= 0xfe00 && cp <= 0xfe0f || cp >= 0x20d0 && cp <= 0x20f0)
        return 0;
    if (cp >= 0x1100 && cp <= 0x115f || cp >= 0x2e80 && cp <= 0xa4cf
        || cp >= 0xac00 && cp <= 0xd7a3 || cp >= 0xf900 && cp <= 0xfaff
        || cp >= 0xfe30 && cp <= 0xfe6f || cp >= 0xff00 && cp <= 0xff60
        || cp >= 0xffe0 && cp <= 0xffe6 || cp >= 0x1f300 && cp <= 0x1f64f
        || cp >= 0x1f900 && cp <= 0x1f9ff)
        return 2;
    return 1;
}

var DEC_GRAPHICS = {
    0x5f: " ", 0x60: "\u25c6", 0x61: "\u2592", 0x62: "\u2409", 0x63: "\u240c",
    0x64: "\u240d", 0x65: "\u240a", 0x66: "\u00b0", 0x67: "\u00b1", 0x68: "\u2424",
    0x69: "\u240b", 0x6a: "\u2518", 0x6b: "\u2510", 0x6c: "\u250c", 0x6d: "\u2514",
    0x6e: "\u253c", 0x6f: "\u23ba", 0x70: "\u23bb", 0x71: "\u2500", 0x72: "\u23bc",
    0x73: "\u23bd", 0x74: "\u251c", 0x75: "\u2524", 0x76: "\u2534", 0x77: "\u252c",
    0x78: "\u2502", 0x79: "\u2264", 0x7a: "\u2265", 0x7b: "\u03c0", 0x7c: "\u2260",
    0x7d: "\u00a3", 0x7e: "\u00b7"
};

function blankCell() {
    return {c: " ", f: null, b: null, a: 0, w: 1};
}

function blankRow(cols) {
    var cells = new Array(cols);
    for (var i = 0; i < cols; i++)
        cells[i] = blankCell();
    return cells;
}

function Screen(cols, rows) {
    this.cols = cols;
    this.rows = rows;
    this.lines = [];
    for (var i = 0; i < rows; i++)
        this.lines.push(blankRow(cols));
    this.x = 0;
    this.y = 0;
    this.top = 0;
    this.bottom = rows - 1;

    this.pending = false;
}

function Terminal(cols, rows, opts) {
    opts = opts || {};

    this.cols = Math.max(1, cols);
    this.rows = Math.max(1, rows);
    this.palette = opts.palette || ANSI16;
    this.scrollbackMax = opts.scrollback === undefined ? 5000 : opts.scrollback;

    this.main = new Screen(this.cols, this.rows);
    this.alt = new Screen(this.cols, this.rows);
    this.screen = this.main;
    this.altActive = false;

    this.scrollback = [];

    this.fg = null;
    this.bg = null;
    this.attrs = 0;

    this.cursorVisible = true;
    this.appCursor = false;
    this.appKeypad = false;
    this.autowrap = true;
    this.bracketedPaste = false;
    this.mouse = 0;

    this.foreground = opts.foreground || "#ffffff";
    this.background = opts.background || "#000000";
    this.fgQuery = rgbReply(this.foreground);
    this.bgQuery = rgbReply(this.background);

    this.title = "";
    this.cwd = "";

    this.reply = "";

    this.revision = 0;

    this.saved = null;
    this.tabs = {};
    for (var t = 8; t < this.cols; t += 8)
        this.tabs[t] = true;

    this.charsets = ["B", "B"];
    this.charset = 0;

    this.state = "ground";
    this.params = [];
    this.paramBuf = "";
    this.intermediate = "";
    this.stringBuf = "";
    this.stringKind = "";

    this.utf8 = [];
    this.utf8Need = 0;
}

Terminal.prototype.touch = function () {
    this.revision++;
};

Terminal.prototype.line = function (y) {
    return this.screen.lines[y];
};

Terminal.prototype.clampCursor = function () {
    var s = this.screen;
    s.x = Math.max(0, Math.min(s.x, this.cols - 1));
    s.y = Math.max(0, Math.min(s.y, this.rows - 1));
};

Terminal.prototype.scrollUp = function (n) {
    var s = this.screen;
    for (var i = 0; i < n; i++) {
        var gone = s.lines.splice(s.top, 1)[0];

        if (!this.altActive && s.top === 0 && s.bottom === this.rows - 1 && this.scrollbackMax > 0) {
            this.scrollback.push(this.renderLine(gone));
            if (this.scrollback.length > this.scrollbackMax)
                this.scrollback.shift();
        }
        s.lines.splice(s.bottom, 0, blankRow(this.cols));
    }
};

Terminal.prototype.scrollDown = function (n) {
    var s = this.screen;
    for (var i = 0; i < n; i++) {
        s.lines.splice(s.bottom, 1);
        s.lines.splice(s.top, 0, blankRow(this.cols));
    }
};

Terminal.prototype.newline = function () {
    var s = this.screen;
    if (s.y === s.bottom)
        this.scrollUp(1);
    else if (s.y < this.rows - 1)
        s.y++;
};

Terminal.prototype.put = function (ch, width) {
    var s = this.screen;

    if (s.pending && this.autowrap) {
        s.x = 0;
        this.newline();
        s.pending = false;
    }

    if (width === 0) {
        var prev = s.lines[s.y][Math.max(0, s.x - 1)];
        if (prev)
            prev.c += ch;
        return;
    }

    if (s.x + width > this.cols) {
        if (!this.autowrap)
            return;
        s.x = 0;
        this.newline();
    }

    var cell = s.lines[s.y][s.x];
    cell.c = ch;
    cell.f = this.fg;
    cell.b = this.bg;
    cell.a = this.attrs;
    cell.w = width;

    if (width === 2 && s.x + 1 < this.cols) {
        var tail = s.lines[s.y][s.x + 1];
        tail.c = "";
        tail.f = this.fg;
        tail.b = this.bg;
        tail.a = this.attrs;
        tail.w = 0;
    }

    s.x += width;
    if (s.x >= this.cols) {
        s.x = this.cols - 1;
        s.pending = true;
    }
};

Terminal.prototype.eraseCells = function (y, from, to) {
    var row = this.screen.lines[y];
    for (var x = from; x <= to && x < this.cols; x++) {
        row[x].c = " ";
        row[x].f = null;

        row[x].b = this.bg;
        row[x].a = 0;
        row[x].w = 1;
    }
};

Terminal.prototype.resize = function (cols, rows) {
    cols = Math.max(1, cols);
    rows = Math.max(1, rows);
    if (cols === this.cols && rows === this.rows)
        return;

    var screens = [this.main, this.alt];
    for (var i = 0; i < screens.length; i++) {
        var s = screens[i];
        for (var y = 0; y < s.lines.length; y++) {
            var row = s.lines[y];
            while (row.length < cols)
                row.push(blankCell());
            row.length = cols;
        }
        while (s.lines.length < rows)
            s.lines.push(blankRow(cols));

        while (s.lines.length > rows) {
            if (s === this.main && this.scrollbackMax > 0 && s.y < s.lines.length - 1)
                this.scrollback.push(this.renderLine(s.lines.shift()));
            else
                s.lines.pop();
            if (s === this.main)
                s.y = Math.max(0, s.y - 1);
        }
        s.cols = cols;
        s.rows = rows;
        s.top = 0;
        s.bottom = rows - 1;
    }

    this.cols = cols;
    this.rows = rows;
    this.tabs = {};
    for (var t = 8; t < cols; t += 8)
        this.tabs[t] = true;
    this.clampCursor();
    this.touch();
};

Terminal.prototype.colour = function (v) {
    if (v === null || v === undefined)
        return null;
    if (typeof v === "string")
        return v;
    if (v < 16)
        return this.palette[v] || ANSI16[v];

    if (v < 232) {
        var i = v - 16;
        var steps = [0, 95, 135, 175, 215, 255];
        var r = steps[Math.floor(i / 36) % 6];
        var g = steps[Math.floor(i / 6) % 6];
        var b = steps[i % 6];
        return "#" + hex2(r) + hex2(g) + hex2(b);
    }

    var l = 8 + (v - 232) * 10;
    return "#" + hex2(l) + hex2(l) + hex2(l);
};

function rgbReply(hex) {
    var m = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(hex);
    if (!m)
        return "rgb:0000/0000/0000";
    var pair = function (h) {
        return (h + h).toLowerCase();
    };
    return "rgb:" + pair(m[1]) + "/" + pair(m[2]) + "/" + pair(m[3]);
}

function mixHex(a, b, t) {
    var pa = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(a);
    var pb = /^#?([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})/i.exec(b);
    if (!pa || !pb)
        return a;
    var lerp = function (i) {
        var x = parseInt(pa[i], 16);
        var y = parseInt(pb[i], 16);
        return hex2(x + (y - x) * t);
    };
    return "#" + lerp(1) + lerp(2) + lerp(3);
}

function hex2(n) {
    var s = Math.max(0, Math.min(255, Math.round(n))).toString(16);
    return s.length < 2 ? "0" + s : s;
}

function escapeMarkup(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

Terminal.prototype.renderLine = function (row) {
    var out = "";
    var runs = [];
    var i = 0;

    var end = row.length - 1;
    while (end >= 0 && row[end].c === " " && row[end].b === null && row[end].a === 0)
        end--;

    while (i <= end) {
        var cell = row[i];
        var fg = cell.f, bg = cell.b, a = cell.a;

        var j = i;
        var text = "";
        while (j <= end && row[j].f === fg && row[j].b === bg && row[j].a === a) {
            text += row[j].c;
            j++;
        }

        if (a & REVERSE) {
            var ink = fg === null ? this.foreground : this.colour(fg);
            var paper = bg === null ? this.background : this.colour(bg);
            fg = paper;
            bg = ink;
        } else {
            fg = fg === null ? null : this.colour(fg);
            bg = bg === null ? null : this.colour(bg);
        }

        if (a & DIM)
            fg = mixHex(fg === null ? this.foreground : fg, bg === null ? this.background : bg, 0.3);

        if (bg !== null)
            runs.push({x: i, len: j - i, colour: bg});

        var body = escapeMarkup(text);
        if (a & HIDDEN)
            body = escapeMarkup(text.replace(/[^\s]/g, " "));
        if (a & BOLD)
            body = "<b>" + body + "</b>";
        if (a & ITALIC)
            body = "<i>" + body + "</i>";
        if (a & UNDERLINE)
            body = "<u>" + body + "</u>";
        if (a & STRIKE)
            body = "<s>" + body + "</s>";
        if (fg !== null)
            body = "<font color=\"" + (typeof fg === "string" ? fg : this.colour(fg)) + "\">" + body + "</font>";

        out += body;
        i = j;
    }

    return {markup: out, runs: runs};
};

Terminal.prototype.view = function (offset) {
    var lines = [];
    var back = this.scrollback.length;
    var start = Math.max(0, back - (offset || 0));

    for (var i = start; i < back; i++)
        lines.push(this.scrollback[i]);
    for (var y = 0; y < this.rows && lines.length < this.rows; y++)
        lines.push(this.renderLine(this.screen.lines[y]));

    return lines;
};

Terminal.prototype.write = function (bytes) {
    for (var i = 0; i < bytes.length; i++)
        this.byte(bytes.charCodeAt(i) & 0xff);
    this.touch();
};

Terminal.prototype.byte = function (b) {

    if (this.state === "osc" || this.state === "dcs") {
        if (b === 0x07) {
            this.endString();
            return;
        }
        if (b === 0x1b) {
            this.state = this.state + "-esc";
            return;
        }

        if (b < 0x20 && b !== 0x0d && b !== 0x0a) {
            this.endString();
            this.byte(b);
            return;
        }
        this.stringBuf += String.fromCharCode(b);
        return;
    }

    if (this.state === "osc-esc" || this.state === "dcs-esc") {

        this.state = this.state.slice(0, 3);
        this.endString();
        if (b !== 0x5c)
            this.byte(b);
        return;
    }

    if (this.state === "esc") {
        this.escape(b);
        return;
    }

    if (this.state === "csi") {
        this.csi(b);
        return;
    }

    if (this.state === "charset") {
        this.charsets[this.charsetSlot || 0] = String.fromCharCode(b);
        this.state = "ground";
        return;
    }

    if (b === 0x1b) {
        this.state = "esc";
        this.intermediate = "";
        return;
    }
    if (b < 0x20) {
        this.control(b);
        return;
    }
    this.text(b);
};

Terminal.prototype.control = function (b) {
    var s = this.screen;
    switch (b) {
    case 0x07:

        break;
    case 0x0e:
        this.charset = 1;
        break;
    case 0x0f:
        this.charset = 0;
        break;
    case 0x08:
        if (s.pending)
            s.pending = false;
        else if (s.x > 0)
            s.x--;
        break;
    case 0x09:
        var next = s.x + 1;
        while (next < this.cols - 1 && !this.tabs[next])
            next++;
        s.x = Math.min(next, this.cols - 1);
        break;
    case 0x0a:
    case 0x0b:
    case 0x0c:
        this.newline();
        s.pending = false;
        break;
    case 0x0d:
        s.x = 0;
        s.pending = false;
        break;
    }
};

Terminal.prototype.text = function (b) {
    var cp = -1;

    if (this.utf8Need > 0) {
        if ((b & 0xc0) !== 0x80) {

            this.utf8 = [];
            this.utf8Need = 0;
            this.put("�", 1);
            this.byte(b);
            return;
        }
        this.utf8.push(b);
        if (--this.utf8Need > 0)
            return;

        var bytes = this.utf8;
        this.utf8 = [];
        var lead = bytes[0];
        if (bytes.length === 2)
            cp = (lead & 0x1f) << 6 | bytes[1] & 0x3f;
        else if (bytes.length === 3)
            cp = (lead & 0x0f) << 12 | (bytes[1] & 0x3f) << 6 | bytes[2] & 0x3f;
        else
            cp = (lead & 0x07) << 18 | (bytes[1] & 0x3f) << 12 | (bytes[2] & 0x3f) << 6 | bytes[3] & 0x3f;
    } else if (b < 0x80) {
        cp = b;
    } else if ((b & 0xe0) === 0xc0) {
        this.utf8 = [b];
        this.utf8Need = 1;
        return;
    } else if ((b & 0xf0) === 0xe0) {
        this.utf8 = [b];
        this.utf8Need = 2;
        return;
    } else if ((b & 0xf8) === 0xf0) {
        this.utf8 = [b];
        this.utf8Need = 3;
        return;
    } else {
        cp = 0xfffd;
    }

    if (this.charsets[this.charset] === "0" && DEC_GRAPHICS[cp]) {
        this.put(DEC_GRAPHICS[cp], 1);
        return;
    }

    var ch = cp > 0xffff
        ? String.fromCharCode(0xd800 + (cp - 0x10000 >> 10), 0xdc00 + (cp - 0x10000 & 0x3ff))
        : String.fromCharCode(cp);
    this.put(ch, charWidth(cp));
};

Terminal.prototype.escape = function (b) {
    var c = String.fromCharCode(b);
    var s = this.screen;

    if (c === "[") {
        this.state = "csi";
        this.params = [];
        this.paramBuf = "";
        this.intermediate = "";
        return;
    }
    if (c === "]" || c === "P" || c === "^" || c === "_" || c === "X") {
        this.state = c === "]" ? "osc" : "dcs";
        this.stringKind = c;
        this.stringBuf = "";
        return;
    }

    if (c === "(" || c === ")" || c === "*" || c === "+") {
        this.state = "charset";
        this.charsetSlot = c === "(" ? 0 : 1;
        return;
    }

    this.state = "ground";
    switch (c) {
    case "7":
        this.saved = {x: s.x, y: s.y, fg: this.fg, bg: this.bg, attrs: this.attrs};
        break;
    case "8":
        if (this.saved) {
            s.x = this.saved.x;
            s.y = this.saved.y;
            this.fg = this.saved.fg;
            this.bg = this.saved.bg;
            this.attrs = this.saved.attrs;
            this.clampCursor();
        }
        break;
    case "D":
        this.newline();
        break;
    case "E":
        s.x = 0;
        this.newline();
        break;
    case "M":
        if (s.y === s.top)
            this.scrollDown(1);
        else if (s.y > 0)
            s.y--;
        break;
    case "c":
        this.reset();
        break;
    case "=":
        this.appKeypad = true;
        break;
    case ">":
        this.appKeypad = false;
        break;
    case "H":
        this.tabs[s.x] = true;
        break;
    }
};

Terminal.prototype.csi = function (b) {
    var c = String.fromCharCode(b);

    if (c >= "0" && c <= "9") {
        this.paramBuf += c;
        return;
    }
    if (c === ";" || c === ":") {
        this.params.push(this.paramBuf === "" ? -1 : parseInt(this.paramBuf, 10));
        this.paramBuf = "";
        return;
    }
    if (b >= 0x20 && b <= 0x2f || c === "?" || c === "<" || c === "=" || c === ">") {
        this.intermediate += c;
        return;
    }

    this.params.push(this.paramBuf === "" ? -1 : parseInt(this.paramBuf, 10));
    this.paramBuf = "";
    this.state = "ground";
    this.dispatch(c);
};

Terminal.prototype.param = function (i, dflt) {
    var v = this.params[i];
    return v === undefined || v === -1 ? dflt : v;
};

Terminal.prototype.dispatch = function (c) {
    var s = this.screen;
    var n, i;

    switch (c) {
    case "@":
        n = this.param(0, 1);
        for (i = 0; i < n; i++) {
            s.lines[s.y].splice(s.x, 0, blankCell());
            s.lines[s.y].length = this.cols;
        }
        break;
    case "A":
        s.y = Math.max(s.top, s.y - this.param(0, 1));
        break;
    case "B":
        s.y = Math.min(s.bottom, s.y + this.param(0, 1));
        break;
    case "C":
        s.x = Math.min(this.cols - 1, s.x + this.param(0, 1));
        s.pending = false;
        break;
    case "D":
        s.x = Math.max(0, s.x - this.param(0, 1));
        s.pending = false;
        break;
    case "E":
        s.x = 0;
        s.y = Math.min(s.bottom, s.y + this.param(0, 1));
        break;
    case "F":
        s.x = 0;
        s.y = Math.max(s.top, s.y - this.param(0, 1));
        break;
    case "G":
    case "`":
        s.x = Math.max(0, Math.min(this.cols - 1, this.param(0, 1) - 1));
        s.pending = false;
        break;
    case "H":
    case "f":
        s.y = Math.max(0, Math.min(this.rows - 1, this.param(0, 1) - 1));
        s.x = Math.max(0, Math.min(this.cols - 1, this.param(1, 1) - 1));
        s.pending = false;
        break;
    case "I":
        n = this.param(0, 1);
        for (i = 0; i < n; i++)
            this.control(0x09);
        break;
    case "J":
        n = this.param(0, 0);
        if (n === 0) {
            this.eraseCells(s.y, s.x, this.cols - 1);
            for (i = s.y + 1; i < this.rows; i++)
                this.eraseCells(i, 0, this.cols - 1);
        } else if (n === 1) {
            this.eraseCells(s.y, 0, s.x);
            for (i = 0; i < s.y; i++)
                this.eraseCells(i, 0, this.cols - 1);
        } else {

            if (n === 3)
                this.scrollback = [];
            for (i = 0; i < this.rows; i++)
                this.eraseCells(i, 0, this.cols - 1);
        }
        break;
    case "K":
        n = this.param(0, 0);
        if (n === 0)
            this.eraseCells(s.y, s.x, this.cols - 1);
        else if (n === 1)
            this.eraseCells(s.y, 0, s.x);
        else
            this.eraseCells(s.y, 0, this.cols - 1);
        break;
    case "L":
        n = this.param(0, 1);
        if (s.y >= s.top && s.y <= s.bottom)
            for (i = 0; i < n; i++) {
                s.lines.splice(s.bottom, 1);
                s.lines.splice(s.y, 0, blankRow(this.cols));
            }
        break;
    case "M":
        n = this.param(0, 1);
        if (s.y >= s.top && s.y <= s.bottom)
            for (i = 0; i < n; i++) {
                s.lines.splice(s.y, 1);
                s.lines.splice(s.bottom, 0, blankRow(this.cols));
            }
        break;
    case "P":
        n = this.param(0, 1);
        for (i = 0; i < n; i++) {
            s.lines[s.y].splice(s.x, 1);
            s.lines[s.y].push(blankCell());
        }
        break;
    case "S":
        this.scrollUp(this.param(0, 1));
        break;
    case "T":
        this.scrollDown(this.param(0, 1));
        break;
    case "X":
        n = this.param(0, 1);
        this.eraseCells(s.y, s.x, s.x + n - 1);
        break;
    case "Z":
        n = this.param(0, 1);
        for (i = 0; i < n; i++) {
            var prev = s.x - 1;
            while (prev > 0 && !this.tabs[prev])
                prev--;
            s.x = Math.max(0, prev);
        }
        break;
    case "d":
        s.y = Math.max(0, Math.min(this.rows - 1, this.param(0, 1) - 1));
        break;
    case "h":
        this.mode(true);
        break;
    case "l":
        this.mode(false);
        break;
    case "m":
        this.sgr();
        break;
    case "n":

        if (this.param(0, 0) === 6)
            this.reply += "\x1b[" + (s.y + 1) + ";" + (s.x + 1) + "R";
        else if (this.param(0, 0) === 5)
            this.reply += "\x1b[0n";
        break;
    case "r":
        var top = this.param(0, 1) - 1;
        var bottom = this.param(1, this.rows) - 1;
        if (top < bottom && bottom < this.rows) {
            s.top = Math.max(0, top);
            s.bottom = bottom;
            s.x = 0;
            s.y = s.top;
        }
        break;
    case "s":
        this.saved = {x: s.x, y: s.y, fg: this.fg, bg: this.bg, attrs: this.attrs};
        break;
    case "u":
        if (this.saved) {
            s.x = this.saved.x;
            s.y = this.saved.y;
            this.clampCursor();
        }
        break;
    case "c":

        this.reply += this.intermediate === ">" ? "\x1b[>0;95;0c" : "\x1b[?1;2c";
        break;
    }
};

Terminal.prototype.mode = function (on) {
    var priv = this.intermediate.indexOf("?") >= 0;

    for (var i = 0; i < this.params.length; i++) {
        var p = this.params[i];
        if (!priv) {
            continue;
        }
        switch (p) {
        case 1:
            this.appCursor = on;
            break;
        case 7:
            this.autowrap = on;
            break;
        case 25:
            this.cursorVisible = on;
            break;
        case 1000:
        case 1002:
        case 1003:
            this.mouse = on ? p : 0;
            break;
        case 1006:
            this.mouseSgr = on;
            break;
        case 2004:
            this.bracketedPaste = on;
            break;
        case 47:
        case 1047:
        case 1049:
            this.switchScreen(on, p === 1049);
            break;
        }
    }
};

Terminal.prototype.switchScreen = function (toAlt, saveCursor) {
    if (toAlt === this.altActive)
        return;

    var s = this.screen;
    if (toAlt) {
        if (saveCursor)
            this.saved = {x: s.x, y: s.y, fg: this.fg, bg: this.bg, attrs: this.attrs};
        this.alt = new Screen(this.cols, this.rows);
        this.screen = this.alt;
        this.altActive = true;
    } else {
        this.screen = this.main;
        this.altActive = false;
        if (saveCursor && this.saved) {
            this.main.x = this.saved.x;
            this.main.y = this.saved.y;
            this.fg = this.saved.fg;
            this.bg = this.saved.bg;
            this.attrs = this.saved.attrs;
            this.clampCursor();
        }
    }
};

Terminal.prototype.sgr = function () {
    var p = this.params;
    if (p.length === 0 || p.length === 1 && p[0] === -1) {
        this.fg = null;
        this.bg = null;
        this.attrs = 0;
        return;
    }

    for (var i = 0; i < p.length; i++) {
        var v = p[i] === -1 ? 0 : p[i];

        if (v === 0) {
            this.fg = null;
            this.bg = null;
            this.attrs = 0;
        } else if (v === 1) this.attrs |= BOLD;
        else if (v === 2) this.attrs |= DIM;
        else if (v === 3) this.attrs |= ITALIC;
        else if (v === 4) this.attrs |= UNDERLINE;
        else if (v === 5 || v === 6) this.attrs |= BLINK;
        else if (v === 7) this.attrs |= REVERSE;
        else if (v === 8) this.attrs |= HIDDEN;
        else if (v === 9) this.attrs |= STRIKE;
        else if (v === 21 || v === 22) this.attrs &= ~(BOLD | DIM);
        else if (v === 23) this.attrs &= ~ITALIC;
        else if (v === 24) this.attrs &= ~UNDERLINE;
        else if (v === 25) this.attrs &= ~BLINK;
        else if (v === 27) this.attrs &= ~REVERSE;
        else if (v === 28) this.attrs &= ~HIDDEN;
        else if (v === 29) this.attrs &= ~STRIKE;
        else if (v >= 30 && v <= 37) this.fg = v - 30;
        else if (v === 39) this.fg = null;
        else if (v >= 40 && v <= 47) this.bg = v - 40;
        else if (v === 49) this.bg = null;
        else if (v >= 90 && v <= 97) this.fg = v - 90 + 8;
        else if (v >= 100 && v <= 107) this.bg = v - 100 + 8;
        else if (v === 38 || v === 48) {

            var kind = p[i + 1];
            var colour = null;
            if (kind === 5) {
                colour = p[i + 2];
                i += 2;
            } else if (kind === 2) {
                colour = "#" + hex2(p[i + 2]) + hex2(p[i + 3]) + hex2(p[i + 4]);
                i += 4;
            }
            if (colour !== null) {
                if (v === 38)
                    this.fg = colour;
                else
                    this.bg = colour;
            }
        }
    }
};

Terminal.prototype.endString = function () {
    var body = this.stringBuf;
    this.stringBuf = "";
    this.state = "ground";

    if (this.stringKind !== "]")
        return;

    var split = body.indexOf(";");
    var code = parseInt(split < 0 ? body : body.slice(0, split), 10);
    var arg = split < 0 ? "" : body.slice(split + 1);

    if (code === 0 || code === 2)
        this.title = arg;
    else if (code === 7)

        this.cwd = decodeURIComponent(arg.replace(/^file:\/\/[^/]*/, ""));
    else if ((code === 10 || code === 11) && arg.indexOf("?") === 0)

        this.reply += "\x1b]" + code + ";" + (code === 10 ? this.fgQuery : this.bgQuery) + "\x1b\\";
};

Terminal.prototype.reset = function () {
    this.main = new Screen(this.cols, this.rows);
    this.alt = new Screen(this.cols, this.rows);
    this.screen = this.main;
    this.altActive = false;
    this.fg = null;
    this.bg = null;
    this.attrs = 0;
    this.cursorVisible = true;
    this.appCursor = false;
    this.autowrap = true;
    this.charsets = ["B", "B"];
    this.charset = 0;
    this.touch();
};

Terminal.prototype.takeReply = function () {
    var r = this.reply;
    this.reply = "";
    return r;
};

Terminal.prototype.cursorRow = function (offset) {
    return this.screen.y + Math.min(offset || 0, this.scrollback.length);
};

function create(cols, rows, opts) {
    return new Terminal(cols, rows, opts);
}

Terminal.prototype.mouseSequence = function (button, col, row, pressed, mods, motion) {
    if (!this.mouse)
        return "";
    if (motion && this.mouse === 1000)
        return "";
    if (motion && this.mouse === 1002 && button < 0)
        return "";

    var code = button < 0 ? 3 : button;
    if (mods) {
        if (mods.shift)
            code += 4;
        if (mods.alt)
            code += 8;
        if (mods.ctrl)
            code += 16;
    }
    if (motion)
        code += 32;

    var x = Math.max(1, Math.min(this.cols, col + 1));
    var y = Math.max(1, Math.min(this.rows, row + 1));

    if (this.mouseSgr)
        return "\x1b[<" + code + ";" + x + ";" + y + (pressed ? "M" : "m");

    if (x > 223 || y > 223)
        return "";
    var legacy = pressed ? code : 3;
    return "\x1b[M" + String.fromCharCode(32 + legacy, 32 + x, 32 + y);
};

Terminal.prototype.wheelSequence = function (up, col, row, mods) {
    if (!this.mouse)
        return "";
    return this.mouseSequence(up ? 64 : 65, col, row, true, mods, false);
};

function modCode(shift, alt, ctrl) {
    return 1 + (shift ? 1 : 0) + (alt ? 2 : 0) + (ctrl ? 4 : 0);
}

var CURSOR_KEYS = {up: "A", down: "B", right: "C", left: "D", end: "F", home: "H"};
var TILDE_KEYS = {insert: 2, "delete": 3, pageup: 5, pagedown: 6};
var FUNCTION_KEYS = {f1: "P", f2: "Q", f3: "R", f4: "S"};
var FUNCTION_TILDE = {f5: 15, f6: 17, f7: 18, f8: 19, f9: 20, f10: 21, f11: 23, f12: 24};

function keySequence(name, shift, alt, ctrl, appCursor) {
    var mod = modCode(shift, alt, ctrl);

    if (CURSOR_KEYS[name]) {
        var letter = CURSOR_KEYS[name];
        if (mod > 1)
            return "\x1b[1;" + mod + letter;
        return (appCursor ? "\x1bO" : "\x1b[") + letter;
    }

    if (TILDE_KEYS[name])
        return "\x1b[" + TILDE_KEYS[name] + (mod > 1 ? ";" + mod : "") + "~";

    if (FUNCTION_KEYS[name])
        return mod > 1 ? "\x1b[1;" + mod + FUNCTION_KEYS[name] : "\x1bO" + FUNCTION_KEYS[name];

    if (FUNCTION_TILDE[name])
        return "\x1b[" + FUNCTION_TILDE[name] + (mod > 1 ? ";" + mod : "") + "~";

    switch (name) {
    case "return":
    case "enter":

        return "\r";
    case "backspace":

        return ctrl ? "\x08" : "\x7f";
    case "tab":
        return shift ? "\x1b[Z" : "\t";
    case "escape":
        return "\x1b";
    case "space":
        return ctrl ? "\x00" : " ";
    }

    return "";
}

function textSequence(text, alt, ctrl) {
    if (!text)
        return "";

    var out = text;
    if (ctrl) {
        var c = text.charCodeAt(0);
        var upper = c >= 97 && c <= 122 ? c - 32 : c;
        if (upper >= 64 && upper <= 95)
            out = String.fromCharCode(upper - 64);
        else if (c === 63)
            out = "\x7f";
        else if (c >= 50 && c <= 56)

            out = String.fromCharCode([0, 27, 28, 29, 30, 31, 127][c - 50]);
    }

    return alt ? "\x1b" + out : out;
}

function pasteSequence(text, bracketed) {
    var body = text.replace(/\r\n/g, "\r").replace(/\n/g, "\r");
    return bracketed ? "\x1b[200~" + body + "\x1b[201~" : body;
}
