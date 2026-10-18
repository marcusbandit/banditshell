import QtQuick
import qs.config
import qs.services
import "../../../services/tray-search.js" as Logic
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["tray"]

    readonly property bool enabled: Config.values.launcher.shell.tray !== false
    readonly property var asked: root.enabled ? Logic.ask(root.search.text) : null

    readonly property bool intent: root.asked !== null

    readonly property bool wanted: root.enabled && root.search.text.length >= 3

    readonly property var listing: root.wanted || root.asked ? Tray.items.map(item => ({
                key: Tray.keyOf(item),
                id: Tray.idOf(item),
                name: Tray.nameOf(item),
                detail: Tray.detailOf(item),
                icon: item.icon ?? "",
                urgent: Tray.urgent(item)
            })) : []

    readonly property var items: {
        if (root.asked)
            return Logic.matching(root.listing, root.asked.words, Ranking.place, 12).map((entry, i) => root.row(entry, i === 0 ? Infinity : 100));
        if (root.wanted)
            return Logic.ambient(root.listing, root.search.text, Ranking.place, 2).map(hit => root.row(hit.entry, hit.score));
        return [];
    }

    readonly property var caps: ({
            tray: 12
        })

    readonly property var groups: [
        {
            key: "tray",
            title: "Tray",
            items: root.items
        }
    ]

    readonly property var phrases: [
        {
            head: "tray ",
            picks: [""]
        }
    ]

    function row(entry: var, score: real): var {
        return {
            key: `tray:${entry.key}`,
            kind: "tray",
            trayKey: entry.key,
            label: entry.name,
            detail: [entry.urgent ? "needs attention" : "", entry.detail || "tray"].filter(Boolean).join(" · "),
            iconSource: entry.icon,
            icon: "widgets",
            score: score
        };
    }

    function itemFor(trayKey: string): var {
        return Tray.items.find(item => Tray.keyOf(item) === trayKey) ?? null;
    }

    function activate(row: var): void {
        const trayKey = row.trayKey;
        const screen = root.search.screenName;
        root.search.leave(() => {
            if (Shell.forScreen(screen)?.openMenu(`tray:${trayKey}`))
                return;
            const item = root.itemFor(trayKey);
            if (item && !Tray.activate(item))
                Tray.secondary(item);
        });
    }

    function actionsFor(row: var): var {
        const trayKey = row.trayKey;
        return [
            {
                icon: "menu_open",
                label: "Open menu",
                short: "Menu",
                run: () => root.activate(row)
            },
            {
                icon: "open_in_full",
                label: "Show it",
                short: "Show",
                run: () => root.search.leave(() => Tray.activate(root.itemFor(trayKey)))
            },
            {
                icon: "ads_click",
                label: "Secondary click",
                short: "Other",
                tucked: true,
                run: () => root.search.leave(() => Tray.secondary(root.itemFor(trayKey)))
            }
        ];
    }
}
