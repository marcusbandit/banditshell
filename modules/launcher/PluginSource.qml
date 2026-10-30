import QtQuick
import Quickshell
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
        return Object.assign({
            key: `plugin:${root.pluginId}:${item.id}`,
            kind: root.kind,
            item: item,
            label: item.title,
            detail: item.refusal || item.subtitle,
            score: score
        }, root.iconOf(item.icon));
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
        if (!root.current)
            return asked.prefixed ? [root.problemRow(root.state.until > Date.now() ? `${plugin.name} is starting again` : `Asking ${plugin.name}`, "", "hourglass_empty", "waiting")] : [];
        if (root.answer.late)
            return asked.prefixed ? [root.problemRow(`${plugin.name} did not answer in time`, "Enter opens its log", "timer_off", "late")] : [];
        if (asked.prefixed)
            return root.answer.items.map(item => root.rowOf(item, Infinity));
        return root.answer.items.map(item => ({
                    item: item,
                    score: Protocol.plainScore(item, asked.text, Ranking.place)
                })).filter(m => m.score > 0).sort((a, b) => b.score - a.score).map(m => root.rowOf(m.item, m.score - Ranking.EXACT));
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
            if (PluginHost.show(root.pluginId, message.view, root))
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

    function runInPage(target: var, action: string, view: string): void {
        if (Protocol.local(target) || target.refusal)
            root.doLocal(target);
        else
            PluginHost.activate(root.pluginId, target.id, action, root, view);
    }

    function submit(view: string, values: var): void {
        PluginHost.submit(root.pluginId, view, values, root);
    }

    function choiceOf(row: var, doing: var, action: string, title: string, icon: string): var {
        return {
            icon: icon || (doing?.open ? "open_in_new" : doing?.copy ? "content_copy" : doing?.run.length ? "play_arrow" : "chevron_right"),
            label: title,
            run: () => doing ? root.doLocal(doing) : PluginHost.activate(root.pluginId, row.item.id, action, root, "")
        };
    }

    function activate(row: var): void {
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
        if (row.problem)
            return row.problem === "waiting" ? [] : [
                {
                    icon: row.icon,
                    label: row.detail.replace(/^Enter /, "").replace(/^./, c => c.toUpperCase()),
                    run: () => root.solve(row)
                }
            ];
        const item = row.item;
        const own = Protocol.local(item) || item.refusal ? [root.choiceOf(row, item, "", item.open ? "Open" : item.copy ? "Copy" : "Run", "")] : [];
        const listed = item.actions.map(a => root.choiceOf(row, Protocol.local(a) || a.refusal ? a : null, a.id, a.title, a.icon));
        const out = own.concat(listed);
        return out.length ? out : [root.choiceOf(row, null, "", "Open", "")];
    }

    function complete(row: var): bool {
        if (row.problem)
            return false;
        PluginHost.complete(root.pluginId, row.item.id, root);
        return true;
    }

    function rowById(id: string): var {
        const prefix = `plugin:${root.pluginId}:`;
        if (id.indexOf(prefix) !== 0)
            return null;
        const item = (root.answer?.items ?? []).find(i => i.id === id.slice(prefix.length));
        return item ? root.rowOf(item, 1) : null;
    }
}
