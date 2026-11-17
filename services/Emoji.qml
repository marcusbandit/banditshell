pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "emoji.js" as EmojiLogic
import "emoji-table.js" as EmojiTable

Singleton {
    id: root

    readonly property var all: EmojiLogic.parse(EmojiTable.TABLE, EmojiTable.GROUPS, EmojiTable.FIRST_SYMBOL_GROUP)
    readonly property var byChar: EmojiLogic.index(root.all)
    readonly property var tones: EmojiLogic.TONES

    readonly property string tone: Config.values.launcher.typing.skinTone
    readonly property string modifier: EmojiLogic.modifierFor(root.tone)

    readonly property string path: `${Config.stateDir}/emoji.json`

    readonly property string pinPath: `${Config.stateDir}/emoji-pinned.json`

    property var used: ({})

    property var pinned: []

    readonly property var recentNames: Object.keys(root.used).sort((a, b) => root.used[b].last - root.used[a].last).map(c => root.byChar[c]?.name ?? "").filter(Boolean).slice(0, 6)

    function ask(text: string): var {
        return EmojiLogic.ask(text);
    }

    function search(term: string, explicit: bool, limit: int): var {
        return EmojiLogic.search(root.all, root.byChar, term, root.used, explicit, limit, root.pinned);
    }

    function textOf(entry: var): string {
        return EmojiLogic.toned(entry, root.modifier);
    }

    function textWith(entry: var, modifier: string): string {
        return EmojiLogic.toned(entry, modifier);
    }

    function codeOf(glyph: string): string {
        return EmojiLogic.codeOf(glyph);
    }

    function isPinned(entry: var): bool {
        return !!entry && root.pinned.indexOf(entry.char) >= 0;
    }

    function pin(entry: var): void {
        if (!entry)
            return;
        root.pinned = EmojiLogic.pin(root.pinned, entry.char);
        pinStore.setText(JSON.stringify(root.pinned));
    }

    function unpin(entry: var): void {
        if (!entry || !root.isPinned(entry))
            return;
        root.pinned = EmojiLogic.unpin(root.pinned, entry.char);
        pinStore.setText(JSON.stringify(root.pinned));
    }

    function use(entry: var): void {
        if (!entry)
            return;
        root.used = EmojiLogic.remember(root.used, entry.char, Date.now());
        store.setText(JSON.stringify(root.used));
    }

    function forget(entry: var): void {
        if (!entry || !root.used[entry.char])
            return;
        const next = Object.assign({}, root.used);
        delete next[entry.char];
        root.used = next;
        store.setText(JSON.stringify(root.used));
    }

    FileView {
        id: pinStore

        path: root.pinPath
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.pinned = Array.isArray(data) ? data.filter(c => typeof c === "string") : [];
            } catch (e) {
                console.warn(`Emoji: ${root.pinPath} is not valid JSON, starting the pinned list over.`, e);
                root.pinned = [];
            }
        }
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.used = data && typeof data === "object" && !Array.isArray(data) ? data : {};
            } catch (e) {
                console.warn(`Emoji: ${root.path} is not valid JSON, starting the recent list over.`, e);
                root.used = {};
            }
        }
    }
}
