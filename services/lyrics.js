.pragma library

const invisible = new RegExp(`[${String.fromCharCode(0x200b, 0x200c, 0x200d, 0x2060, 0xfeff)}]`, "g");
const trailing = /^[,.;:!?'"’”…-]+$/;

const breakAfterTimed = 3;
const breakAfterGuess = 4.5;

function clean(text) {
    return String(text ?? "").replace(invisible, "").replace(/\s+/g, " ").trim();
}

function stamp(text) {
    const parts = String(text).trim().split(":");
    if (parts.length < 2 || parts.length > 3)
        return NaN;
    let seconds = 0;
    for (const part of parts) {
        if (!/^\d+(\.\d+)?$/.test(part))
            return NaN;
        seconds = seconds * 60 + parseFloat(part);
    }
    return seconds;
}

function pieces(body, lineStart) {
    const tag = /<(\d+:\d+(?::\d+)?(?:\.\d+)?)>/g;
    if (!tag.test(body))
        return null;
    tag.lastIndex = 0;

    const out = [];
    let at = lineStart;
    let last = 0;
    let match;
    while ((match = tag.exec(body)) !== null) {
        const before = body.slice(last, match.index);
        if (before.trim() !== "")
            out.push({ start: at, text: before });
        at = stamp(match[1]);
        last = tag.lastIndex;
    }
    const tail = body.slice(last);
    const closed = tail.trim() === "";
    if (!closed)
        out.push({ start: at, text: tail });

    for (let i = 0; i < out.length; i++) {
        const next = out[i + 1];
        out[i].end = next ? next.start : closed && at > out[i].start ? at : NaN;
        out[i].joins = !!next && !/\s$/.test(out[i].text) && !/^\s/.test(next.text);
    }
    return out.length > 0 ? out : null;
}

function parseLrc(text) {
    const lines = [];
    let offset = 0;
    const leading = /^\[([^\]]*)\]/;

    for (const raw of String(text ?? "").split(/\r?\n/)) {
        let rest = raw.trim();
        const starts = [];
        let match;
        while ((match = leading.exec(rest)) !== null) {
            const inside = match[1];
            const at = stamp(inside);
            if (isFinite(at))
                starts.push(at);
            else {
                const meta = /^offset:\s*([+-]?\d+)$/i.exec(inside.trim());
                if (meta)
                    offset = parseInt(meta[1], 10) / 1000;
            }
            rest = rest.slice(match[0].length);
        }
        if (starts.length === 0)
            continue;

        for (const start of starts) {
            const timed = pieces(rest, start);
            lines.push({
                start: start,
                text: clean(timed ? timed.map(p => p.text).join("") : rest),
                pieces: timed
            });
        }
    }

    for (const line of lines) {
        line.start = Math.max(0, line.start - offset);
        for (const p of line.pieces ?? []) {
            p.start = Math.max(0, p.start - offset);
            if (isFinite(p.end))
                p.end = Math.max(0, p.end - offset);
        }
    }

    lines.sort((a, b) => a.start - b.start);
    return lines;
}

function group(syllables) {
    const words = [];
    let current = null;
    for (const s of syllables) {
        const text = clean(s.text);
        if (text !== "") {
            if (!current)
                current = { text: "", start: s.start, end: s.end, parts: [] };
            current.text += text;
            current.parts.push({ size: text.length, start: s.start, end: s.end });
            current.end = s.end;
        }
        if (current && !s.joins) {
            words.push(current);
            current = null;
        }
    }
    if (current)
        words.push(current);
    return words;
}

function plainWords(text) {
    return clean(text).split(" ").filter(t => t !== "").map(t => ({
        text: t,
        start: NaN,
        end: NaN,
        parts: null
    }));
}

function sungFor(chars, slot) {
    const natural = 0.5 + chars / 13;
    if (!(slot > 0) || !isFinite(slot))
        return natural;
    if (slot <= natural * 1.5)
        return slot * 0.94;
    return Math.min(slot * 0.9, natural * 1.35);
}

