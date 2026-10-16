pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "snippets.js" as SnippetLogic

Singleton {
    id: root

    readonly property var list: Config.values.launcher.typing.snippets ?? []

    function ask(text: string): var {
        return SnippetLogic.ask(text);
    }

    function find(term: string, explicit: bool): var {
        return SnippetLogic.find(root.list, term, explicit);
    }

    function byId(id: string): var {
        return root.list.find(s => s?.id === id) ?? null;
    }

    function clipboardText(): string {
        const entry = Clipboard.entries.find(e => e.id === Clipboard.current) ?? Clipboard.entries[0];
        return entry && !entry.file ? entry.text ?? "" : "";
    }

    function expand(snippet: var): var {
        const now = new Date();
        return SnippetLogic.expand(snippet?.text ?? "", {
            date: TimeFormat.dateText(now, "year"),
            time: TimeFormat.time(now, false),
            clipboard: root.clipboardText()
        });
    }

    function preview(snippet: var): string {
        return SnippetLogic.preview(root.expand(snippet).text, 80);
    }

    function suggestName(text: string): string {
        return SnippetLogic.suggestName(text);
    }

    function keywordHolder(keyword: string, id: string): var {
        return SnippetLogic.keywordHolder(root.list, keyword, id);
    }

    function save(snippet: var): string {
        const id = snippet.id || SnippetLogic.newId(root.list, Date.now());
        Config.set("launcher.typing.snippets", SnippetLogic.withSnippet(root.list, {
            id: id,
            name: String(snippet.name ?? "").trim(),
            keyword: SnippetLogic.cleanKeyword(snippet.keyword),
            text: String(snippet.text ?? "")
        }));
        return id;
    }

    function add(name: string, keyword: string, text: string): string {
        return root.save({
            id: "",
            name: name,
            keyword: keyword,
            text: text
        });
    }

    function remove(id: string): var {
        const gone = root.byId(id);
        Config.set("launcher.typing.snippets", SnippetLogic.withoutSnippet(root.list, id));
        return gone;
    }

    function restore(snippet: var, at: int): void {
        const next = root.list.filter(s => s?.id !== snippet.id);
        next.splice(Math.max(0, Math.min(at, next.length)), 0, snippet);
        Config.set("launcher.typing.snippets", next);
    }
}
