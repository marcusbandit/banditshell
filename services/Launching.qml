pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property var cfg: Config.values.launcher.opening

    property var pending: []

    property real now: 0

    property var shown: []

    function visible(rec: var): bool {
        return (rec.state === "waiting" ? root.now : rec.done) - rec.at > root.cfg.graceMs;
    }

    function start(entry: var): void {
        if (!entry)
            return;

        const id = entry.id ?? entry.name ?? "";
        const rec = {
            id: id,
            name: entry.name || id,
            mark: root.markFor(entry),
            marks: root.marksFor(entry),
            at: Date.now(),
            state: "waiting",
            done: 0
        };

        root.pending = [...root.pending.filter(r => r.id !== id), rec];
        root.now = rec.at;
        tick.start();
    }

    function markFor(entry: var): string {
        const art = entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
        return art ? `image:${art}` : `symbol:${Apps.iconFor(entry.id ?? entry.name ?? "")}`;
    }

    function marksFor(entry: var): var {
        const out = [];
        const add = s => {
            const k = root.key(s);
            if (k && !out.includes(k))
                out.push(k);
        };

        const id = (entry.id ?? "").replace(/\.desktop$/i, "");
        add(entry.startupClass);
        add(id);
        add(entry.name);
        add(((entry.command ?? [])[0] ?? "").split("/").pop());
        for (const v of Apps.nameVariants(id))
            add(v);
        return out;
    }

    function key(s: string): string {
        return (s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    function fits(rec: var, cls: string): bool {
        const k = root.key(cls);
        if (k.length < 3)
            return false;
        return rec.marks.some(m => m.length >= 3 && (m === k || m.includes(k) || k.includes(m)));
    }

    function settle(cls: string): void {
        const waiting = root.pending.filter(r => r.state === "waiting");
        if (!waiting.length)
            return;
        root.land(waiting.find(r => root.fits(r, cls)) ?? waiting[0], cls);
    }

    function noticeFocus(cls: string): void {
        const hit = root.pending.find(r => r.state === "waiting" && root.fits(r, cls));
        if (hit)
            root.land(hit, cls);
    }

    function land(rec: var, cls: string): void {
        if (!rec || rec.state !== "waiting")
            return;
        rec.state = "here";
        rec.done = Date.now();

        if (root.fits(rec, cls))
            root.learn(rec.id, rec.done - rec.at);
        root.pending = root.pending.slice();

        root.shown = root.pending.filter(r => root.visible(r));
    }

    function expected(id: string): real {
        return root.times[id]?.ms ?? root.cfg.assumeMs;
    }

    function ceiling(rec: var): real {
        return Math.max(root.cfg.giveUpMs, root.expected(rec.id) * root.cfg.giveUpFactor);
    }

    readonly property real curve: 1.8

    function progress(rec: var): real {
        if (rec.state !== "waiting")
            return 1;
        return 1 - Math.exp(-root.curve * (root.now - rec.at) / Math.max(1, root.expected(rec.id)));
    }

    Timer {
        id: tick

        interval: 40
        repeat: true
        running: false

        onTriggered: {
            const now = Date.now();
            root.now = now;

            const kept = [];
            let changed = false;

            for (const rec of root.pending) {
                if (rec.state === "waiting") {
                    if (now - rec.at > root.ceiling(rec)) {
                        rec.state = "lost";
                        rec.done = now;
                        changed = true;
                    }
                    kept.push(rec);
                    continue;
                }

                if (now - rec.done > (rec.state === "here" ? root.cfg.landedMs : root.cfg.lostMs)) {
                    changed = true;
                    continue;
                }
                kept.push(rec);
            }

            if (changed)
                root.pending = kept;

            const live = kept.filter(r => root.visible(r));
            if (changed || live.length !== root.shown.length || live.some((r, i) => r !== root.shown[i]))
                root.shown = live;

            if (!kept.length)
                tick.stop();
        }
    }

    Connections {
        target: Hypr

        function onWindowOpened(addr: string, title: string, cls: string): void {
            root.settle(cls);
        }

        function onFocusedAddressChanged(): void {
            const bare = root.bare(Hypr.focusedAddress);
            if (!bare)
                return;
            const client = Hyprland.toplevels.values.find(t => root.bare(t.address ?? "") === bare);
            if (client)
                root.noticeFocus(Hypr.classOf(client));
        }
    }

    function bare(addr: string): string {
        return (addr.startsWith("0x") ? addr.slice(2) : addr).toLowerCase();
    }

    readonly property string path: `${Apps.dir}/startup.json`

    property var times: ({})

    function learn(id: string, ms: real): void {
        if (!id || ms <= 0)
            return;

        const old = root.times[id]?.ms;
        const a = root.cfg.learn;
        root.times = Object.assign({}, root.times, {
            [id]: {
                ms: Math.round(old ? old * (1 - a) + ms * a : ms)
            }
        });
        store.setText(JSON.stringify(root.times));
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object" && !Array.isArray(data))
                    root.times = data;
                else
                    console.warn(`Launching: ${root.path} does not hold a table of times, starting them over.`);
            } catch (e) {
                console.warn(`Launching: ${root.path} is not valid JSON, starting the times over.`, e);
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", Apps.dir]
    }
}
