import QtQuick
import Quickshell
import qs.config
import qs.services
import "../search.js" as Search
import "../../files/marks.js" as Marks
import "../../../services/recent-documents.js" as Logic
import "../../../services/projects.js" as Ages
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["recent"]

    readonly property bool enabled: Config.values.launcher.shell.recent !== false
    readonly property var asked: root.enabled ? Logic.ask(root.search.text) : null

    readonly property bool intent: root.asked !== null

    readonly property bool wanted: root.enabled && root.search.text.length >= 3

    readonly property bool active: root.asked !== null || root.wanted

    onActiveChanged: if (root.active)
        RecentDocuments.refresh()

    readonly property var candidates: root.active ? Logic.readBookmarks(RecentDocuments.xbel, Search.isSecretish) : []

    onCandidatesChanged: if (root.candidates.length)
        RecentDocuments.check(root.candidates.map(doc => doc.path))

    readonly property var documents: Logic.existing(root.candidates, RecentDocuments.listing)

    readonly property var items: {
        if (root.asked)
            return Logic.matching(root.documents, root.asked.words, 24).map((doc, i) => root.row(doc, i === 0 ? Infinity : 100));
        if (root.wanted)
            return Logic.ambient(root.documents, root.search.text, Ranking.place, 3).map(hit => root.row(hit.document, hit.score));
        return [];
    }

    readonly property var caps: ({
            recent: 24
        })

    readonly property var prefixes: !root.enabled ? [] : [
            {
                section: "Files and clipboard",
                word: "recent",
                example: "recent invoice",
                about: "Recently used documents",
                icon: "history",
                also: []
            }
        ]

    readonly property var groups: [
        {
            key: "recent",
            title: "Recent documents",
            items: root.items
        }
    ]

    readonly property var phrases: [
        {
            head: "recent ",
            picks: [""]
        }
    ]

    function row(doc: var, score: real): var {
        return {
            key: `recent:${doc.path}`,
            kind: "recent",
            path: doc.path,
            label: doc.name,
            detail: [doc.app, Ages.ago(doc.visited, Date.now()), Search.shortPath(doc.dir, Files.home)].filter(Boolean).join(" · "),
            icon: Marks.iconFor(doc.path, doc.name, false, Files.home) || "draft",
            peekPath: doc.path,
            score: score
        };
    }

    function activate(row: var): void {
        const path = row.path;
        root.search.launch(() => Quickshell.execDetached(["xdg-open", path]));
    }

    function actionsFor(row: var): var {
        const path = row.path;
        return [
            {
                icon: "open_in_new",
                label: "Open",
                run: () => root.activate(row)
            },
            {
                icon: "content_copy",
                label: "Copy",
                run: () => root.search.leave(() => Clipboard.copy({
                        paths: [path]
                    }))
            },
            {
                icon: "folder_open",
                label: "Show in folder",
                short: "Folder",
                tucked: true,
                run: () => root.search.leave(() => Files.reveal(path))
            }
        ];
    }
}
