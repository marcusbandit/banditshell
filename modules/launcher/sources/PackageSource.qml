import QtQuick
import Quickshell
import qs.services
import "../../../services/packages.js" as Packages

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["package"]

    readonly property string term: PackageSearch.enabled ? Packages.ask(root.search.text) : ""

    onTermChanged: {
        PackageSearch.armed = "";
        PackageSearch.want(root.term);
    }

    readonly property bool intent: !!root.term

    readonly property var caps: ({
            packages: 10
        })

    readonly property var found: root.term ? PackageSearch.results(root.term).slice(0, 30) : []
    readonly property bool searching: !!root.term && PackageSearch.searching(root.term)

    readonly property var groups: [
        {
            key: "packages",
            title: "Packages",
            items: root.rows
        }
    ]

    function stateOf(entry: var): string {
        return PackageSearch.jobs[Packages.installToken(entry)] ?? "";
    }

    function iconFor(entry: var): string {
        if (entry.icon)
            return `file://${entry.icon}`;
        return entry.source === "flatpak" ? "" : Quickshell.iconPath(entry.name, true);
    }

    readonly property var rows: {
        const out = root.found.map((entry, i) => {
            const token = Packages.installToken(entry);
            const state = root.stateOf(entry);
            const armed = PackageSearch.armed === token;
            const busy = state === "installing" ? entry.source === "aur" ? "building" : "installing" : state === "removing" ? "removing" : "";
            return {
                key: `package:${token}`,
                kind: "package",
                entry: entry,
                label: armed ? `Press Enter again to uninstall ${entry.title}` : entry.title,
                detail: armed ? "" : busy ? [Packages.detailOf(entry).split(" · ")[0], busy].join(" · ") : Packages.detailOf(entry),
                icon: entry.installed ? "inventory_2" : "package_2",
                iconSource: root.iconFor(entry),
                score: 10 - i * 0.01
            };
        });
        if (!out.length && root.searching)
            return [
                {
                    key: `package-search:${root.term}`,
                    kind: "package",
                    waiting: true,
                    label: `Searching packages for ${root.term}`,
                    detail: "",
                    icon: "manage_search",
                    score: 10
                }
            ];
        return out;
    }

    function appFor(entry: var): var {
        return entry.installed ? Apps.entryById(entry.name) ?? null : null;
    }

    function openPage(entry: var): void {
        const url = Packages.pageUrl(entry);
        if (url)
            root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function activate(row: var): void {
        const first = root.actionsFor(row)[0];
        if (first)
            first.run();
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        const entry = row.entry;
        const token = Packages.installToken(entry);
        const state = root.stateOf(entry);
        const page = Packages.pageUrl(entry) ? [
            {
                icon: "open_in_new",
                label: "Open package page",
                short: "Page",
                run: () => root.openPage(entry)
            }
        ] : [];
        if (PackageSearch.armed === token)
            return [
                {
                    icon: "delete",
                    label: "Uninstall",
                    alarm: true,
                    run: () => PackageSearch.uninstall(entry)
                },
                {
                    icon: "close",
                    label: "Cancel",
                    run: () => PackageSearch.armed = ""
                }
            ];
        if (state === "installing" || state === "removing")
            return [
                {
                    icon: "hourglass_top",
                    label: state === "installing" ? "Installing" : "Removing",
                    run: () => {}
                }
            ].concat(page);
        if (entry.installed || state === "installed") {
            const app = root.appFor(entry);
            return (app ? [
                    {
                        icon: "open_in_new",
                        label: `Open ${app.name}`,
                        short: "Open",
                        run: () => root.search.launch(() => Apps.launch(app))
                    }
                ] : []).concat(page, [
                {
                    icon: "delete",
                    label: "Uninstall",
                    run: () => PackageSearch.armed = token
                }
            ]);
        }
        if (!PackageSearch.installable(entry))
            return page;
        return [
            {
                icon: "download",
                label: entry.source === "aur" ? `Build with ${PackageSearch.aurHelper}` : "Install",
                short: "Install",
                run: () => PackageSearch.install(entry)
            }
        ].concat(page);
    }
}
