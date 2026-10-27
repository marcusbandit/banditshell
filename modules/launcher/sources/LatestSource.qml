import QtQuick
import Quickshell
import qs.services
import "../search.js" as Search
import "../../files/marks.js" as Marks
import "../../../services/latest-files.js" as Logic
import "../../../services/projects.js" as Ages

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["latest"]

    readonly property var asked: Logic.ask(root.search.text)
    readonly property bool intent: root.asked !== null

    onAskedChanged: if (root.asked)
        LatestFiles.refresh(root.asked.shelf.key)

    readonly property var caps: ({
            latest: 24
        })

    function row(file: var, shelf: var, first: bool): var {
        const picture = !file.dir && Search.isPicture(file.path);
        return {
            key: `latest:${file.path}`,
            kind: "latest",
            path: file.path,
            dir: file.dir,
            picture: picture,
            editable: shelf.pictures,
            label: file.name,
            detail: Ages.ago(file.modified, Date.now()),
            iconSource: picture ? Search.fileUrl(file.path) : "",
            icon: Marks.iconFor(file.path, file.name, file.dir, System.home) || (file.dir ? "folder" : shelf.icon),
            peekPath: file.path,
            peekDir: file.dir,
            score: first ? Infinity : 100
        };
    }

    readonly property var prefixes: [
        {
            section: "Files and clipboard",
            word: "downloads",
            example: "downloads pdf",
            about: "Latest downloads",
            icon: "download",
            also: ["download"]
        },
        {
            section: "Files and clipboard",
            word: "screenshots",
            example: "screenshots terminal",
            about: "Latest screenshots",
            icon: "screenshot_monitor",
            also: []
        }
    ]

    readonly property var groups: [
        {
            key: "latest",
            title: root.asked?.shelf.title ?? "",
            items: root.asked ? Logic.matching(LatestFiles.lists[root.asked.shelf.key] ?? [], root.asked.words, 24).map((file, i) => root.row(file, root.asked.shelf, i === 0)) : []
        }
    ]

    function activate(row: var): void {
        const path = row.path;
        root.search.launch(() => Quickshell.execDetached(["xdg-open", path]));
    }

    function actionsFor(row: var): var {
        const path = row.path;
        const picture = row.picture;
        const acts = [
            {
                icon: "open_in_new",
                label: "Open",
                run: () => root.activate(row)
            },
            {
                icon: "content_copy",
                label: "Copy",
                run: () => root.search.leave(() => LatestFiles.copy(path, picture))
            }
        ];
        if (row.editable && picture)
            acts.push({
                icon: "edit",
                label: "Edit",
                run: () => root.search.launch(() => LatestFiles.edit(path))
            });
        acts.push({
            icon: "folder_open",
            label: "Show in folder",
            tucked: row.editable,
            run: () => root.search.leave(() => System.reveal(path))
        });
        return acts;
    }
}
