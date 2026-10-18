import qs.services
import qs.modules.panel

PanelIpc {
    target: "clipboard"

    function list(): string {
        const rows = Clipboard.entries.map((e, i) => {
            const what = Clipboard.summarise(e).replace(/\s+/g, " ").trim();
            return `${i}\t${e.pinned ? "*" : " "}\t${e.kind}\t${what.slice(0, 120)}`;
        });
        return rows.join("\n");
    }

    function use(index: string): string {
        const at = parseInt(index, 10);
        const entry = Clipboard.entries[at];
        if (!entry)
            return `no entry ${index}`;
        Clipboard.copy(entry);
        return `copied ${entry.kind}: ${Clipboard.summarise(entry).slice(0, 80)}`;
    }

    function pin(index: string): string {
        const at = parseInt(index, 10);
        const entry = Clipboard.entries[at];
        if (!entry)
            return `no entry ${index}`;
        Clipboard.setPinned(entry, !entry.pinned);
        return entry.pinned ? "let go" : "kept";
    }

    function remove(index: string): string {
        const at = parseInt(index, 10);
        const entry = Clipboard.entries[at];
        if (!entry)
            return `no entry ${index}`;
        Clipboard.remove(entry);
        return "removed";
    }

    function clear(): string {
        const before = Clipboard.entries.length;
        Clipboard.clear();
        return `cleared ${before - Clipboard.entries.length}, kept ${Clipboard.entries.length}`;
    }

    function status(): string {
        const win = Shell.showing(w => w.clipboard.open);
        const kinds = {};
        for (const e of Clipboard.entries)
            kinds[e.kind] = (kinds[e.kind] ?? 0) + 1;
        const tally = Object.keys(kinds).sort().map(k => `${k}=${kinds[k]}`).join(" ");
        return `recording=${Clipboard.recording} entries=${Clipboard.entries.length} pinned=${Clipboard.entries.filter(e => e.pinned).length} open=${win?.clipboard.open ?? false} ${tally}`;
    }
}
