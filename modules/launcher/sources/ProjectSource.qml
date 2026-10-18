import QtQuick
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/projects.js" as Logic

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["project"]

    readonly property bool started: root.search.started

    onStartedChanged: if (root.started)
        Projects.refresh()

    readonly property var ask: Logic.projectAsk(root.search.text)

    readonly property bool intent: !!root.ask

    readonly property string want: root.ask ? root.ask.text : root.search.text

    function projectRow(project: var, last: real, score: real): var {
        return {
            key: `project:${project.path}`,
            kind: "project",
            path: project.path,
            peekPath: project.path,
            peekDir: true,
            label: project.name,
            detail: [Logic.parentWithin(Projects.roots, project.path), project.branch, Logic.ago(last, Date.now())].filter(Boolean).join(" · "),
            icon: "folder_code",
            score: score
        };
    }

    readonly property var rows: {
        if (!root.ask && root.want.length < 2)
            return [];
        const hits = Logic.rank(Projects.projects, Projects.opened, root.want, Ranking.place, root.ask ? 12 : 4);
        return hits.map(h => root.projectRow(h.project, h.last, root.ask ? Infinity : Logic.ambientScore(h.score))).filter(r => r.score > 0);
    }

    readonly property var groups: [
        {
            key: "projects",
            title: "Projects",
            items: root.rows
        }
    ]

    readonly property var caps: ({
            projects: 12
        })

    readonly property string editorName: Projects.editor?.name ?? ""

    function activate(row: var): void {
        const path = row.path;
        root.search.launch(() => Projects.openInEditor(path));
    }

    function actionsFor(row: var): var {
        const path = row.path;
        return [
            {
                icon: "code",
                label: root.editorName ? `Open in ${root.editorName}` : "Open",
                run: () => root.activate(row)
            },
            {
                icon: "terminal",
                label: "Open in terminal",
                short: "Terminal",
                run: () => root.search.launch(() => Projects.openTerminal(path))
            },
            {
                icon: "folder_open",
                label: "Show in Files",
                short: "Files",
                run: () => root.search.leave(() => Files.show(path))
            },
            {
                icon: "content_copy",
                label: "Copy path",
                short: "Copy",
                run: () => root.search.leave(() => System.copyText(path))
            }
        ];
    }

    function rowById(id: string): var {
        if (id.indexOf("project:") !== 0)
            return null;
        const path = id.slice(8);
        const project = Projects.projects.find(p => p.path === path);
        return project ? root.projectRow(project, Logic.lastTouched(project, Projects.opened), 1) : null;
    }
}
