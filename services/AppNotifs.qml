pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var byApp: {
        const out = {};
        for (const entry of Notifs.history) {
            if (entry.leaving)
                continue;
            const id = root.appIdFor(entry);
            if (!id)
                continue;
            if (!out[id])
                out[id] = [];
            out[id].push(entry);
        }
        return out;
    }

    function appIdFor(entry: var): string {
        for (const name of [entry?.desktopEntry, entry?.appName]) {
            if (!name)
                continue;
            for (const variant of Apps.nameVariants(name)) {
                if (!variant)
                    continue;
                const id = DesktopEntries.heuristicLookup(variant)?.id;
                if (id)
                    return id;
            }
        }
        return "";
    }

    function forId(id: string): var {
        return root.byApp[id] ?? [];
    }

    function forEntry(entry: var): var {
        return root.forId(entry?.id ?? "");
    }

    function countFor(entry: var): int {
        return root.forEntry(entry).length;
    }

    function newestFor(entry: var): var {
        return root.forEntry(entry)[0] ?? null;
    }

    function dismissFor(entry: var): void {
        for (const notif of root.forEntry(entry).slice())
            Notifs.dismiss(notif);
    }

    function countForAll(entries: var): int {
        let n = 0;
        for (const id of new Set(entries.map(e => e?.id ?? "")))
            n += root.forId(id).length;
        return n;
    }

    function dismissForAll(entries: var): void {
        for (const id of new Set(entries.map(e => e?.id ?? "")))
            for (const notif of root.forId(id).slice())
                Notifs.dismiss(notif);
    }
}