function pace(words, start, end) {
    const weight = words.reduce((n, w) => n + w.text.length + 1, 0);
    let at = start;
    for (const w of words) {
        const span = weight > 0 ? (end - start) * (w.text.length + 1) / weight : 0;
        w.start = at;
        w.end = at + span;
        at += span;
    }
    return words;
}

function trimWord(word, left, right) {
    const text = word.text.slice(left, word.text.length - right);
    if (!word.parts)
        return { text: text, start: word.start, end: word.end, parts: null };

    const parts = word.parts.map(p => ({ size: p.size, start: p.start, end: p.end }));
    let l = left;
    while (l > 0 && parts.length > 0) {
        const take = Math.min(l, parts[0].size);
        parts[0].size -= take;
        l -= take;
        if (parts[0].size === 0)
            parts.shift();
    }
    let r = right;
    while (r > 0 && parts.length > 0) {
        const last = parts[parts.length - 1];
        const take = Math.min(r, last.size);
        last.size -= take;
        r -= take;
        if (last.size === 0)
            parts.pop();
    }
    if (parts.length === 0)
        return { text: text, start: word.start, end: word.end, parts: null };
    return { text: text, start: parts[0].start, end: parts[parts.length - 1].end, parts: parts };
}

function extend(word, tail) {
    word.text += tail;
    if (word.parts)
        word.parts[word.parts.length - 1].size += tail.length;
}

function separate(words) {
    const lead = [];
    const back = [];
    let inside = false;

    for (const original of words) {
        let w = original;
        if (!inside && w.text.startsWith("(")) {
            inside = true;
            w = trimWord(w, 1, 0);
        }
        if (!inside) {
            lead.push(w);
            continue;
        }
        const close = w.text.indexOf(")");
        if (close < 0) {
            if (w.text !== "")
                back.push(w);
            continue;
        }
        inside = false;
        const inner = trimWord(w, 0, w.text.length - close);
        if (inner.text !== "")
            back.push(inner);
        const tail = w.text.slice(close + 1);
        if (tail === "")
            continue;
        if (trailing.test(tail)) {
            if (lead.length > 0)
                extend(lead[lead.length - 1], tail);
        } else
            lead.push(trimWord(w, close + 1, 0));
    }

    back.sort((a, b) => a.start - b.start);
    return { lead: lead, back: back };
}

function textOf(words) {
    return words.map(w => w.text).join(" ");
}

function line(start, end, side, words, background, timed, exact) {
    const parts = separate(words);
    const back = parts.back.concat(background ?? []).sort((a, b) => a.start - b.start);
    const all = parts.lead.concat(back);
    const first = all.length > 0 ? Math.min(start, ...all.map(w => w.start)) : start;
    const last = all.length > 0 ? Math.max(end, ...all.map(w => w.end)) : end;
    return {
        start: first,
        end: last,
        gap: false,
        side: side,
        lead: parts.lead,
        back: back,
        timed: timed,
        exact: exact,
        text: textOf(parts.lead) || textOf(back)
    };
}

function gap(start, end, side) {
    return {
        start: start,
        end: end,
        gap: true,
        side: side,
        lead: [],
        back: [],
        timed: true,
        exact: true,
        text: ""
    };
}

function interludes(lines, length) {
    lines.sort((a, b) => a.start - b.start);
    const out = [];
    if (lines.length > 0 && lines[0].start >= breakAfterTimed)
        out.push(gap(0, lines[0].start, lines[0].side));
    for (let i = 0; i < lines.length; i++) {
        const current = lines[i];
        out.push(current);
        const next = lines[i + 1];
        if (!next)
            break;
        const reach = Math.max(...lines.slice(0, i + 1).map(l => l.end));
        const needed = current.timed || current.exact ? breakAfterTimed : breakAfterGuess;
        if (next.start - reach >= needed)
            out.push(gap(reach, next.start, next.side));
    }
    return out;
}

