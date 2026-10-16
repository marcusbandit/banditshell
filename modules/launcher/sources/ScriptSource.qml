import QtQuick
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/script-commands.js" as Scripts

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["script", "scriptline", "scriptfolder", "scriptitem", "scriptproblem"]

    readonly property string text: root.search.text

    readonly property bool started: root.search.started

    onStartedChanged: if (root.started)
        ScriptCommands.refresh()

    readonly property bool listing: Scripts.listAsk(root.text)

    readonly property var matches: {
        const t = root.text;
        if (root.listing)
            return ScriptCommands.scripts.map(script => ({
                        script: script,
                        values: [],
                        typed: false,
                        score: Infinity
                    }));
        if (t.length < 2)
            return [];
        const out = [];
        for (const script of ScriptCommands.scripts) {
            const ask = Scripts.askFor(script, t);
            const score = ask ? Infinity : Scripts.ambientScore(Math.max(Ranking.place(script.title, t), Ranking.place(script.word, t), Ranking.place(script.packageName, t) - 1));
            if (score > 0)
                out.push({
                    script: script,
                    values: ask?.values ?? [],
                    typed: !!ask && ask.values.length > 0,
                    score: score
                });
        }
        return out.sort((a, b) => b.score - a.score);
    }

    readonly property var listAsk: {
        const top = root.matches[0];
        if (root.listing || !top || top.score !== Infinity || top.script.mode !== "list")
            return null;
        return {
            script: top.script,
            values: top.values,
            key: Scripts.runKey(top.script, top.values)
        };
    }

    onListAskChanged: ScriptCommands.wantList(root.listAsk?.script ?? null, root.listAsk?.values ?? [])

    readonly property bool intent: root.listing || !!root.listAsk || root.matches.some(m => m.typed)

    function signature(script: var): string {
        return script.arguments.map(a => a.optional ? `[${a.placeholder}]` : `<${a.placeholder}>`).join(" ");
    }

    function shownValues(script: var, values: var): string {
        return values.map((v, i) => script.arguments[i]?.type === "password" ? "•••" : v).filter(Boolean).join(" · ");
    }

    function detailFor(script: var, values: var): string {
        const run = ScriptCommands.runs[script.path];
        if (run?.running)
            return "running";
        if (run && script.mode !== "fullOutput") {
            const last = (run.lines[run.lines.length - 1] ?? "").trim();
            const status = run.code === -1 ? "stopped" : run.code ? `exit ${run.code}` : "";
            return [status, last].filter(Boolean).join(" · ");
        }
        return root.shownValues(script, values) || script.packageName || script.description;
    }

    function scriptRow(script: var, values: var, score: real): var {
        const bare = !values.length && script.arguments.length > 0;
        return {
            key: `script:${script.file}`,
            kind: "script",
            script: script,
            values: values,
            label: bare ? `${script.title} ${root.signature(script)}` : script.title,
            detail: root.detailFor(script, values),
            icon: script.icon || "terminal",
            iconSource: script.iconFile,
            score: score
        };
    }

    readonly property var outputRows: {
        const top = root.matches[0];
        if (!top || top.score !== Infinity || top.script.mode !== "fullOutput")
            return [];
        const run = ScriptCommands.runs[top.script.path];
        if (!run || run.key !== Scripts.runKey(top.script, top.values))
            return [];
        return run.lines.slice(-40).map((line, i) => ({
                    key: `scriptline:${i}:${line}`,
                    kind: "scriptline",
                    label: line,
                    detail: "",
                    icon: "subdirectory_arrow_right",
                    score: Infinity
                }));
    }

    function itemRow(script: var, item: var, index: int, waiting: bool): var {
        return {
            key: `scriptitem:${script.file}:${index}:${item.uid || item.title}${waiting ? ":waiting" : ""}`,
            kind: "scriptitem",
            script: script,
            item: item,
            waiting: waiting,
            faded: waiting,
            label: item.title,
            detail: Scripts.refusalOf(item) || item.subtitle,
            icon: item.icon || (item.file ? "draft" : "chevron_right"),
            glyph: item.glyph,
            iconSource: item.iconFile,
            peekPath: item.file ? item.arg : "",
            score: Infinity
        };
    }

    function problemRow(script: var, label: string, icon: string): var {
        return {
            key: `scriptproblem:${script.file}:${label}`,
            kind: "scriptproblem",
            script: script,
            label: label,
            detail: script.title,
            icon: icon,
            score: Infinity
        };
    }

    readonly property var listRows: {
        const ask = root.listAsk;
        if (!ask)
            return [];
        const result = ScriptCommands.listFor(ask.script.path, ask.key);
        const fresh = ScriptCommands.listFresh(ask.key);
        const running = [Object.assign(root.scriptRow(ask.script, ask.values, Infinity), {
                detail: "running"
            })];
        if (!result || result.path !== ask.script.path || !fresh && (result.error || !result.items.length))
            return running;
        if (result.error)
            return [root.problemRow(ask.script, result.error, "error")];
        if (!result.items.length)
            return ScriptCommands.listPending(ask.key) ? running : [root.problemRow(ask.script, "No results", "search_off")];
        return result.items.map((item, i) => root.itemRow(ask.script, item, i, !fresh));
    }

    readonly property bool folderAsked: root.text.length >= 3 && Math.max(Ranking.place("script commands", root.text), Ranking.place("scripts", root.text), Ranking.place("new script", root.text)) >= Ranking.PREFIX

    readonly property var folderRows: !root.folderAsked ? [] : [
        {
            key: "scriptfolder",
            kind: "scriptfolder",
            label: ScriptCommands.folderExists ? "Open scripts folder" : "Create a script command",
            detail: ScriptCommands.folderExists ? (ScriptCommands.scripts.length === 1 ? "1 script" : `${ScriptCommands.scripts.length} scripts`) : ScriptCommands.folder.replace(Files.home, "~"),
            icon: ScriptCommands.folderExists ? "folder_open" : "add",
            score: root.listing ? Infinity : 0.4
        }
    ]

    readonly property var groups: [
        {
            key: "scripts",
            title: "Scripts",
            items: root.listAsk ? [] : root.matches.slice(0, root.outputRows.length ? 1 : root.listing ? 40 : 6).map(m => root.scriptRow(m.script, m.values, m.score)).concat(root.outputRows, root.folderRows)
        },
        {
            key: "scriptlist",
            title: root.listAsk?.script.title ?? "",
            items: root.listRows
        }
    ]

    readonly property var caps: ({
            scripts: 48,
            scriptlist: 50
        })

    readonly property var phrases: ScriptCommands.scripts.filter(s => s.arguments[0]?.type === "dropdown" && s.arguments[0].choices.length).map(s => ({
                head: `${s.title.toLowerCase()} `,
                picks: s.arguments[0].choices.map(c => c.value)
            }))

    function run(row: var): void {
        const script = row.script;
        if (script.mode === "list") {
            if (root.listAsk?.script.path === script.path)
                ScriptCommands.rerunList();
            else
                root.search.retype(`${script.title} `);
            return;
        }
        if (Scripts.missing(script, row.values).length) {
            root.search.retype(`${script.title} `);
            return;
        }
        if (script.mode === "silent")
            root.search.launch(() => ScriptCommands.run(script, row.values));
        else
            ScriptCommands.run(script, row.values);
    }

    function openFolder(): void {
        if (ScriptCommands.folderExists)
            root.search.leave(() => Files.show(ScriptCommands.folder));
        else
            root.search.leave(() => ScriptCommands.createExamples());
    }

    function itemActions(row: var): var {
        if (row.waiting)
            return [
                {
                    icon: "hourglass_empty",
                    label: "Waiting for the script",
                    run: () => {}
                }
            ];
        const item = row.item;
        const script = row.script;
        const action = Scripts.itemAction(item, script.selects);
        const copied = item.copy || item.arg || item.title;
        const link = item.url || item.arg;
        const choices = {
            run: {
                icon: "play_arrow",
                label: "Run",
                run: () => root.search.leave(() => ScriptCommands.select(script, item.arg))
            },
            url: {
                icon: "open_in_new",
                label: "Open link",
                short: "Open",
                run: () => root.search.launch(() => Files.openWith(link))
            },
            copy: {
                icon: "content_copy",
                label: "Copy",
                run: () => root.search.leave(() => Clipboard.copy({
                            text: copied
                        }))
            },
            file: {
                icon: "open_in_new",
                label: "Open",
                run: () => root.search.launch(() => Files.openWith(item.arg))
            },
            complete: {
                icon: "keyboard_tab",
                label: "Narrow down",
                run: () => root.complete(row)
            }
        };
        const out = choices[action] ? [choices[action]] : [
            {
                icon: "block",
                label: "Nothing to do",
                run: () => {}
            }
        ];
        if (action !== "copy" && (item.copy || item.arg))
            out.push(choices.copy);
        if (action !== "url" && item.url && !item.linkRefusal)
            out.push(choices.url);
        if (item.file && !item.fileRefusal)
            out.push({
                icon: "drive_file_move",
                label: "Show in folder",
                short: "Folder",
                run: () => root.search.leave(() => Files.reveal(item.arg))
            });
        return out.concat([
            {
                icon: "edit",
                label: "Edit script",
                tucked: true,
                run: () => root.search.leave(() => Projects.edit(script.path, script.path.slice(0, script.path.lastIndexOf("/"))))
            }
        ]);
    }

    function activate(row: var): void {
        switch (row.kind) {
        case "scriptitem":
            if (!row.waiting && (row.item.valid || row.item.autocomplete))
                root.itemActions(row)[0].run();
            return;
        case "scriptproblem":
            ScriptCommands.rerunList();
            return;
        case "script":
            root.run(row);
            return;
        case "scriptline":
            root.search.leave(() => Files.copyText(row.label));
            return;
        case "scriptfolder":
            root.openFolder();
            return;
        }
    }

    function actionsFor(row: var): var {
        if (row.kind === "scriptitem")
            return root.itemActions(row);
        if (row.kind === "scriptproblem")
            return [
                {
                    icon: "refresh",
                    label: "Run again",
                    run: () => ScriptCommands.rerunList()
                },
                {
                    icon: "edit",
                    label: "Edit script",
                    short: "Edit",
                    run: () => root.search.leave(() => Projects.edit(row.script.path, row.script.path.slice(0, row.script.path.lastIndexOf("/"))))
                }
            ];
        if (row.kind === "scriptline")
            return [
                {
                    icon: "content_copy",
                    label: "Copy line",
                    run: () => root.activate(row)
                }
            ];
        if (row.kind === "scriptfolder")
            return [
                {
                    icon: row.icon,
                    label: row.label,
                    run: () => root.activate(row)
                }
            ];
        const script = row.script;
        const folder = script.path.slice(0, script.path.lastIndexOf("/"));
        const run = ScriptCommands.runs[script.path];
        const out = [
            {
                icon: "play_arrow",
                label: "Run",
                run: () => root.activate(row)
            }
        ];
        if (run?.running)
            out.push({
                icon: "stop",
                label: "Stop",
                run: () => ScriptCommands.stop(script.path)
            });
        else if (run?.lines.length)
            out.push({
                icon: "content_copy",
                label: "Copy output",
                short: "Copy",
                run: () => root.search.leave(() => Files.copyText(run.lines.join("\n")))
            });
        return out.concat([
            {
                icon: "edit",
                label: "Edit script",
                short: "Edit",
                run: () => root.search.leave(() => Projects.edit(script.path, folder))
            },
            {
                icon: "drive_file_move",
                label: "Show in folder",
                tucked: true,
                run: () => root.search.leave(() => Files.reveal(script.path))
            }
        ]);
    }

    function complete(row: var): bool {
        if (row.kind === "scriptitem") {
            if (row.waiting || !row.item.autocomplete)
                return false;
            root.search.retype(`${row.script.title} ${row.item.autocomplete}`);
            return true;
        }
        if (row.kind !== "script" || !row.script.arguments.length && row.script.mode !== "list")
            return false;
        root.search.retype(`${row.script.title} `);
        return true;
    }

    function rowById(id: string): var {
        if (id.indexOf("script:") !== 0)
            return null;
        const file = id.slice(7);
        const script = ScriptCommands.scripts.find(s => s.file === file);
        return script ? root.scriptRow(script, [], 1) : null;
    }
}
