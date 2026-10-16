import QtQuick
import Quickshell
import qs.services
import "../../../services/lorem.js" as Lorem

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["lorem"]

    readonly property var ask: Lorem.loremAsk(root.search.text)

    readonly property bool intent: !!root.ask

    readonly property string generated: root.ask ? Lorem.generate(root.ask.count, root.ask.unit) : ""

    readonly property var groups: [
        {
            key: "lorem",
            title: "Lorem ipsum",
            items: !root.ask ? [] : [
                {
                    key: `lorem:${root.ask.count}:${root.ask.unit}`,
                    kind: "lorem",
                    text: root.generated,
                    label: `Copy ${Lorem.describe(root.ask.count, root.ask.unit)}`,
                    detail: Lorem.preview(root.generated, 44),
                    icon: "notes",
                    score: Infinity
                }
            ]
        }
    ]

    readonly property var phrases: [
        {
            head: "lorem ",
            picks: ["3", "5 sentences", "50 words"]
        }
    ]

    function activate(row: var): void {
        const text = row.text;
        root.search.leave(() => Files.copyText(text));
    }

    function actionsFor(row: var): var {
        return [
            {
                icon: "content_copy",
                label: "Copy",
                run: () => root.activate(row)
            }
        ];
    }
}