function fromLrc(entries, length) {
    const lines = [];
    const total = length > 0 ? length : Infinity;
    for (let i = 0; i < entries.length; i++) {
        const entry = entries[i];
        if (entry.text === "")
            continue;
        const next = entries[i + 1];
        const nextStart = next ? next.start : total;
        const marked = !!next && next.text === "";

        if (entry.pieces) {
            const words = group(entry.pieces.map(p => ({
                text: p.text,
                start: p.start,
                end: isFinite(p.end) ? p.end : Math.min(nextStart, p.start + Math.max(0.4, clean(p.text).length * 0.08)),
                joins: p.joins
            })));
            const end = words.length > 0 ? words[words.length - 1].end : entry.start;
            lines.push(line(entry.start, end, "left", words, [], true, true));
            continue;
        }

        const words = plainWords(entry.text);
        const chars = words.reduce((n, w) => n + w.text.length, 0);
        const sung = sungFor(chars, nextStart - entry.start);
        pace(words, entry.start, entry.start + sung);
        lines.push(line(entry.start, entry.start + sung, "left", words, [], false, marked));
    }
    return interludes(lines, length);
}

function syllablesOf(list) {
    return (list ?? []).map(s => ({
        text: s.Text ?? "",
        start: Number(s.StartTime),
        end: Number(s.EndTime),
        joins: !!s.IsPartOfWord
    }));
}

function writersOf(content) {
    return (Array.isArray(content.SongWriters) ? content.SongWriters : []).map(clean).filter(w => w !== "");
}

function fromSpicy(content, length) {
    if (!content || typeof content !== "object")
        return null;

    if (content.Type === "Static")
        return { plain: (content.Lines ?? []).map(l => clean(l.Text)), writers: writersOf(content) };

    const vocals = (content.Content ?? []).filter(v => v && v.Type !== "Instrumental");

    if (content.Type === "Syllable") {
        const lines = [];
        for (const v of vocals) {
            const lead = group(syllablesOf(v.Lead?.Syllables));
            const back = [];
            for (const b of v.Background ?? [])
                back.push(...group(syllablesOf(b.Syllables)));
            if (lead.length === 0 && back.length === 0)
                continue;
            const start = Number(v.Lead?.StartTime ?? back[0]?.start ?? 0);
            const end = Number(v.Lead?.EndTime ?? start);
            lines.push(line(start, end, v.OppositeAligned ? "right" : "left", lead, back, true, true));
        }
        return lines.length > 0 ? { synced: interludes(lines, length), writers: writersOf(content) } : null;
    }

    if (content.Type === "Line") {
        const lines = [];
        const total = length > 0 ? length : Infinity;
        for (let i = 0; i < vocals.length; i++) {
            const v = vocals[i];
            const words = plainWords(v.Text);
            if (words.length === 0)
                continue;
            const start = Number(v.StartTime);
            const nextStart = vocals[i + 1] ? Number(vocals[i + 1].StartTime) : total;
            const end = Number(v.EndTime);
            const exact = isFinite(end) && end > start && end < nextStart - 0.3;
            const chars = words.reduce((n, w) => n + w.text.length, 0);
            const sung = exact ? end - start : sungFor(chars, nextStart - start);
            pace(words, start, start + sung);
            lines.push(line(start, start + sung, v.OppositeAligned ? "right" : "left", words, [], false, exact));
        }
        return lines.length > 0 ? { synced: interludes(lines, length), writers: writersOf(content) } : null;
    }

    return null;
}

function plain(text) {
    return String(text ?? "").split(/\r?\n/).map(clean);
}

function lineAt(lines, t) {
    let lo = 0;
    let hi = lines.length - 1;
    let found = -1;
    while (lo <= hi) {
        const mid = (lo + hi) >> 1;
        if (lines[mid].start <= t) {
            found = mid;
            lo = mid + 1;
        } else
            hi = mid - 1;
    }
    return found;
}

function wordFill(word, t) {
    if (t <= word.start)
        return 0;
    if (t >= word.end)
        return 1;
    if (!word.parts)
        return (t - word.start) / Math.max(0.001, word.end - word.start);
    let lit = 0;
    let size = 0;
    for (const p of word.parts) {
        size += p.size;
        if (t >= p.end)
            lit += p.size;
        else if (t > p.start)
            lit += p.size * (t - p.start) / Math.max(0.001, p.end - p.start);
    }
    return size > 0 ? lit / size : 1;
}

