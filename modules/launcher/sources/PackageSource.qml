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

    readonly property var prefixes: !PackageSearch.enabled ? [] : [
            {
                section: "System",
                word: "pkg",
                example: "pkg ripgrep",
                about: "Find a package to install",
                icon: "package_2",
                also: ["install", "package"]
            }
        ]

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
            const armed = PackageSearch.armed === `remove:${token}` ? `Press Enter again to uninstall ${entry.title}` : PackageSearch.armed === `install:${token}` ? `Press Enter again to build ${entry.title}` : "";
            const busy = ["installing", "building", "removing"].indexOf(state) >= 0 ? state : "";
            return {
                key: `package:${token}`,
                kind: "package",
                entry: entry,
                label: armed || entry.title,
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
        const cancel = {
            icon: "close",
            label: "Cancel",
            run: () => PackageSearch.armed = ""
        };
        if (PackageSearch.armed === `remove:${token}`)
            return [
                {
                    icon: "delete",
                    label: "Uninstall",
                    alarm: true,
                    run: () => PackageSearch.uninstall(entry)
                },
                cancel
            ];
        if (PackageSearch.armed === `install:${token}`)
            return [
                {
                    icon: "terminal",
                    label: `Build with ${PackageSearch.aurHelper} in a terminal`,
                    short: "Build",
                    run: () => PackageSearch.install(entry)
                },
                cancel
            ].concat(page);
        if (state === "installing" || state === "building" || state === "removing")
            return [
                {
                    icon: "hourglass_top",
                    label: state === "removing" ? "Removing" : state === "building" ? "Building" : "Installing",
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
                    run: () => PackageSearch.armed = `remove:${token}`
                }
            ]);
        }
        if (!PackageSearch.installable(entry))
            return page;
        return [
            {
                icon: "download",
                label: entry.source === "aur" ? `Build with ${PackageSearch.aurHelper}` : "Install",
                short: entry.source === "aur" ? "Build" : "Install",
                run: () => {
                    if (entry.source === "aur")
                        PackageSearch.armed = `install:${token}`;
                    else
                        PackageSearch.install(entry);
                }
            }
        ].concat(page);
    }
}
