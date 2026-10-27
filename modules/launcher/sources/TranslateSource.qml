import QtQuick
import Quickshell
import qs.services
import "../../../services/translation.js" as Translation

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["translation"]

    readonly property var asked: Translator.enabled ? Translation.ask(root.search.text) : null
    readonly property string target: root.asked ? root.asked.to || Translator.preferred : ""
    readonly property string firstKey: root.asked ? Translation.keyOf(root.asked.text, root.target) : ""
    readonly property var first: root.firstKey ? Translator.lookup.answers[root.firstKey] : undefined
    readonly property bool flipped: !!root.asked && !root.asked.explicit && !!root.first && !!Translator.fallback && Translation.languageCode(root.first.from) === root.target
    readonly property string wanted: root.flipped ? Translation.keyOf(root.asked.text, Translator.fallback) : root.firstKey

    onWantedChanged: Translator.lookup.want(root.wanted)

    readonly property bool intent: !!root.asked

    readonly property var answer: root.wanted ? Translator.lookup.answers[root.wanted] : undefined
    readonly property bool pending: !!root.wanted && root.answer === undefined && Translator.lookup.failures[root.wanted] === undefined

    readonly property var prefixes: !Translator.enabled ? [] : [
            {
                section: "Ask and look up",
                word: "translate",
                example: "translate hola to english",
                about: "Translate text",
                icon: "translate",
                also: ["tr"]
            }
        ]

    readonly property var groups: [
        {
            key: "translation",
            title: "Translation",
            items: root.rows
        }
    ]

    readonly property var rows: {
        if (!root.wanted)
            return [];
        const to = Translation.splitKey(root.wanted).to;
        const toName = Translation.languageName(to);
        if (root.answer) {
            const fromName = Translation.languageName(root.answer.from);
            return [
                {
                    key: `translation:${root.wanted}`,
                    kind: "translation",
                    label: root.answer.text,
                    detail: fromName ? `${fromName} to ${toName}` : toName,
                    icon: "translate",
                    original: root.asked.text,
                    translated: root.answer.text,
                    from: root.answer.from,
                    to: to,
                    score: Infinity
                }
            ];
        }
        return root.pending ? [
            {
                key: `translation:${root.wanted}`,
                kind: "translation",
                label: `Translating into ${toName}`,
                detail: root.asked.text,
                icon: "translate",
                waiting: true,
                score: Infinity
            }
        ] : [];
    }

    function activate(row: var): void {
        if (row.waiting)
            return;
        const text = row.translated;
        root.search.leave(() => System.copyText(text));
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        const fromName = Translation.languageName(row.from);
        return [
            {
                icon: "content_copy",
                label: "Copy",
                run: () => root.activate(row)
            },
            {
                icon: "open_in_new",
                label: "Open in Google Translate",
                short: "Open",
                run: () => {
                    const url = Translation.pageUrl(row.original, row.to);
                    root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
                }
            }
        ].concat(fromName ? [
                {
                    icon: "swap_horiz",
                    label: `Back to ${fromName}`,
                    run: () => root.search.retype(`translate ${row.translated} to ${fromName.toLowerCase()}`)
                }
            ] : []);
    }
}
