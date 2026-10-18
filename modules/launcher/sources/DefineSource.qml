import QtQuick
import Quickshell
import qs.services
import "../../../services/dictionary.js" as Words

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["definition"]

    readonly property var asked: Words.ask(root.search.text)
    readonly property string word: root.asked?.word ?? ""
    readonly property bool explicit: !!root.asked?.explicit
    readonly property bool waitingForWord: Words.waitingForWord(root.search.query)
    readonly property bool onlineWanted: root.explicit && Dictionary.onlineEnabled

    onWordChanged: root.lookUp()
    onExplicitChanged: root.lookUp()

    function lookUp(): void {
        Dictionary.want(root.word, root.explicit);
        Dictionary.online.want(root.onlineWanted ? root.word : "");
    }

    readonly property bool intent: root.explicit || root.waitingForWord

    readonly property var answer: root.word ? Dictionary.answers[root.word] : undefined
    readonly property var localEntry: root.answer?.entry ?? null
    readonly property bool localBusy: !!root.word && root.answer === undefined && (Dictionary.ready || Dictionary.building || Dictionary.state === "starting")
    readonly property var onlineAnswer: root.onlineWanted ? Dictionary.online.answers[root.word] : undefined
    readonly property bool onlineFailed: root.onlineWanted && Dictionary.online.failures[root.word] !== undefined
    readonly property bool onlineBusy: root.onlineWanted && root.onlineAnswer === undefined && !root.onlineFailed

    readonly property Component page: Component {
        DefinitionPage {}
    }

    readonly property var caps: ({
            dictionary: 8
        })

    readonly property var groups: [
        {
            key: "dictionary",
            title: "Dictionary",
            note: root.explicit && Dictionary.building ? "getting the offline copy" : "",
            items: root.rows
        }
    ]

    function firstSense(entry: var): var {
        const group = entry?.groups?.[0];
        return group ? {
            part: group.part,
            text: group.senses[0]?.text ?? ""
        } : null;
    }

    function pageOf(entry: var, main: bool): var {
        return {
            word: entry?.word ?? root.word,
            local: entry,
            online: main ? root.onlineAnswer ?? null : null,
            onlineWanted: main && root.onlineWanted,
            onlineBusy: main && root.onlineBusy,
            onlineFailed: main && root.onlineFailed
        };
    }

    function wordRow(entry: var, main: bool, score: real): var {
        const first = root.firstSense(entry) ?? (main && root.onlineAnswer ? root.onlineAnswer.senses[0] : null);
        const word = entry?.word ?? root.word;
        return {
            key: `definition:${word.toLowerCase()}`,
            kind: "definition",
            label: word,
            detail: first ? `${first.part} · ${first.text}` : "",
            icon: "menu_book",
            word: word,
            meaning: first?.text ?? "",
            peekCard: root.page,
            entry: root.pageOf(entry, main),
            score: score
        };
    }

    function note(key: string, label: string, detail: string, waiting: bool): var {
        return {
            key: `definition-${key}`,
            kind: "definition",
            label: label,
            detail: detail,
            icon: "menu_book",
            word: root.word,
            waiting: waiting,
            missing: !waiting,
            score: Infinity
        };
    }

    readonly property var rows: {
        if (root.waitingForWord)
            return [root.note("hint", "Type a word to define", "", true)];
        if (!root.word)
            return [];
        if (!root.explicit)
            return root.localEntry && !root.localEntry.asked ? [root.wordRow(root.localEntry, false, 0.25)] : [];
        const found = root.localEntry || root.onlineAnswer ? [root.wordRow(root.localEntry, true, Infinity)] : [];
        const completions = (root.answer?.completions ?? []).map((entry, i) => root.wordRow(entry, false, 9 - i * 0.01));
        if (found.length || completions.length)
            return found.concat(completions);
        if (root.localBusy || root.onlineBusy)
            return [root.note("looking", `Looking up ${root.word}`, "", true)];
        return [root.note("missing", `No definition for “${root.word}”`, "Search Wiktionary", false)];
    }

    readonly property var commands: [
        {
            id: "define",
            icon: "menu_book",
            label: "Define a word",
            words: "define dictionary meaning",
            hidden: root.waitingForWord || root.explicit,
            stay: true,
            run: () => root.search.retype("define ")
        }
    ]

    function openWiktionary(word: string): void {
        const url = Words.pageUrl(word);
        root.search.launch(() => Quickshell.execDetached(["xdg-open", url]));
    }

    function copy(text: string): void {
        root.search.leave(() => System.copyText(text));
    }

    function activate(row: var): void {
        if (row.waiting)
            return;
        if (row.missing) {
            root.openWiktionary(row.word);
            return;
        }
        if (row.word.toLowerCase() !== root.word || !root.explicit) {
            root.search.retype(`define ${row.word}`);
            return;
        }
        root.copy(row.meaning || row.word);
    }

    function complete(row: var): bool {
        if (row.waiting || row.missing)
            return false;
        root.search.retype(`define ${row.word}`);
        return true;
    }

    function actionsFor(row: var): var {
        if (row.waiting)
            return [];
        if (row.missing)
            return [
                {
                    icon: "open_in_new",
                    label: "Search Wiktionary",
                    short: "Wiktionary",
                    run: () => root.openWiktionary(row.word)
                }
            ];
        const main = row.word.toLowerCase() === root.word && root.explicit;
        return [
            main ? {
                icon: "content_copy",
                label: "Copy definition",
                run: () => root.copy(row.meaning || row.word)
            } : {
                icon: "menu_book",
                label: "Open",
                run: () => root.search.retype(`define ${row.word}`)
            },
            {
                icon: "content_copy",
                label: "Copy word",
                short: "Copy",
                run: () => root.copy(row.word)
            },
            {
                icon: "open_in_new",
                label: "Open in Wiktionary",
                short: "Wiktionary",
                run: () => root.openWiktionary(row.word)
            }
        ];
    }
}
