import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/notes.js" as Logic
import "../../../services/projects.js" as Ages

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["note", "newnote"]

    readonly property bool started: root.search.started

    onStartedChanged: if (root.started)
        Notes.refresh()

    readonly property var ask: Logic.notesAsk(root.search.text)

    readonly property bool intent: !!root.ask || root.bare

    readonly property string want: root.ask ? root.ask.text : root.search.text

    function noteRow(note: var, score: real): var {
        const folder = note.relative.lastIndexOf("/") > 0 ? note.relative.slice(0, note.relative.lastIndexOf("/")) : "";
        return {
            key: `note:${note.path}`,
            kind: "note",
            note: note,
            peekPath: note.path,
            label: note.name,
            detail: [note.vaultName, folder, Ages.ago(note.modified, Date.now())].filter(Boolean).join(" · "),
            icon: "description",
            score: score
        };
    }

    readonly property var bareAsk: /^(?:new )?note$/i
    readonly property bool bare: root.bareAsk.test(root.search.text)

    readonly property var rows: {
        const out = [];
        const ask = root.ask;
        if (root.bare && Notes.vault)
            out.push({
                key: "newnote",
                kind: "newnote",
                title: "",
                label: "New note",
                detail: Notes.vault.name,
                icon: "note_add",
                score: Infinity,
                ask: {
                    prompt: "Title of the new note",
                    icon: "note_add",
                    suggestion: "",
                    take: text => {
                        const title = Logic.fileNameFor(text);
                        if (title)
                            root.search.launch(() => Notes.create(title));
                    }
                }
            });
        if (ask?.create && Notes.vault)
            out.push({
                key: `newnote:${ask.create}`,
                kind: "newnote",
                title: ask.create,
                label: `New note ${ask.create}`,
                detail: Notes.vault.name,
                icon: "note_add",
                score: Infinity
            });
        if (!ask && root.want.length < 3)
            return out;
        const hits = Logic.search(Notes.notes, root.want, Ranking.place, ask ? 10 : 4);
        return out.concat(hits.map(h => root.noteRow(h.note, ask ? Infinity : h.score - 1)).filter(r => r.score > 0));
    }

    readonly property var groups: [
        {
            key: "notes",
            title: "Notes",
            items: root.rows
        }
    ]

    readonly property var caps: ({
            notes: 11
        })

    function activate(row: var): void {
        if (row.kind === "newnote") {
            const title = row.title;
            root.search.launch(() => Notes.create(title));
            return;
        }
        const note = row.note;
        root.search.launch(() => Notes.open(note));
    }

    function actionsFor(row: var): var {
        if (row.kind === "newnote")
            return [
                {
                    icon: "note_add",
                    label: "Create note",
                    run: () => root.activate(row)
                }
            ];
        const path = row.note.path;
        const vault = Notes.vaults.find(v => v.path === row.note.vault);
        return [
            {
                icon: "open_in_new",
                label: Notes.obsidian && vault?.registered ? "Open in Obsidian" : "Open",
                run: () => root.activate(row)
            },
            {
                icon: "drive_file_move",
                label: "Show in folder",
                short: "Folder",
                run: () => root.search.leave(() => Files.reveal(path))
            },
            {
                icon: "content_copy",
                label: "Copy path",
                short: "Copy",
                run: () => root.search.leave(() => Files.copyText(path))
            }
        ];
    }
}
