import QtQuick
import Quickshell
import qs.services
import "../../../services/browsing.js" as Browsing

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["place"]

    readonly property bool typing: BrowserPlaces.enabled && root.search.text.length > 0

    onTypingChanged: if (root.typing)
        BrowserPlaces.wake()

    readonly property var asked: BrowserPlaces.enabled ? Browsing.ask(root.search.text) : null
    readonly property bool narrowed: !!root.asked?.only

    readonly property bool intent: root.narrowed

    readonly property var caps: ({
            bookmarks: root.narrowed ? 12 : 4,
            history: root.narrowed ? 12 : 4
        })

    readonly property var found: !root.asked || !root.narrowed && (root.asked.term.length < 3 || root.search.intent) || root.search.text.indexOf("://") >= 0 ? [] : Browsing.match(BrowserPlaces.places, root.asked, 24)

    function placeRow(hit: var, rank: int): var {
        const p = hit.place;
        return {
            key: `place:${p.url}`,
            kind: "place",
            url: p.url,
            label: p.title,
            detail: p.host,
            icon: p.bookmark ? "bookmark" : "history",
            iconSource: p.icon ? `file://${p.icon}` : "",
            score: root.narrowed ? 10 - rank * 0.01 : hit.score - (p.bookmark ? 2 : 3)
        };
    }

    readonly property var groups: [
        {
            key: "bookmarks",
            title: "Bookmarks",
            items: root.found.filter(h => h.place.bookmark).map((h, i) => root.placeRow(h, i))
        },
        {
            key: "history",
            title: "History",
            items: root.found.filter(h => !h.place.bookmark).map((h, i) => root.placeRow(h, i))
        }
    ]

    function activate(row: var): void {
        const url = row.url;
        root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function actionsFor(row: var): var {
        return [
            {
                icon: "open_in_new",
                label: "Open",
                run: () => root.activate(row)
            },
            {
                icon: "content_copy",
                label: "Copy link",
                run: () => {
                    const url = row.url;
                    root.search.leave(() => Files.copyText(url));
                }
            }
        ];
    }
}
