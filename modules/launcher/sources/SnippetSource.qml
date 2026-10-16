import QtQuick
import Quickshell
import qs.config
import qs.services

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["snippet", "snippetnew"]

    readonly property var asked: Snippets.ask(root.search.text)
    readonly property bool explicit: root.asked.explicit

    readonly property var found: root.search.text.length < 2 && !root.explicit ? [] : Snippets.find(root.asked.term, root.explicit).slice(0, root.explicit ? 20 : 4)

    readonly property bool intent: root.explicit || root.found.some(f => f.keyed)

    readonly property bool saving: root.explicit && root.asked.term !== "" && !Snippets.list.some(s => String(s?.name ?? "").toLowerCase() === root.asked.term.toLowerCase())

    readonly property var groups: [
        {
            key: "snippets",
            title: "Snippets",
            items: root.found.map(f => root.row(f.snippet, root.explicit ? Infinity : f.score)).concat(root.saving ? [root.saveRow(root.asked.term)] : [], root.explicit && root.asked.term === "" ? [root.newRow()] : [])
        }
    ]

    readonly property var phrases: [
        {
            head: "snippet ",
            picks: Snippets.list.length ? Snippets.list.map(s => String(s?.name ?? "")).filter(Boolean) : [""]
        }
    ]

    function row(snippet: var, score: real): var {
        const preview = Snippets.preview(snippet);
        return {
            key: `snippet:${snippet.id}`,
            kind: "snippet",
            snippet: snippet,
            label: snippet.name || preview,
            detail: snippet.keyword ? `${snippet.keyword} · ${preview}` : preview,
            icon: "short_text",
            score: score
        };
    }

    function newRow(): var {
        return {
            key: "snippetnew",
            kind: "snippetnew",
            label: "New snippet",
            detail: "",
            icon: "add",
            score: Infinity
        };
    }

    function saveRow(text: string): var {
        const name = Snippets.suggestName(text);
        const shown = text.length > 40 ? `${text.slice(0, 39).trim()}…` : text;
        return {
            key: "snippetsave",
            kind: "snippetsave",
            text: text,
            label: `Save “${shown}” as a snippet`,
            detail: "",
            icon: "bookmark_add",
            score: Infinity,
            ask: {
                prompt: "Name for this snippet",
                icon: "short_text",
                suggestion: name,
                take: typed => {
                    Snippets.add(typed, "", text);
                    return `snippet ${typed}`;
                }
            }
        };
    }

    function rowById(id: string): var {
        if (id === "snippetnew")
            return root.newRow();
        if (!id.startsWith("snippet:"))
            return null;
        const snippet = Snippets.byId(id.slice(8));
        return snippet ? root.row(snippet, 1) : null;
    }

    function type(snippet: var): void {
        const done = Snippets.expand(snippet);
        const address = root.search.windowTarget();
        root.search.leave(() => Typist.type(done.text, done.back, address));
    }

    function copy(snippet: var): void {
        const done = Snippets.expand(snippet);
        root.search.leave(() => Clipboard.copy({
                text: done.text
            }));
    }

    function edit(): void {
        const screen = root.search.screenName;
        root.search.leave(() => Settings.openAt(screen, "launcher", "snippets"));
    }

    function activate(row: var): void {
        if (row.kind === "snippetnew")
            root.edit();
        else if (Typist.found)
            root.type(row.snippet);
        else
            root.copy(row.snippet);
    }

    function actionsFor(row: var): var {
        if (row.kind === "snippetnew")
            return [
                {
                    icon: "add",
                    label: "New snippet",
                    run: () => root.edit()
                }
            ];
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
                run: () => root.copy(row.snippet)
            });
        acts.push({
            icon: "edit",
            label: "Edit",
            run: () => root.edit()
        }, {
            icon: "delete",
            label: "Delete",
            tucked: true,
            run: () => Snippets.remove(row.snippet.id)
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

    function complete(row: var): bool {
        if (row.kind !== "snippet")
            return false;
        root.search.retype(row.snippet.keyword || `snippet ${row.snippet.name}`);
        return true;
    }
}
