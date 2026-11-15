pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.config
import "mixer.js" as Logic

Singleton {
    id: root

    property bool windowOpen: false

    function show(): void {
        root.windowOpen = true;
    }

    function hide(): void {
        root.windowOpen = false;
    }

    function toggle(): void {
        root.windowOpen = !root.windowOpen;
    }

    onWindowOpenChanged: Relaunch.keep("mixer", {
        open: root.windowOpen
    })

    Component.onCompleted: {
        if (Relaunch.recall("mixer")?.open)
            root.show();
    }

    property var viewers: []
    readonly property bool watching: root.viewers.length > 0

    function watch(viewer: var, on: bool): void {
        const at = root.viewers.indexOf(viewer);
        if (on && at < 0)
            root.viewers = root.viewers.concat([viewer]);
        else if (!on && at >= 0)
            root.viewers = root.viewers.filter(v => v !== viewer);
    }

    function shownOf(nodes: var): var {
        return nodes.filter(n => !Logic.isPlumbing(n.properties));
    }

    readonly property var outputs: root.watching ? root.shownOf(Audio.playing) : []
    readonly property var inputs: root.watching ? root.shownOf(Audio.recording) : []

    readonly property var outputApps: root.appsOf(root.outputs, false)
    readonly property var inputApps: root.appsOf(root.inputs, true)

    readonly property var outputByKey: root.keyed(root.outputApps)
    readonly property var inputByKey: root.keyed(root.inputApps)

    function keyed(apps: var): var {
        const out = {};
        for (const app of apps)
            out[app.key] = app;
        return out;
    }

    function appsOf(nodes: var, listening: bool): var {
        const groups = Logic.group(nodes.map(n => ({
                        id: n.id,
                        node: n,
                        props: n.properties
                    })));
        for (const app of groups) {
            app.listening = listening;
            app.display = root.displayName(app);
            app.nodes = app.streams.map(s => s.node);
        }
        return Logic.byName(groups, a => a.display);
    }

    function displayName(app: var): string {
        if (app.named)
            return app.name;
        return Apps.entryFor(app.binary || app.name)?.name || app.name;
    }

    function iconOf(app: var): string {
        return AppIcons.markFor(app?.binary || app?.name || "", "colour");
    }

    function streamsOf(app: var): var {
        return (app?.nodes ?? []).map(n => ({
                    id: n.id,
                    props: n.properties,
                    volume: n.audio?.volume ?? 0,
                    muted: !!n.audio?.muted
                }));
    }

    function volumeOf(app: var): real {
        return Logic.volumeOf(root.streamsOf(app));
    }

    function mutedOf(app: var): bool {
        return Logic.mutedAll(root.streamsOf(app));
    }

    function stateOf(app: var): string {
        return Logic.state(root.streamsOf(app), root.heard, root.watching);
    }

    function titleOf(app: var): string {
        const nodes = app?.nodes ?? [];
        const loud = nodes.filter(n => root.heard[n.id]);
        for (const n of loud.concat(nodes)) {
            const t = Logic.title(n.properties, app.display);
            if (t)
                return t;
        }
        return "";
    }

    function peakOf(app: var): real {
        let most = 0;
        for (const n of app?.nodes ?? [])
            most = Math.max(most, root.watchOf(n)?.monitor.peak ?? 0);
        return most;
    }

    function setVolume(app: var, v: real): void {
        for (const n of app?.nodes ?? [])
            Audio.setStreamVolume(n, v);
    }

    function nudge(app: var, steps: int): void {
        root.setVolume(app, root.volumeOf(app) + steps * Config.values.volume.step / 100);
    }

    function setMuted(app: var, muted: bool): void {
        Audio.setStreamsMuted(app?.nodes ?? [], muted);
    }

    function toggleMute(app: var): void {
        root.setMuted(app, !root.mutedOf(app));
    }

    function deviceOf(app: var): var {
        const node = app?.nodes?.[0] ?? null;
        if (!node)
            return null;
        const groups = Pipewire.linkGroups.values;
        if (app.listening) {
            const feed = groups.find(g => g.target === node && g.source && !g.source.isStream);
            return feed?.source ?? null;
        }
        const out = groups.find(g => g.source === node && g.target?.isSink && !g.target.isStream);
        return out?.target ?? null;
    }

    function route(app: var, sink: var): void {
        for (const n of app?.nodes ?? [])
            Quickshell.execDetached(Logic.routeCommand(n.id, sink?.name ?? ""));
    }

    readonly property var soundingApps: root.outputApps.filter(a => root.stateOf(a) === "sound")
    readonly property string headline: Logic.headline(root.soundingApps.map(a => a.display), root.outputApps.length)

    function summaryNow(): string {
        return Logic.summary(root.appsOf(root.shownOf(Audio.playing), false).map(a => root.stateOf(a)));
    }

    function statusLine(): string {
        const line = apps => apps.map(a => `${a.display}=${root.stateOf(a)}`).join(",");
        return `open=${root.windowOpen} watching=${root.watching} apps=[${line(root.appsOf(root.shownOf(Audio.playing), false))}] listening=[${line(root.appsOf(root.shownOf(Audio.recording), true))}]`;
    }

    property var heard: ({})

    function hear(id: int, on: bool): void {
        if (!!root.heard[id] === on)
            return;
        const next = Object.assign({}, root.heard);
        if (on)
            next[id] = true;
        else
            delete next[id];
        root.heard = next;
    }

    property var watches: ({})

    function watchOf(node: var): var {
        return node ? root.watches[node.id] ?? null : null;
    }

    function recordsOutput(node: var): bool {
        return Pipewire.linkGroups.values.some(g => g.target === node && !!g.source?.isSink);
    }

    readonly property var watched: root.watching ? [Audio.sink, Audio.source].filter(Boolean).concat(root.outputs, root.inputs.filter(n => !root.recordsOutput(n))).slice(0, 40) : []

    Instantiator {
        model: ScriptModel {
            values: root.watched
        }

        delegate: QtObject {
            id: watch

            required property var modelData

            readonly property int nodeId: watch.modelData?.id ?? -1

            readonly property PwNodePeakMonitor monitor: PwNodePeakMonitor {
                node: watch.modelData
                enabled: root.watching

                onPeakChanged: watch.heardNow(watch.monitor.peak > Logic.HEARD)
            }

            property bool loud: false

            function heardNow(now: bool): void {
                if (now === watch.loud)
                    return;
                watch.loud = now;
                if (now) {
                    watch.quiet.stop();
                    root.hear(watch.nodeId, true);
                } else {
                    watch.quiet.restart();
                }
            }

            readonly property Timer quiet: Timer {
                interval: 1200
                onTriggered: root.hear(watch.nodeId, false)
            }

            Component.onDestruction: root.hear(watch.nodeId, false)
        }

        onObjectAdded: (index, object) => {
            const next = Object.assign({}, root.watches);
            next[object.nodeId] = object;
            root.watches = next;
        }

        onObjectRemoved: (index, object) => {
            if (root.watches[object.nodeId] !== object)
                return;
            const next = Object.assign({}, root.watches);
            delete next[object.nodeId];
            root.watches = next;
        }
    }
}
