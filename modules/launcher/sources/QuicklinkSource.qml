import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../../services/quicklinks.js" as Quicklinks
import "../prefixes.js" as Prefixes

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["quicklink"]

    readonly property var links: Config.values.launcher.typing.quicklinks ?? []

    function fetchIcons(): void {
        for (const link of root.links) {
            const origin = Quicklinks.originOf(link?.url);
            if (origin)
                LinkPreviews.look(origin);
        }
    }

    onLinksChanged: root.fetchIcons()
    Component.onCompleted: root.fetchIcons()

    readonly property var matched: root.search.text ? Quicklinks.match(root.links, root.search.text) : {
        exact: [],
        partial: []
    }

    readonly property var claimed: root.search.prefixes.filter(p => p.section !== "Quicklinks").reduce((out, p) => out.concat(Prefixes.heads(p)), [])

    function clashes(link: var): bool {
        return root.claimed.indexOf(Quicklinks.cleanKeyword(link.keyword)) >= 0;
    }

    readonly property bool intent: root.matched.exact.some(m => m.query !== "" && !root.clashes(m.link))

    readonly property var groups: [
        {
            key: "quicklinks",
            title: "Quicklinks",
            items: root.matched.exact.map(m => root.row(m.link, m.query, m.query && !root.clashes(m.link) ? Infinity : Quicklinks.KEYWORD_SCORE)).concat(root.matched.partial.slice(0, 3).map(p => root.row(p.link, "", p.score)))
        }
    ]

    readonly property var prefixes: Quicklinks.prefixes(root.links)

    readonly property var phrases: root.links.filter(link => Quicklinks.takes(link) && Quicklinks.cleanKeyword(link.keyword)).map(link => ({
                head: `${Quicklinks.cleanKeyword(link.keyword)} `,
                picks: [""]
            }))

    function row(link: var, query: string, score: real): var {
        const url = Quicklinks.resolve(link.url, query);
        const next = Quicklinks.missing(link.url, query);
        const site = LinkPreviews.pageOf(Quicklinks.originOf(link.url));
        const host = Quicklinks.hostOf(url);
        return {
            key: `quicklink:${Quicklinks.cleanKeyword(link.keyword)}`,
            kind: "quicklink",
            link: link,
            query: query,
            url: url,
            label: query ? `${link.name}: ${query}` : link.name,
            detail: root.clashes(link) ? `${host} · same word as a built-in source` : next && query ? `${host} · then ${next}` : host,
            icon: Quicklinks.takes(link) ? "travel_explore" : "link",
            iconSource: site?.icon ? `file://${site.icon}` : "",
            score: score
        };
    }

    function rowById(id: string): var {
        if (!id.startsWith("quicklink:"))
            return null;
        const keyword = id.slice(10);
        const link = root.links.find(l => Quicklinks.cleanKeyword(l.keyword) === keyword);
        return link ? root.row(link, "", 1) : null;
    }

    function activate(row: var): void {
        const url = row.url;
        root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function actionsFor(row: var): var {
        const acts = [
            {
                icon: row.icon,
                label: "Open",
                run: () => root.activate(row)
            },
            {
                icon: "content_copy",
                label: "Copy link",
                short: "Copy",
                run: () => root.search.leave(() => Clipboard.copy({
                            text: row.url
                        }))
            },
            {
                icon: "label",
                label: "Copy name",
                short: "Name",
                run: () => root.search.leave(() => Clipboard.copy({
                            text: row.link.name
                        }))
            }
        ];
        if (!row.query && Quicklinks.takes(row.link))
            acts.push({
                icon: "keyboard_tab",
                label: `Search ${row.link.name}`,
                short: "Search",
                run: () => root.complete(row)
            });
        acts.push({
            icon: "file_copy",
            label: "Duplicate",
            tucked: true,
            run: () => root.duplicate(row.link)
        }, {
            icon: "edit",
            label: "Edit quicklinks",
            tucked: true,
            run: () => {
                const screen = root.search.screenName;
                root.search.leave(() => Settings.openAt(screen, "launcher", "quicklinks"));
            }
        });
        return acts;
    }

    function duplicate(link: var): void {
        const made = Quicklinks.copyOf(root.links, link);
        Config.set("launcher.typing.quicklinks", Quicklinks.withLink(root.links, made, -1));
        root.search.retype(made.keyword);
    }

    function complete(row: var): bool {
        if (row.query || !Quicklinks.takes(row.link))
            return false;
        root.search.retype(`${Quicklinks.cleanKeyword(row.link.keyword)} `);
        return true;
    }
}
