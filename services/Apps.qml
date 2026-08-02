pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Installed applications, and how to find one by typing.
//
// The ranking is the whole service, and it is two independent things kept
// separate on purpose:
//
//   TIER: where the match landed. Substring matching alone puts "Disk Usage
//   Analyzer" above "Discord" for "disc", which makes a launcher feel broken
//   even though every result technically matches. The start of the name beats
//   the middle of the name, which beats the keywords, which beats the
//   description.
//
//   FRECENCY: what you actually use. Only ever a tiebreak WITHIN a tier, never
//   across one, because no amount of habit should make a worse match win. With
//   no query typed every candidate is the same tier, so the whole list is
//   ordered by what you reach for.
//
// They used to be added into one number, which meant the length penalty inside a
// tier silently outranked usage: an app you open daily lost to one with a name
// two letters shorter.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // Match tiers, high to low. Named rather than written as literals at the
    // comparison sites, so "does a keyword match beat a word-start match" is
    // answered by reading the list instead of by comparing two magic numbers.
    readonly property int tierExact: 6
    readonly property int tierPrefix: 5
    readonly property int tierWordStart: 4
    readonly property int tierAnywhere: 3
    readonly property int tierMeta: 2
    readonly property int tierComment: 1
    readonly property int tierSubsequence: 0
    readonly property int tierNone: -1

    function tier(entry: var, needle: string): int {
        if (!needle)
            return root.tierExact;

        const q = needle.toLowerCase();
        const name = (entry.name ?? "").toLowerCase();
        const generic = (entry.genericName ?? "").toLowerCase();
        const comment = (entry.comment ?? "").toLowerCase();
        const keywords = (entry.keywords ?? []).join(" ").toLowerCase();

        if (name === q)
            return root.tierExact;
        if (name.startsWith(q))
            return root.tierPrefix;
        if (new RegExp(`\\b${root.escapeRegex(q)}`).test(name))
            return root.tierWordStart;
        if (name.includes(q))
            return root.tierAnywhere;
        if (generic.includes(q) || keywords.includes(q))
            return root.tierMeta;
        if (comment.includes(q))
            return root.tierComment;

        // Subsequence, so "ff" finds Firefox. Last resort: it matches almost
        // everything, so it must never outrank a real match.
        return root.subsequence(name, q) ? root.tierSubsequence : root.tierNone;
    }

    function escapeRegex(s: string): string {
        return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    }

    function subsequence(haystack: string, needle: string): bool {
        let i = 0;
        for (const ch of haystack) {
            if (ch === needle[i])
                i++;
            if (i === needle.length)
                return true;
        }
        return false;
    }

    // Everything that matches, best first. NOT truncated: the list scrolls, and
    // a cap is the wrong answer to "there are a lot of results" when the top of
    // the list is already the answer you wanted.
    function search(needle: string): var {
        const now = Date.now();
        return root.all.map(e => ({
                    entry: e,
                    tier: root.tier(e, needle),
                    used: root.frecencyAt(e, now),
                    // Only while something is TYPED. Shorter is a better match
                    // for a query, and means nothing without one: with an empty
                    // box and no usage yet it sorted the whole menu by name
                    // length, so the launcher opened on "R".
                    length: needle ? (e.name ?? "").length : 0
                })).filter(r => r.tier > root.tierNone).sort((a, b) => b.tier - a.tier || b.used - a.used || a.length - b.length || (a.entry.name ?? "").localeCompare(b.entry.name ?? "")).map(r => r.entry);
    }

    function launch(entry: var): void {
        root.record(entry);
        // execute() handles the desktop-entry Exec field's own escaping and
        // field codes, which is a small horror worth not reimplementing.
        entry?.execute();
    }

    // What you actually use.
    //
    // FRECENCY, not a count. A thing opened forty times last year should not
    // outrank the one opened twice this week, and a pure count can never forget,
    // so a launcher tuned by a month of one project stays tuned to it forever.
    //
    // Each launch is worth 1 at the moment it happens and halves every
    // `halfLifeDays`. That needs no history: the stored score is decayed to now
    // before 1 is added, so one number per app carries the whole curve.
    readonly property real halfLifeDays: Config.values.launcher.halfLifeDays
    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/usage.json`

    property var usage: ({})

    function decay(fromMs: real, toMs: real): real {
        const days = Math.max(0, toMs - fromMs) / 86400000;
        return Math.pow(0.5, days / Math.max(root.halfLifeDays, 1 / 24));
    }

    function frecencyAt(entry: var, now: real): real {
        const rec = root.usage[entry?.id ?? ""];
        if (!rec)
            return 0;
        return rec.score * root.decay(rec.last, now);
    }

    function record(entry: var): void {
        const id = entry?.id;
        if (!id)
            return;

        const now = Date.now();
        const rec = root.usage[id];
        const next = {
            score: (rec ? rec.score * root.decay(rec.last, now) : 0) + 1,
            last: now
        };

        // A NEW object, not a mutated one. `usage` is a var property and QML
        // only notices assignment, so mutating it in place leaves every binding
        // that reads it showing the old order until something else happens to
        // invalidate them.
        root.usage = Object.assign({}, root.usage, {
            [id]: next
        });
        store.setText(JSON.stringify(root.usage));
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                root.usage = JSON.parse(text()) ?? {};
            } catch (e) {
                console.warn(`Apps: ${root.path} is not valid JSON, starting the usage record over.`, e);
                root.usage = {};
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    // First run: nothing to read, but the directory has to exist before the
    // first launch can write anything into it.
    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
    }
}
