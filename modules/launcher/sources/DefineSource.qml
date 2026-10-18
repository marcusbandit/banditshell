import QtQuick
import Quickshell
import qs.services
import "../../../services/dictionary.js" as Words

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["definition"]

    readonly property string word: Dictionary.enabled ? Words.ask(root.search.text) : ""

    readonly property bool waitingForWord: Dictionary.enabled && Words.waitingForWord(root.search.query)

    onWordChanged: Dictionary.lookup.want(root.word)

    readonly property bool intent: !!root.word || root.waitingForWord

    readonly property var answer: root.word ? Dictionary.lookup.answers[root.word] : undefined
    readonly property bool pending: !!root.word && root.answer === undefined && Dictionary.lookup.failures[root.word] === undefined

    readonly property var caps: ({
            dictionary: 8
        })

    readonly property var groups: [
        {
            key: "dictionary",
            title: root.answer ? root.answer.word : "Dictionary",
            items: root.rows
        }
    ]

    readonly property var rows: {
        if (root.answer)
            return root.answer.senses.map((sense, i) => ({
                        key: `definition:${root.word}:${i}`,
                        kind: "definition",
                        label: sense.text,
                        detail: i === 0 && root.answer.phonetic ? `${sense.part} · ${root.answer.phonetic}` : sense.part,
                        icon: "menu_book",
                        word: root.word,
                        sense: sense,
                        peekText: [sense.text, sense.example].filter(Boolean).join("\n\n"),
                        score: i === 0 ? Infinity : 9 - i * 0.01
                    }));
        if (root.waitingForWord)
            return [
                {
                    key: "definition-hint",
                    kind: "definition",
                    label: "Type a word to define",
                    detail: "",
                    icon: "menu_book",
                    waiting: true,
                    score: Infinity
                }
            ];
        return root.pending ? [
            {
                key: `definition:${root.word}`,
                kind: "definition",
                label: `Looking up ${root.word}`,
                detail: "",
                icon: "menu_book",
                waiting: true,
                score: Infinity
            }
        ] : [];
    }

    readonly property var commands: [
        {
            id: "define",
            icon: "menu_book",
            label: "Define a word",
            words: "define dictionary meaning",
            hidden: !Dictionary.enabled || root.waitingForWord || !!root.word,
            stay: true,
            run: () => root.search.retype("define ")
        }
    ]

    function activate(row: var): void {
        if (row.waiting)
            return;
        const text = row.sense.text;
        root.search.leave(() => System.copyText(text));
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        return [
            {
                icon: "content_copy",
                label: "Copy",
                run: () => root.activate(row)
            },
            {
                icon: "open_in_new",
                label: "Open in Wiktionary",
                short: "Wiktionary",
                run: () => {
                    const url = Words.pageUrl(row.word);
                    root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
                }
            }
        ];
    }
}
