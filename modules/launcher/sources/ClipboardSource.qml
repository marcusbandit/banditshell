import QtQuick
import qs.config
import qs.services
import "../../../services/clipboard-search.js" as ClipboardSearch

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["clipboard", "clipboardclear", "clipboardundo"]

    readonly property var asked: ClipboardSearch.ask(root.search.text)
    readonly property bool explicit: root.asked.explicit

    readonly property bool listening: root.explicit || Config.values.launcher.typing.clipboard

    readonly property bool active: root.listening && root.search.text.length > 0 && !root.paged

    readonly property var indexed: root.active ? ClipboardSearch.index(Clipboard.entries, e => Clipboard.summarise(e)) : []

    readonly property var found: root.active ? ClipboardSearch.find(root.indexed, root.asked.term, root.explicit, root.explicit ? 12 : 3) : []

    readonly property bool intent: root.explicit

    readonly property int clearable: Clipboard.unpinned

    readonly property bool offersClear: root.explicit && root.clearable > 0 && (root.asked.term === "" || "clear history".startsWith(root.asked.term.toLowerCase()))

    readonly property bool clearing: root.search.armed === "clipboardclear"

    readonly property string deleting: root.search.armed.startsWith("clipboarddelete:") ? root.search.armed.slice(16) : ""

    readonly property var prefixes: [
        {
            section: "Files and clipboard",
            word: "clip",
            example: "clip api key",
            about: "Clipboard history",
            icon: "content_paste",
            also: ["clips", "clipboard"]
        }
    ]

    readonly property bool offersUndo: root.explicit && Clipboard.shelved > 0 && (root.asked.term === "" || root.undoLabel.toLowerCase().startsWith(root.asked.term.toLowerCase()))

    readonly property bool undoingDelete: Clipboard.shelfKind === "delete"
    readonly property string undoLabel: root.undoingDelete ? "Undo delete" : "Undo clear"

    property string revealed: ""

    onActiveChanged: if (!root.active)
        root.revealed = ""

    readonly property bool paged: root.search.presents && root.explicit

    readonly property bool opening: root.paged && /^\s*\S+\s/.test(root.search.query)

    onOpeningChanged: if (root.opening && !root.search.presenting)
        Qt.callLater(root.openPage)

    readonly property Component page: Component {
        ClipboardPage {}
    }

    function openPage(): void {
        if (!root.search.presents || root.search.presenting)
            return;
        root.search.present({
            component: root.page,
            name: "clipboard",
            text: "Clipboard history",
            filters: true,
            placeholder: "Filter what you copied",
            filter: root.asked.term,
            restore: root.search.query.trim().split(/\s+/)[0] ?? "",
            source: root
        });
    }

    readonly property var rows: {
        if (root.paged)
            return root.offersUndo ? [root.undoRow()] : [];
        const rows = root.found.map(entry => root.row(entry));
        if (root.offersUndo)
            return [root.undoRow()].concat(rows);
        if (!root.offersClear)
            return rows;
        return root.asked.term !== "" ? [root.clearRow()].concat(rows) : rows.concat([root.clearRow()]);
    }

    readonly property var groups: [
        {
            key: "clipboard",
            title: "Clipboard",
            items: root.rows
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
        const secret = Clipboard.sensitive(entry);
        const masked = secret && root.revealed !== entry.id;
        const text = picture ? entry.w > 0 ? `${entry.w} × ${entry.h}` : "Picture" : ClipboardSearch.firstLine(Clipboard.summarise(entry), 160);
        const parts = [];
        if (entry.pinned)
            parts.push("pinned");
        if (secret)
            parts.push("secret");
        else if (entry.kind !== "text")
            parts.push(entry.kind);
        const bytes = Clipboard.size(entry.bytes);
        if (bytes)
            parts.push(bytes);
        const when = Clipboard.age(entry.recorded);
        if (when)
            parts.push(when);
        return {
            key: `clipboard:${entry.id}`,
            kind: "clipboard",
            entry: entry,
            going: root.clearing && !entry.pinned,
            armed: root.deleting === entry.id,
            label: root.deleting === entry.id ? "Press Enter again to delete" : masked ? Clipboard.mask : text,
            revealLabel: masked ? text : "",
            masked: masked,
            secret: secret,
            detail: parts.join(" · "),
            icon: secret ? "visibility_off" : Clipboard.markFor(entry.kind),
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

    function undoRow(): var {
        return {
            key: "clipboardundo",
            kind: "clipboardundo",
            label: root.undoLabel,
            detail: root.undoingDelete ? (Clipboard.shelved === 1 ? "1 deleted" : `${Clipboard.shelved} deleted`) : `${Clipboard.shelved} cleared`,
            icon: "undo",
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

    function discard(entry: var): void {
        if (entry.pinned) {
            root.search.armed = `clipboarddelete:${entry.id}`;
            return;
        }
        Clipboard.remove(entry);
    }

    function copy(row: var): void {
        const entry = row.entry;
        root.search.leave(() => Clipboard.copy(entry));
    }

    function activate(row: var): void {
        if (row.kind === "clipboardundo") {
            Clipboard.undo();
            return;
        }
        if (row.kind === "clipboardclear") {
            if (row.armed)
                root.clear();
            else
                root.search.armed = "clipboardclear";
            return;
        }
        if (root.deleting === row.entry.id) {
            root.search.armed = "";
            Clipboard.remove(row.entry);
            return;
        }
        if (Typist.found)
            root.paste(row);
        else
            root.copy(row);
    }

    function confirmActionsFor(row: var): var {
        if (row.kind === "clipboard")
            return [
                {
                    icon: "delete",
                    label: "Delete",
                    alarm: true,
                    run: () => {
                        root.search.armed = "";
                        Clipboard.remove(row.entry);
                    }
                }
            ];
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
        if (row.kind === "clipboardundo")
            return [
                {
                    icon: "undo",
                    label: "Undo",
                    run: () => Clipboard.undo()
                }
            ];
        if (row.kind === "clipboardclear")
            return [
                {
                    icon: "delete_sweep",
                    label: "Clear history",
                    alarm: true,
                    run: () => root.search.armed = "clipboardclear"
                }
            ];
        const typing = Typist.found;
        const acts = [
            {
                icon: typing ? "content_paste_go" : "content_copy",
                label: typing ? "Paste" : "Copy",
                run: () => typing ? root.paste(row) : root.copy(row)
            }
        ];
        if (typing)
            acts.push({
                icon: "content_copy",
                label: "Copy",
                run: () => root.copy(row)
            });
        if (row.secret)
            acts.push({
                icon: row.masked ? "visibility" : "visibility_off",
                label: row.masked ? "Show" : "Hide",
                run: () => root.revealed = row.masked ? row.entry.id : ""
            });
        acts.push({
            icon: "push_pin",
            fill: row.entry.pinned,
            label: row.entry.pinned ? "Unpin" : "Pin",
            run: () => Clipboard.setPinned(row.entry, !row.entry.pinned)
        }, {
            icon: "delete",
            label: "Delete",
            alarm: true,
            run: () => root.discard(row.entry)
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
