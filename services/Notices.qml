pragma Singleton

import QtQuick
import Quickshell
import qs.config

Singleton {
    id: root

    readonly property bool live: !Quickshell.env("BANDITSHELL_PREVIEW")

    readonly property int glanceMs: Math.max(1, Config.values.island.glanceSeconds) * 1000

    readonly property bool updateShown: root.live && Update.state === Update.available && Config.values.sidebar.update !== "never"

    readonly property var standing: {
        const out = [];
        if (!root.live)
            return out;
        if (root.updateShown)
            out.push({
                key: `update:${Update.target}`,
                kind: "update",
                count: Update.behind,
                headline: Update.headline
            });
        if (Pacman.restartNeeded)
            out.push({
                key: `restart:${Pacman.installed}`,
                kind: "restart",
                version: Pacman.pretty(Pacman.installed)
            });
        else if (Pacman.kernelUpdate)
            out.push({
                key: `kernel:${Pacman.kernelUpdate.to}`,
                kind: "kernel",
                version: Pacman.pretty(Pacman.kernelUpdate.to),
                upgrading: Pacman.upgrading
            });
        return out;
    }

    property var passing: []

    property var glancing: []
    property var left: ({})

    readonly property var fresh: [...root.standing, ...root.passing].filter(n => root.glancing.includes(n.key))
    readonly property var settled: root.standing.filter(n => !root.glancing.includes(n.key))

    property var holders: []
    readonly property bool held: root.holders.length > 0

    function hold(who: var): void {
        if (!root.holders.includes(who))
            root.holders = [...root.holders.filter(h => h), who];
    }

    function release(who: var): void {
        root.holders = root.holders.filter(h => h && h !== who);
    }

    function glance(key: string, ms: var): void {
        root.left[key] = ms > 0 ? ms : root.glanceMs;
        if (!root.glancing.includes(key))
            root.glancing = [...root.glancing, key];
    }

    function settle(key: string): void {
        delete root.left[key];
        root.glancing = root.glancing.filter(k => k !== key);
        root.passing = root.passing.filter(n => n.key !== key);
    }

    readonly property int passingMax: 3

    function pass(notice: var): void {
        root.passing = [notice, ...root.passing.filter(n => n.key !== notice.key)].slice(0, root.passingMax);
        root.glance(notice.key, notice.ms);
        root.prune();
    }

    function prune(): void {
        const live = new Set([...root.standing, ...root.passing].map(n => n.key));
        if (root.glancing.some(k => !live.has(k)))
            root.glancing = root.glancing.filter(k => live.has(k));
    }

    onStandingChanged: root.meet()
    Component.onCompleted: root.meet()

    function meet(): void {
        const seen = kept.seen ? kept.seen.split("\n") : [];
        const fresh = root.standing.filter(n => !seen.includes(n.key));
        for (const n of fresh)
            root.glance(n.key);
        if (fresh.length > 0)
            kept.seen = [...seen, ...fresh.map(n => n.key)].slice(-50).join("\n");
        root.prune();
    }

    PersistentProperties {
        id: kept

        reloadableId: "notices"

        property string seen: ""
    }

    Timer {
        interval: 100
        repeat: true
        running: root.glancing.length > 0 && !root.held

        onTriggered: {
            const done = [];
            for (const key of root.glancing) {
                root.left[key] = (root.left[key] ?? 0) - interval;
                if (root.left[key] <= 0)
                    done.push(key);
            }
            for (const key of done)
                root.settle(key);
        }
    }

    readonly property string track: Media.hasTrack ? `${Media.title}\n${Media.artist}` : ""
    property string heard: ""
    property bool awake: false

    onTrackChanged: {
        const was = root.heard;
        root.heard = root.track;
        if (root.awake && root.track && root.track !== was && Media.playing && Config.values.island.nowPlaying)
            root.pass({
                key: "music",
                kind: "music"
            });
    }

    Timer {
        interval: 5000
        running: true
        onTriggered: {
            root.heard = root.track;
            root.awake = true;
        }
    }

    Connections {
        target: Downloads
        enabled: root.live

        function onArrived(names: var, dir: string): void {
            const at = Date.now();
            root.pass({
                key: `download:${at}:${names[0]}`,
                kind: "download",
                name: names[0],
                path: `${dir}/${names[0]}`,
                more: names.length - 1
            });
        }
    }

    Connections {
        target: Notifications

        function onHeldReleased(count: int): void {
            root.pass({
                key: `held:${Date.now()}`,
                kind: "held",
                count: count
            });
        }
    }
}
