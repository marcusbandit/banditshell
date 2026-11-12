import QtQuick
import qs.services
import "../search.js" as Search
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property string text: root.search.text
    readonly property int asked: Search.volumeLevelAsk(root.text)
    readonly property int masterLevel: root.asked > root.ceiling ? root.ceiling : Search.volumeAsk(root.text)
    readonly property var streamAsk: root.masterLevel < 0 ? Search.streamVolumeAsk(root.text) : null
    readonly property bool mixer: Search.mixerAsk(root.text)
    readonly property string named: root.masterLevel < 0 && !root.streamAsk ? Search.streamNameAsk(root.text) : ""
    readonly property int ceiling: Math.round(Audio.maxVolume * 100)

    readonly property var kinds: ["stream", "appmute"]
    readonly property var caps: ({
            sound: root.mixer ? 12 : 5
        })
    readonly property bool intent: root.masterLevel >= 0 || root.rows.some(r => r.level >= 0)

    readonly property var groups: [
        {
            key: "sound",
            title: "Sound",
            items: root.rows
        }
    ]

    function levelRow(node: var, name: string, level: int, score: real, look: var): var {
        return Object.assign({
            key: `stream:${node.id}${level >= 0 ? `:${level}` : ""}`,
            kind: "stream",
            node: node,
            level: level,
            label: level >= 0 ? `Set ${name} to ${level}%` : name,
            detail: "",
            toggle: !Audio.streamMuted(node),
            slider: {
                value: () => Audio.streamVolume(node),
                set: v => Audio.setStreamVolume(node, v),
                to: Audio.maxVolume
            },
            score: score
        }, look);
    }

    function masterRow(): var {
        const sink = Audio.sink;
        const level = Math.min(root.masterLevel, root.ceiling);
        const score = level >= 0 || root.mixer ? Infinity : Math.max(Ranking.place("volume", root.text), Ranking.place("sound output speakers audio", root.text) - 0.5);
        if (!sink || score <= 0 || root.streamAsk)
            return null;
        return root.levelRow(sink, "volume", level, score, {
            label: level >= 0 ? `Set volume to ${level}%` : "Volume",
            detail: root.asked > root.ceiling ? `${Audio.deviceLabel(sink)} · ${root.ceiling}% is the most` : Audio.deviceLabel(sink),
            icon: Audio.deviceIcon(sink)
        });
    }

    function streamRow(node: var): var {
        const name = Search.streamName(Audio.streamLabel(node));
        const binary = Audio.streamBinary(node);
        const ask = root.streamAsk;
        const wanted = ask?.name ?? root.named;
        if (wanted && Ranking.place(name, wanted) <= 0 && Ranking.place(binary, wanted) <= 0)
            return null;
        const level = ask ? Math.min(ask.level, root.ceiling) : -1;
        const score = wanted || root.mixer ? Infinity : Math.max(Ranking.place(name, root.text), Ranking.place(binary, root.text));
        return score > 0 ? root.levelRow(node, name, level, score, {
            iconSource: Apps.iconSourceFor([binary, name]),
            icon: "graphic_eq"
        }) : null;
    }

    function appMuteRow(): var {
        const score = Math.max(Ranking.place("mute active app", root.text), Ranking.place("mute unmute focused current window application sound", root.text) - 0.5);
        if (score <= 0)
            return null;
        const nodes = Search.streamsForWindow(Audio.playing.map(node => ({
                    binary: Audio.streamBinary(node),
                    name: Search.streamName(Audio.streamLabel(node)),
                    node: node
                })), root.search.targetState.class).map(s => s.node);
        if (!nodes.length)
            return null;
        return {
            key: "appmute",
            kind: "appmute",
            nodes: nodes,
            label: "Mute active app",
            detail: Search.streamName(Audio.streamLabel(nodes[0])),
            icon: "graphic_eq",
            toggle: nodes.every(n => Audio.streamMuted(n)),
            score: score
        };
    }

    readonly property var rows: {
        if (root.text.length < 3 || !Audio.ready)
            return [];
        const master = root.masterRow();
        const streams = root.masterLevel >= 0 ? [] : Audio.playing.map(node => root.streamRow(node)).filter(Boolean).sort((a, b) => b.score - a.score);
        const app = root.appMuteRow();
        return (master ? [master] : []).concat(streams, app ? [app] : []);
    }

    function activate(row: var): void {
        if (row.kind === "appmute")
            Audio.setStreamsMuted(row.nodes, !row.toggle);
        else if (row.level >= 0)
            Audio.setStreamVolume(row.node, row.level / 100);
        else
            Audio.toggleStreamMute(row.node);
    }

    function actionsFor(row: var): var {
        if (row.kind === "appmute")
            return [
                {
                    icon: row.toggle ? "volume_up" : "volume_off",
                    label: row.toggle ? "Unmute" : "Mute",
                    run: () => root.activate(row)
                }
            ];
        if (row.level >= 0)
            return [
                {
                    icon: "volume_up",
                    label: row.label,
                    run: () => root.activate(row)
                }
            ];
        const muted = Audio.streamMuted(row.node);
        return [
            {
                icon: muted ? "volume_up" : "volume_off",
                label: muted ? "Unmute" : "Mute",
                run: () => root.activate(row)
            }
        ];
    }
}
