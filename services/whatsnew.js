// services/whatsnew.js: the What's new log, as data.
//
// docs/whats-new.json is one entry per push, newest first, written for the
// RECIPIENT of an update (the rule is docs/agents/whats-new.md). This file
// parses that log and answers the one question the shell asks of it: given
// what the user has already been shown, what has accumulated since?
//
// NO QML IN HERE, the way hyprgen.js has none: the logic is testable and the
// card is not. What is checked in tests/whatsnew.test.js is the behaviour
// that breaks SILENTLY - an accumulation that stops at the wrong entry shows
// the user the same card every launch or never announces a push at all, and
// neither of those throws anything.

// The five change types the rule hands out. The reader does not enforce them:
// a type the rule gains later must still reach the card, which draws a
// generic mark for anything it does not have a glyph for.
const TYPES = ["issues", "bugs", "features", "ui", "config"];

// One change line. Malformed ones are DROPPED rather than repaired: a line
// with no text has nothing to say, and inventing a type for one would be a
// fact the writer never stated. Severity is the rule's own guarded axis, so
// an unknown severity reads Minor - the failure direction for that axis is
// inflation, never understatement.
function change(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    if (typeof raw.text !== "string" || !raw.text.trim())
        return null;
    return {
        type: typeof raw.type === "string" ? raw.type : "",
        severity: raw.severity === "major" ? "major" : "minor",
        text: raw.text.trim()
    };
}

// One entry. The id is the only REQUIRED field: it is the marker's waypoint,
// so an entry with no id cannot be accumulated against even if its prose is
// fine. An entry whose changes are unreadable is still kept - it carries a
// version the marker may name - and `accumulated` simply never shows it.
function entry(raw) {
    if (!raw || typeof raw !== "object")
        return null;
    if (typeof raw.id !== "string" || !raw.id.trim())
        return null;
    return {
        id: raw.id.trim(),
        date: typeof raw.date === "string" ? raw.date.trim() : "",
        example: raw.example === true,
        changes: Array.isArray(raw.changes) ? raw.changes.map(change).filter(c => c) : []
    };
}

// The file as entries, newest first, in the order written. Both the shipped
// shape ({"entries": [...]}) and a bare array are accepted, because a log
// whose top level grew a wrapper must not take every old checkout's card
// down with it. Anything else - not JSON, not a list - is an empty log,
// which is the correct answer for "no news".
function parse(text) {
    let doc;
    try {
        doc = JSON.parse(String(text ?? ""));
    } catch (e) {
        return [];
    }
    const list = Array.isArray(doc) ? doc : Array.isArray(doc?.entries) ? doc.entries : null;
    if (!list)
        return [];
    return list.map(entry).filter(e => e);
}

// WHAT THIS USER HAS NOT BEEN SHOWN: every non-example entry newer than the
// marker, newest first, skipping entries with nothing readable to show.
//
// The file order IS the order: entries are appended at push time and never
// reordered, so "newer than the marker" is a walk from the top that stops at
// the entry the marker names. A marker that is empty or no longer in the
// file stops nowhere and shows everything - the marker's entry can be gone
// because the log was trimmed under it (trimmed entries are the oldest, so
// everything still in the file is newer than it) or because no card was ever
// shown, and in both cases the whole log is genuinely unseen. An entry the
// marker names is a waypoint, not content: the walk stops there whether it
// has changes or not.
function accumulated(entries, seen) {
    const mark = String(seen ?? "");
    const out = [];
    for (const e of entries) {
        if (e.example || !e.changes.length)
            continue;
        if (mark && e.id === mark)
            break;
        out.push(e);
    }
    return out;
}

// An entry is Major when any of its changes is: the classification belongs
// to the change ("you must do this"), and the entry inherits the strongest
// thing said in it.
function severityOf(e) {
    return e && e.changes.some(c => c.severity === "major") ? "major" : "minor";
}