function progress(words, t) {
    for (let i = 0; i < words.length; i++) {
        const w = words[i];
        if (t >= w.end)
            continue;
        return i + wordFill(w, t);
    }
    return words.length;
}

function gapFill(entry, t) {
    const span = Math.max(0.001, entry.end - entry.start - 0.35);
    return Math.max(0, Math.min(1, (t - entry.start) / span));
}

function layout(widths, space, room) {
    const rows = [];
    let row = null;
    for (let i = 0; i < widths.length; i++) {
        const w = widths[i];
        if (!row || (row.width > 0 && row.width + space + w > room)) {
            row = { first: i, count: 0, width: 0, starts: [] };
            rows.push(row);
        }
        const x = row.count === 0 ? 0 : row.width + space;
        row.starts.push(x);
        row.width = x + w;
        row.count++;
    }
    return rows;
}

function litWidth(row, widths, position) {
    const local = position - row.first;
    if (local <= 0)
        return 0;
    if (local >= row.count)
        return row.width;
    const k = Math.floor(local);
    return row.starts[k] + widths[row.first + k] * (local - k);
}

function cleanTitle(title) {
    let t = String(title ?? "");
    t = t.replace(/\s*[\(\[](?:feat\.?|ft\.?|featuring|with)\s[^\)\]]*[\)\]]/gi, "");
    t = t.replace(/\s*[\(\[][^\)\]]*(?:remaster|version|edit|mix|live|mono|stereo|official|video|audio|lyrics?|explicit|clean|deluxe|bonus)[^\)\]]*[\)\]]/gi, "");
    t = t.replace(/\s+-\s+(?:.*(?:remaster|version|edit|mix|live|mono|stereo|from|single|bonus|acoustic|demo)).*$/i, "");
    return t.replace(/\s+/g, " ").trim() || String(title ?? "").trim();
}

function firstArtist(artist) {
    return String(artist ?? "").split(/\s*(?:,|&|\sx\s|\sfeat\.?\s|\sft\.?\s|;)\s*/i)[0].trim();
}

const marks = new RegExp(`[${String.fromCharCode(0x300)}-${String.fromCharCode(0x36f)}]`, "g");
const punctuation = new RegExp(`[\\s!-/:-@\\[-\x60{-~${String.fromCharCode(0x2018, 0x2019, 0x201c, 0x201d, 0x2013, 0x2014, 0xa1, 0xbf)}]+`, "g");

function fold(text) {
    return String(text ?? "").toLowerCase().normalize("NFKD").replace(marks, "").replace(punctuation, "");
}

function score(record, wanted) {
    if (!record || (!record.syncedLyrics && !record.plainLyrics && !record.instrumental))
        return -Infinity;

    let s = 0;

    if (wanted.length > 0 && record.duration > 0) {
        const off = Math.abs(record.duration - wanted.length);
        if (off > 5)
            return -Infinity;
        s -= off * 2;
    }

    const title = fold(cleanTitle(wanted.title));
    const theirs = fold(cleanTitle(record.trackName ?? record.name));
    if (title === "" || theirs === "")
        return -Infinity;
    if (theirs === title)
        s += 10;
    else if (theirs.includes(title) || title.includes(theirs))
        s += 4;
    else
        return -Infinity;

    const artist = fold(firstArtist(wanted.artist));
    const theirArtist = fold(record.artistName);
    if (artist !== "" && theirArtist !== "") {
        if (theirArtist.includes(artist) || artist.includes(theirArtist))
            s += 6;
        else
            s -= 8;
    }

    if (record.syncedLyrics)
        s += 12;
    if (wanted.album && fold(record.albumName) === fold(wanted.album))
        s += 2;

    return s;
}

function pick(records, wanted) {
    let best = null;
    let bestScore = -Infinity;
    for (const record of records ?? []) {
        const s = score(record, wanted);
        if (s > bestScore) {
            best = record;
            bestScore = s;
        }
    }
    return bestScore > 0 ? best : null;
}

function query(params) {
    return Object.keys(params).filter(k => params[k] !== undefined && params[k] !== "" && params[k] !== null).map(k => `${k}=${encodeURIComponent(params[k])}`).join("&");
}
