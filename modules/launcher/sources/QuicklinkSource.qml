import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../../services/quicklinks.js" as Quicklinks

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["quicklink"]

    readonly property var links: Config.values.launcher.typing.quicklinks ?? []

    readonly property var matched: root.search.text ? Quicklinks.match(root.links, root.search.text) : {
        exact: [],
        partial: []
    }

    readonly property bool intent: root.matched.exact.some(m => m.query !== "")

    readonly property var groups: [
        {
            key: "quicklinks",
            title: "Quicklinks",
            items: root.matched.exact.map(m => root.row(m.link, m.query, m.query ? Infinity : 3.5)).concat(root.matched.partial.slice(0, 3).map(p => root.row(p.link, "", p.score)))
        }
    ]

    readonly property var phrases: root.links.filter(link => Quicklinks.takes(link) && Quicklinks.cleanKeyword(link.keyword)).map(link => ({
                head: `${Quicklinks.cleanKeyword(link.keyword)} `,
                picks: [""]
            }))

    function row(link: var, query: string, score: real): var {
        const url = Quicklinks.resolve(link.url, query);
        return {
            key: `quicklink:${Quicklinks.cleanKeyword(link.keyword)}`,
            kind: "quicklink",
            link: link,
            query: query,
            url: url,
            label: query ? `${link.name}: ${query}` : link.name,
            detail: Quicklinks.hostOf(url),
            icon: Quicklinks.takes(link) ? "travel_explore" : "link",
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

    function complete(row: var): bool {
        if (row.query || !Quicklinks.takes(row.link))
            return false;
        root.search.retype(`${Quicklinks.cleanKeyword(row.link.keyword)} `);
        return true;
    }
}
