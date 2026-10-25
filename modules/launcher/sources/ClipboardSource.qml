import QtQuick
import qs.config
import qs.services
import "../../../services/clipboard-search.js" as ClipboardSearch

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["clipboard", "clipboardclear"]

    readonly property var asked: ClipboardSearch.ask(root.search.text)
    readonly property bool explicit: root.asked.explicit

    readonly property bool listening: root.explicit || Config.values.launcher.typing.clipboard

    readonly property bool active: root.listening && root.search.text.length > 0

    readonly property var indexed: root.active ? ClipboardSearch.index(Clipboard.entries, e => Clipboard.summarise(e)) : []

    readonly property var found: root.active ? ClipboardSearch.find(root.indexed, root.asked.term, root.explicit, root.explicit ? 12 : 3) : []

    readonly property bool intent: root.explicit

    readonly property int clearable: Clipboard.unpinned

    readonly property bool offersClear: root.explicit && root.clearable > 0 && (root.asked.term === "" || "clear history".startsWith(root.asked.term.toLowerCase()))

    readonly property bool clearing: root.search.armed === "clipboardclear"

    readonly property var groups: [
        {
            key: "clipboard",
            title: "Clipboard",
            items: root.offersClear && root.asked.term !== "" ? [root.clearRow()].concat(root.found.map(entry => root.row(entry))) : root.found.map(entry => root.row(entry)).concat(root.offersClear ? [root.clearRow()] : [])
        }
    ]

    readonly property var phrases: [
        {
            head: "clip ",
            picks: [""]
        }
    ]

    function row(entry: var): var {
        const picture = entry.kind === "image" && !!entry.file;
        const parts = [];
        if (entry.pinned)
            parts.push("pinned");
        if (entry.kind !== "text")
            parts.push(entry.kind);
        const bytes = Clipboard.size(entry.bytes);
        if (bytes)
            parts.push(bytes);
        parts.push(Clipboard.age(entry.recorded));
        return {
            key: `clipboard:${entry.id}`,
            kind: "clipboard",
            entry: entry,
            going: root.clearing && !entry.pinned,
            label: picture ? entry.w > 0 ? `${entry.w} × ${entry.h}` : "Picture" : ClipboardSearch.firstLine(Clipboard.summarise(entry), 160),
            detail: parts.join(" · "),
            icon: Clipboard.markFor(entry.kind),
            iconSource: picture ? `file://${entry.file}` : "",
            score: root.explicit ? Infinity : 0.3
        };
    }

    function clearRow(): var {
        const pinned = Clipboard.entries.length - root.clearable;
        return {
            key: "clipboardclear",
            kind: "clipboardclear",
            armed: root.clearing,
            label: root.clearing ? `Enter clears ${root.clearable === 1 ? "1 item" : `${root.clearable} items`}` : "Clear history",
            detail: pinned > 0 ? `${pinned} pinned stay` : "",
            icon: "delete_sweep",
            score: Infinity
        };
    }

    function clear(): void {
        root.search.armed = "";
        Clipboard.clear();
    }

    function paste(row: var): void {
        const address = root.search.windowTarget();
        Clipboard.copy(row.entry);
        root.search.leave(() => Typist.paste(address));
    }

    function copy(row: var): void {
        const entry = row.entry;
        root.search.leave(() => Clipboard.copy(entry));
    }

    function activate(row: var): void {
        if (row.kind === "clipboardclear") {
            if (row.armed)
                root.clear();
            else
                root.search.armed = "clipboardclear";
            return;
        }
        if (Typist.found)
            root.paste(row);
        else
            root.copy(row);
    }

    function confirmActionsFor(row: var): var {
        return [
            {
                icon: "delete_sweep",
                label: "Clear",
                alarm: true,
                run: () => root.clear()
            }
        ];
    }

    function actionsFor(row: var): var {
        if (row.kind === "clipboardclear")
            return [
                {
                    icon: "delete_sweep",
                    label: "Clear history",
                    run: () => root.search.armed = "clipboardclear"
                }
            ];
        const typing = Typist.found;
        const acts = [
            {
                icon: typing ? "content_paste_go" : "content_copy",
                label: typing ? "Paste" : "Copy",
                run: () => root.activate(row)
            }
        ];
        if (typing)
            acts.push({
                icon: "content_copy",
                label: "Copy",
                run: () => root.copy(row)
            });
        acts.push({
            icon: "push_pin",
            fill: row.entry.pinned,
            label: row.entry.pinned ? "Unpin" : "Pin",
            run: () => Clipboard.setPinned(row.entry, !row.entry.pinned)
        }, {
            icon: "delete",
            label: "Delete",
            run: () => Clipboard.remove(row.entry)
        });
        if (!typing && Typist.probed)
            acts.push({
                icon: "download",
                label: Typist.installing === "trying" ? "Installing wtype" : "Install wtype to paste",
                tucked: true,
                run: () => Typist.install()
            });
        return acts;
    }
}
