import QtQuick
import Quickshell
import qs.config
import qs.services
import "../../services/plugin-protocol.js" as Protocol
import "../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    property string pluginId: ""

    readonly property var plugin: PluginHost.pluginOf(root.pluginId)

    readonly property string kind: `plugin-${root.pluginId}`

    readonly property var kinds: [root.kind]

    readonly property bool watching: root.search.active && root.search.presents

    onWatchingChanged: PluginHost.watch(root, root.watching)

    Component.onCompleted: PluginHost.watch(root, root.watching)

    Component.onDestruction: PluginHost.watch(root, false)

    readonly property var asked: root.plugin && root.search.active ? Protocol.asked(root.plugin, root.search.query) : null

    readonly property string askKey: root.asked ? `${root.asked.prefixed}\n${root.asked.text}` : ""

    onAskKeyChanged: {
        if (root.askKey)
            pause.restart();
        else
            pause.stop();
    }

    property Timer pause: Timer {
        interval: 120
        onTriggered: {
            pause.interval = 120;
            if (!root.asked)
                return;
            const wait = PluginHost.ask(root.pluginId, root.asked.text, root.asked.prefixed, root);
            if (wait > 0) {
                pause.interval = wait;
                pause.restart();
            }
        }
    }

    readonly property bool intent: !!root.asked?.prefixed

    readonly property var answer: PluginHost.answers[root.pluginId] ?? null

    readonly property var state: PluginHost.stateOf(root.pluginId)

    onStateChanged: {
        if (root.askKey && !root.state.off)
            pause.restart();
    }

    readonly property var missing: PluginHost.missingOf(root.pluginId)

    readonly property string rank: Protocol.rankOf(Config.values.launcher.plugins.rank)

    readonly property bool current: !!root.answer && !!root.asked && root.answer.text === root.asked.text && root.answer.prefixed === root.asked.prefixed

    function iconOf(icon: var): var {
        const own = icon?.name || icon?.glyph || icon?.file ? icon : root.plugin?.icon ?? {};
        return {
            icon: own.name ?? (own.glyph || own.file ? "" : "extension"),
            glyph: own.glyph ?? "",
            iconSource: own.file ? Protocol.fileUrl(own.file) : ""
        };
    }

    function rowOf(item: var, score: real): var {
        const span = item.height;
        const preview = item.preview;
        const facts = preview?.facts ? preview : null;
        return Object.assign({
            key: `plugin:${root.pluginId}:${item.id}`,
            kind: root.kind,
            item: item,
            owner: root,
            label: item.title,
            detail: item.refusal || item.subtitle,
            score: score,
            span: span,
            tags: item.tags,
            card: item.qml || span !== 1 ? root.rowCard : null,
            peekText: facts ? "" : preview?.text ?? "",
            peekImage: preview?.image ?? "",
            peekPath: preview?.file ?? "",
            peekCard: preview?.qml ? root.previewCard : facts ? root.factsCard : null,
            entry: preview?.qml ? {
                owner: root,
                item: item,
                qml: preview.qml
            } : facts
        }, root.iconOf(item.icon), item.image && span === 1 && !item.qml ? {
            iconSource: item.image
        } : {});
    }

    function shown(items: var, asked: var): var {
        if (asked.prefixed)
            return items.map(item => root.rowOf(item, Infinity));
        return Protocol.plainRows(items, asked.text, root.rank, Ranking.place).map(m => root.rowOf(m.item, m.score));
    }

    function problemRow(label: string, detail: string, icon: string, problem: string): var {
        return {
            key: `plugin:${root.pluginId}:!${problem}`,
            kind: root.kind,
            problem: problem,
            label: label,
            detail: detail,
            icon: icon,
            faded: problem === "waiting",
            score: Infinity
        };
    }

    readonly property var rows: {
        const asked = root.asked;
        const plugin = root.plugin;
        if (!asked || !plugin)
            return [];
        if (root.state.off)
            return asked.prefixed ? [root.problemRow(`${plugin.name} stopped after crashing three times`, "Enter opens its log", "error", "off")] : [];
        if (root.missing.length) {
            const named = plugin.preferences.filter(p => root.missing.includes(p.key)).map(p => p.title.toLowerCase()).join(" and ");
            return asked.prefixed ? [root.problemRow(`${plugin.name} needs its ${named}`, "Enter opens its settings", "settings", "settings")] : [];
        }
        if (!root.current) {
            const kept = Protocol.kept(root.answer, asked);
            if (kept.length)
                return root.shown(kept, asked);
            return asked.prefixed ? [root.problemRow(root.state.until > Date.now() ? `${plugin.name} is starting again` : `Asking ${plugin.name}`, "", "hourglass_empty", "waiting")] : [];
        }
        if (root.answer.late)
            return asked.prefixed ? [root.problemRow(`${plugin.name} did not answer in time`, "Enter opens its log", "timer_off", "late")] : [];
        return root.shown(root.answer.items, asked);
    }

    readonly property var groups: [
        {
            key: `plugin:${root.pluginId}`,
            title: root.plugin?.name ?? "",
            items: root.rows
        }
    ]

    readonly property var caps: ({
            [`plugin:${root.pluginId}`]: root.asked?.prefixed ? Protocol.ITEM_LIMIT : root.plugin?.global?.cap ?? 0
        })

    readonly property var prefixes: root.plugin?.prefix.length ? [
        {
            section: "Plugins",
            word: root.plugin.prefix[0],
            example: `${root.plugin.prefix[0]} …`,
            about: root.plugin.about || root.plugin.name,
            icon: root.plugin.icon.name ?? "extension",
            also: root.plugin.prefix.slice(1)
        }
    ] : []

    function doLocal(doing: var): void {
        if (doing.refusal)
            return;
        if (doing.open)
            root.search.launch(() => System.openWith(doing.open));
        else if (doing.copy)
            root.search.leave(() => System.copyText(doing.copy));
        else if (doing.run.length)
            root.search.launch(() => Quickshell.execDetached(doing.run));
    }

    property Component pageView: Component {
        PluginView {}
    }

    property Component rowCard: Component {
        PluginRow {}
    }

    property Component previewCard: Component {
        PluginPreview {}
    }

    property Component factsCard: Component {
        PluginFacts {}
    }

    function handle(message: var): void {
        if (message.type === "fill") {
            root.search.retype(message.text);
            return;
        }
        if (message.type === "view") {
            if (!root.search.presents) {
                PluginHost.note(root.pluginId, "skipped a view this launcher cannot show");
                return;
            }
            if (PluginHost.show(root.pluginId, message.view, root, root.search.presenting))
                root.search.present({
                    component: root.pageView,
                    text: message.view.title
                });
            return;
        }
        switch (message.do) {
        case "copy":
            root.search.leave(() => System.copyText(message.text));
            return;
        case "open":
            root.search.launch(() => System.openWith(message.target));
            return;
        case "notify":
            Notify.post({
                summary: message.title,
                body: message.body
            });
            return;
        case "close":
            root.search.leave(() => {});
            return;
        }
    }

    function solve(row: var): void {
        switch (row.problem) {
        case "off":
        case "late":
            root.search.leave(() => System.openWith(PluginHost.logOf(root.pluginId)));
            return;
        case "settings":
            root.search.leave(() => Panels.open("settings", {
                    screen: root.search.screenName,
                    page: "launcher"
                }));
            return;
        }
    }

    function act(item: var, action: var, view: string): void {
        const id = typeof action === "string" ? action : "";
        const listed = id ? item.actions.find(a => a.id === id) : null;
        const enter = id ? null : Protocol.enterOf(item);
        if (listed && (Protocol.local(listed) || listed.refusal))
            root.doLocal(listed);
        else if (enter?.local)
            root.doLocal(enter.local);
        else
            PluginHost.activate(root.pluginId, item.id, id || enter.action, root, view);
    }

    function copyOut(text: var): void {
        const copied = String(text ?? "");
        root.search.leave(() => System.copyText(copied));
    }

    function openOut(target: var): void {
        const opened = String(target ?? "");
        const refusal = opened ? Protocol.targetRefusal(opened) : "open without a target";
        if (refusal)
            PluginHost.note(root.pluginId, `its QML ${refusal}`);
        else
            root.search.launch(() => System.openWith(opened));
    }

    function fillOut(text: var): void {
        root.search.retype(String(text ?? ""));
    }

    function closeOut(): void {
        root.search.leave(() => {});
    }

    function activateIn(item: string, action: string, view: string): void {
        PluginHost.activate(root.pluginId, item, action, root, view);
    }

    function submit(view: string, values: var): void {
        PluginHost.submit(root.pluginId, view, values, root);
    }

    function choiceOf(row: var, doing: var, action: string, title: string, icon: string, chord: string): var {
        return {
            icon: icon || (doing?.open ? "open_in_new" : doing?.copy ? "content_copy" : doing?.run.length ? "play_arrow" : "chevron_right"),
            label: title,
            chord: chord,
            keys: Protocol.chordLabel(chord),
            run: () => doing ? root.doLocal(doing) : PluginHost.activate(root.pluginId, row.item.id, action, root, "")
        };
    }

    function activate(row: var): void {
        if (row.cold) {
            PluginHost.activateCold(root.pluginId, row.cold);
            return;
        }
        if (row.problem) {
            root.solve(row);
            return;
        }
        const enter = Protocol.enterOf(row.item);
        if (enter.local)
            root.doLocal(enter.local);
        else
            PluginHost.activate(root.pluginId, row.item.id, enter.action, root, "");
    }

    function actionsFor(row: var): var {
        if (row.cold)
            return [];
        if (row.problem)
            return row.problem === "waiting" ? [] : [
                {
                    icon: row.icon,
                    label: row.detail.replace(/^Enter /, "").replace(/^./, c => c.toUpperCase()),
                    run: () => root.solve(row)
                }
            ];
        const item = row.item;
        const own = Protocol.local(item) || item.refusal ? [root.choiceOf(row, item, "", item.open ? "Open" : item.copy ? "Copy" : "Run", "", "")] : [];
        const listed = item.actions.map(a => root.choiceOf(row, Protocol.local(a) || a.refusal ? a : null, a.id, a.title, a.icon, a.chord));
        const out = own.concat(listed);
        return out.length ? out : [root.choiceOf(row, null, "", "Open", "", "")];
    }

    function complete(row: var): bool {
        if (row.problem)
            return false;
        PluginHost.complete(root.pluginId, row.item.id, root);
        return true;
    }

    function rowById(id: string): var {
        const prefix = `plugin:${root.pluginId}:`;
        if (id.indexOf(prefix) !== 0 || !root.plugin)
            return null;
        const itemId = id.slice(prefix.length);
        const item = (root.answer?.items ?? []).find(i => i.id === itemId);
        if (item)
            return root.rowOf(item, 1);
        return itemId ? {
            key: id,
            kind: root.kind,
            cold: itemId,
            label: Config.values.launcher.hotkeys[id]?.label || itemId,
            icon: root.plugin.icon.name ?? "extension",
            score: 1
        } : null;
    }
}
