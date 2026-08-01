pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Installed applications, and how to find one by typing.
//
// The ranking is the whole service. Substring matching puts "Disk Usage
// Analyzer" above "Discord" for "disc", which is wrong in a way that makes a
// launcher feel broken even though every result technically matches. So matches
// are SCORED, and where the match lands matters more than that it happened:
// the start of the name beats the middle of the name, which beats the keywords,
// which beats the description.
Singleton {
    id: root

    readonly property var all: DesktopEntries.applications.values.filter(e => !e.noDisplay)

    // How many to show. A launcher is for the one you meant, not for browsing.
    readonly property int maxResults: Config.values.launcher.maxResults

    function score(entry: var, needle: string): real {
        if (!needle)
            return 1;

        const q = needle.toLowerCase();
        const name = (entry.name ?? "").toLowerCase();
        const generic = (entry.genericName ?? "").toLowerCase();
        const comment = (entry.comment ?? "").toLowerCase();
        const keywords = (entry.keywords ?? []).join(" ").toLowerCase();

        // Exact, then prefix, then word-start, then anywhere. Each tier is far
        // enough above the next that a better KIND of match always wins,
        // regardless of how many worse ones a candidate stacks up.
        if (name === q)
            return 1000;
        if (name.startsWith(q))
            return 900 - name.length;
        if (new RegExp(`\\b${root.escapeRegex(q)}`).test(name))
            return 800 - name.length;
        if (name.includes(q))
            return 700 - name.length;
        if (generic.includes(q) || keywords.includes(q))
            return 500;
        if (comment.includes(q))
            return 300;

        // Subsequence, so "ff" finds Firefox. Last resort: it matches almost
        // everything, so it must never outrank a real one.
        return root.subsequence(name, q) ? 100 : 0;
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

    function search(needle: string): var {
        return root.all.map(e => ({
                    entry: e,
                    score: root.score(e, needle)
                })).filter(r => r.score > 0).sort((a, b) => b.score - a.score || (a.entry.name ?? "").localeCompare(b.entry.name ?? "")).slice(0, root.maxResults).map(r => r.entry);
    }

    function launch(entry: var): void {
        // execute() handles the desktop-entry Exec field's own escaping and
        // field codes, which is a small horror worth not reimplementing.
        entry?.execute();
    }
}
