import QtQuick
import Quickshell
import qs.services
import "../../../services/dictionary.js" as Words
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["definition"]

    readonly property var asked: Words.ask(root.search.text)
    readonly property string word: root.asked?.word ?? ""
    readonly property bool explicit: !!root.asked?.explicit
    readonly property bool waitingForWord: Words.waitingForWord(root.search.query)
    readonly property var modeRest: Words.modeOf(root.search.query)
    readonly property bool alone: root.modeRest !== null
    readonly property bool onlineWanted: root.explicit && Dictionary.onlineEnabled

    readonly property bool quiet: root.search.quiet

    onWordChanged: root.lookUp()
    onExplicitChanged: root.lookUp()
    onOnlineWantedChanged: root.lookUp()
    onQuietChanged: root.lookUp()

    function lookUp(): void {
        if (root.quiet)
            return;
        const asked = Words.ask(root.search.text);
        const word = asked?.word ?? "";
        const explicit = !!asked?.explicit;
        Dictionary.online.want(explicit && Dictionary.onlineEnabled ? word : "");
        if (explicit) {
            root.bare.stop();
            Dictionary.want(word, true);
        } else {
            root.bare.word = word;
            root.bare.restart();
        }
    }

    readonly property Timer bare: Timer {
        property string word: ""

        interval: 150
        onTriggered: Dictionary.want(root.bare.word, false)
    }

    readonly property bool intent: root.explicit || root.waitingForWord

    readonly property var answer: root.word ? Dictionary.answers[root.word] : undefined
    readonly property var localEntry: root.answer?.entry ?? null
    readonly property bool localBusy: Dictionary.pending(root.word, root.explicit)
    readonly property var onlineAnswer: root.onlineWanted ? Dictionary.online.answers[root.word] : undefined
    readonly property bool onlineFailed: root.onlineWanted && Dictionary.online.failures[root.word] !== undefined
    readonly property bool onlineBusy: root.onlineWanted && root.onlineAnswer === undefined && !root.onlineFailed

    readonly property Component wordView: Component {
        WordView {}
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
            main: main,
            meaning: first?.text ?? "",
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
            return root.alone ? [Object.assign(root.note("missing", `No definition for “${root.modeRest}”`, "Search Wiktionary", false), {
                        word: root.modeRest
                    })] : [];
        if (!root.explicit)
            return root.localEntry ? [root.wordRow(root.localEntry, false, Ranking.WORD - 0.5)] : [];
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

    function open(word: string): void {
        if (root.search.presents)
            root.search.present({
                component: root.wordView,
                text: word
            });
        else
            root.search.retype(`define ${word}`);
    }

    function activate(row: var): void {
        if (row.waiting)
            return;
        if (row.missing) {
            root.openWiktionary(row.word);
            return;
        }
        root.open(row.word);
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
        return [
            {
                icon: "menu_book",
                label: "Open",
                run: () => root.open(row.word)
            },
            {
                icon: "content_copy",
                label: "Copy definition",
                run: () => root.copy(row.meaning || row.word)
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
