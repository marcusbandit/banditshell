import QtQuick
import qs.services

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["emoji"]

    readonly property var asked: Emoji.ask(root.search.text)
    readonly property bool explicit: root.asked.explicit
    readonly property string typed: String(root.asked.term || "").toLowerCase()

    readonly property var found: root.search.text ? Emoji.search(root.asked.term, root.explicit, root.explicit ? 40 : 3) : []

    readonly property bool intent: root.explicit

    readonly property var prefixes: [
        {
            section: "Ask and look up",
            word: "emoji",
            example: "emoji heart",
            about: "Emoji and symbols",
            icon: "mood",
            also: ["emojis", "symbols"]
        }
    ]

    readonly property var groups: [
        {
            key: "emoji",
            title: "Emoji and symbols",
            items: root.found.map(entry => root.row(entry))
        }
    ]

    readonly property var phrases: [
        {
            head: "emoji ",
            picks: Emoji.recentNames.concat(["heart", "thumbs up", "smile", "fire", "check mark", "right arrow", "degree"])
        }
    ]

    function row(entry: var): var {
        return {
            key: `emoji:${entry.char}`,
            kind: "emoji",
            entry: entry,
            glyph: Emoji.textOf(entry),
            label: entry.name.charAt(0).toUpperCase() + entry.name.slice(1),
            detail: entry.symbol ? `${entry.group} · ${Emoji.codeOf(entry.char)}` : entry.group,
            icon: entry.symbol ? "special_character" : "mood",
            score: root.explicit ? Infinity : root.typed && entry.title.indexOf(root.typed) === 0 ? 0.8 : 0.45
        };
    }

    function rowById(id: string): var {
        if (!id.startsWith("emoji:"))
            return null;
        const entry = Emoji.byChar[id.slice(6)];
        return entry ? root.row(entry) : null;
    }

    function type(row: var, glyph: string): void {
        const address = root.search.windowTarget();
        Emoji.use(row.entry);
        root.search.leave(() => Typist.type(glyph, 0, address));
    }

    function copy(row: var, glyph: string): void {
        Emoji.use(row.entry);
        root.search.leave(() => Clipboard.copy({
                text: glyph
            }));
    }

    function activate(row: var): void {
        if (Typist.found)
            root.type(row, row.glyph);
        else
            root.copy(row, row.glyph);
    }

    function actionsFor(row: var): var {
        const typing = Typist.found;
        const acts = [
            {
                icon: typing ? "keyboard" : "content_copy",
                label: typing ? "Type" : "Copy",
                run: () => root.activate(row)
            }
        ];
        if (typing)
            acts.push({
                icon: "content_copy",
                label: "Copy",
                run: () => root.copy(row, row.glyph)
            });
        if (row.entry.places.length)
            for (const tone of Emoji.tones) {
                if (tone.modifier === Emoji.modifier)
                    continue;
                const glyph = Emoji.textWith(row.entry, tone.modifier);
                acts.push({
                    icon: "front_hand",
                    label: `${tone.name} ${glyph}`,
                    tucked: true,
                    run: () => typing ? root.type(row, glyph) : root.copy(row, glyph)
                });
            }
        if (Emoji.used[row.entry.char])
            acts.push({
                icon: "history",
                label: "Forget that I used it",
                tucked: true,
                run: () => {
                    Emoji.forget(row.entry);
                    LauncherMemory.forget(row.id ?? row.key);
                }
            });
        if (!typing && Typist.probed)
            acts.push({
                icon: "download",
                label: Typist.installing === "trying" ? "Installing wtype" : "Install wtype to type it",
                tucked: true,
                run: () => Typist.install()
            });
        return acts;
    }
}
