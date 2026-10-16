import QtQuick
import Quickshell
import qs.services
import "../search.js" as Search
import "../../../services/screenshots.js" as Logic
import "../../../services/projects.js" as Ages

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["screenshot"]

    readonly property var words: Logic.ask(root.search.text)
    readonly property bool intent: root.words !== null

    onIntentChanged: if (root.intent)
        Screenshots.refresh()

    readonly property var caps: ({
            screenshots: 24
        })

    function row(shot: var, first: bool): var {
        return {
            key: `screenshot:${shot.path}`,
            kind: "screenshot",
            path: shot.path,
            label: shot.name,
            detail: Ages.ago(shot.modified, Date.now()),
            iconSource: Search.fileUrl(shot.path),
            icon: "screenshot_monitor",
            peekPath: shot.path,
            score: first ? Infinity : 100
        };
    }

    readonly property var groups: [
        {
            key: "screenshots",
            title: "Screenshots",
            items: root.intent ? Logic.matching(Screenshots.shots, root.words, 24).map((shot, i) => root.row(shot, i === 0)) : []
        }
    ]

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
                run: () => root.search.leave(() => Screenshots.copy(path))
            },
            {
                icon: "edit",
                label: "Edit",
                run: () => root.search.launch(() => Screenshots.edit(path))
            },
            {
                icon: "folder_open",
                label: "Show in folder",
                tucked: true,
                run: () => root.search.leave(() => Files.reveal(path))
            }
        ];
    }
}
