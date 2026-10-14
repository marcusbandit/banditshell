pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "desktop-entries.js" as Entries

Singleton {
    id: root

    readonly property string scanScript: `IFS=:; for d in "\${XDG_DATA_HOME:-$HOME/.local/share}" \${XDG_DATA_DIRS:-/usr/local/share:/usr/share}; do awk 'FNR==1 { n = split(FILENAME, p, "/"); print "@@@" p[n] } /^(\\[|Name=|NoDisplay=|Hidden=|OnlyShowIn=|NotShowIn=|MimeType=|Categories=|Icon=|Exec=|TryExec=|Terminal=|Type=)/' "$d"/applications/*.desktop 2>/dev/null; done`

    property var entries: []
    property bool loaded: false

    readonly property var byId: {
        const out = {};
        for (const entry of root.entries)
            out[entry.id] = entry;
        return out;
    }

    readonly property var byProgram: Entries.indexPrograms(root.entries)

    function entryFor(id: string): var {
        const name = String(id ?? "");
        return root.byId[name] ?? root.byId[`${name}.desktop`] ?? null;
    }

    function forCommand(command: string): var {
        return root.byProgram[Entries.programOf(command)] ?? null;
    }

    function nameFor(id: string): string {
        const entry = root.entryFor(id);
        return entry?.name || String(id ?? "").replace(/\.desktop$/, "");
    }

    function markFor(id: string): string {
        return root.markForIcon(root.entryFor(id)?.icon ?? "", id);
    }

    function markForIcon(icon: string, id: string): string {
        const base = String(id ?? "").replace(/\.desktop$/, "");
        const picked = AppIcons.markFor(base, "colour");
        if (picked)
            return picked;
        const art = icon ? Quickshell.iconPath(icon, true) : "";
        return art ? `image:${art}` : `symbol:${Apps.iconFor(base)}`;
    }

    function read(text: string): void {
        root.entries = Entries.indexEntries(Entries.parseBundle(text));
        root.loaded = true;
    }

    Process {
        command: ["sh", "-c", root.scanScript]
        running: true

        stdout: StdioCollector {
            onStreamFinished: root.read(text)
        }
    }
}
