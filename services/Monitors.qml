pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    property var outputs: []

    property string selected: ""

    readonly property var selectedOutput: root.outputs.find(m => m.name === root.selected) ?? null

    readonly property var scaleChoices: [0.5, 0.6667, 0.75, 1, 1.25, 1.5, 1.75, 2]

    readonly property var transformChoices: [{
            value: 0,
            label: "normal"
        }, {
            value: 1,
            label: "90°"
        }, {
            value: 2,
            label: "180°"
        }, {
            value: 3,
            label: "270°"
        }]

    function parseMode(s: string): var {
        const m = /^(\d+)x(\d+)@([\d.]+)Hz$/.exec(s ?? "");
        return m ? {
            w: +m[1],
            h: +m[2],
            hz: +m[3]
        } : null;
    }

    function modeString(w: int, h: int, hz: real): string {
        return `${w}x${h}@${Math.round(hz)}`;
    }

    function specFor(m: var): var {
        let mode = root.modeString(m.width, m.height, m.refreshRate);
        for (const s of m.availableModes ?? []) {
            const p = root.parseMode(s);
            if (p && p.w === m.width && p.h === m.height && Math.round(p.hz) === Math.round(m.refreshRate)) {
                mode = root.modeString(p.w, p.h, p.hz);
                break;
            }
        }
        return {
            output: m.name,
            mode,
            position: `${m.x}x${m.y}`,
            scale: m.scale,
            transform: m.transform,
            vrr: m.vrr ? 1 : 0
        };
    }

    function layoutOf(m: var): var {
        const odd = m.transform % 2 === 1;
        return {
            w: Math.round((odd ? m.height : m.width) / m.scale),
            h: Math.round((odd ? m.width : m.height) / m.scale)
        };
    }

    property var queued: ({})

    function flushQueued(): void {
        const name = Object.keys(root.queued)[0];
        if (!name)
            return;
        const spec = root.queued[name];
        const rest = Object.assign({}, root.queued);
        delete rest[name];
        root.queued = rest;
        root.applySpec(spec);
    }

    Connections {
        target: HyprConfig

        function onReadyChanged(): void {
            if (HyprConfig.ready)
                root.flushQueued();
        }
    }

    function applySpec(spec: var): void {
        if (!spec?.output)
            return;

        if (HyprConfig.applying || !HyprConfig.ready) {
            root.queued = Object.assign({}, root.queued, {
                [spec.output]: spec
            });
            return;
        }

        root.pending = Object.assign({}, root.pending, {
            [spec.output]: spec
        });

        const entry = HyprConfig.monitors.find(m => !m.dynamic && m.output === spec.output);
        if (entry)
            HyprConfig.updateMonitor(entry.id, {
                mode: spec.mode,
                position: spec.position,
                scale: spec.scale,
                transform: spec.transform,
                vrr: spec.vrr
            });
        else

            HyprConfig.addMonitor((HyprConfig.outputTables[0]?.file ?? "lua/monitors.lua"), spec);

        settle.restart();
    }

    property var pending: ({})

    function displaySpec(name: string): var {
        if (root.pending[name])
            return root.pending[name];
        const m = root.outputs.find(o => o.name === name);
        return m ? root.specFor(m) : null;
    }

    function apply(name: string, fields: var): void {
        const base = root.pending[name] ?? root.specFor(root.outputs.find(o => o.name === name));
        if (!base)
            return;
        root.applySpec(Object.assign({}, base, fields));
    }

    function refresh(): void {
        probe.running = true;
    }

    Process {
        id: probe

        command: ["hyprctl", "-j", "monitors"]

        stdout: StdioCollector {
            onStreamFinished: {
                let mons = [];
                try {
                    mons = JSON.parse(text);
                } catch (e) {}
                if (!mons.length)
                    return;
                root.outputs = mons.map(m => ({
                        name: m.name,
                        description: [m.make, m.model].filter(p => p).join(" "),
                        x: m.x,
                        y: m.y,
                        width: m.width,
                        height: m.height,
                        scale: m.scale,
                        transform: m.transform,
                        vrr: !!m.vrr,
                        refreshRate: m.refreshRate,
                        availableModes: m.availableModes ?? [],
                        focused: !!m.focused,
                        disabled: !!m.disabled
                    }));

                if (!root.outputs.some(m => m.name === root.selected))
                    root.selected = root.outputs.find(m => m.focused)?.name ?? root.outputs[0]?.name ?? "";

                const still = Object.assign({}, root.pending);
                for (const name in still) {
                    const m = root.outputs.find(o => o.name === name);
                    if (m) {
                        const s = still[name];
                        const cur = root.specFor(m);
                        if (s.mode === cur.mode && s.position === cur.position && Math.abs(s.scale - cur.scale) < 0.001 && s.transform === cur.transform && s.vrr === cur.vrr)
                            delete still[name];
                    } else {
                        delete still[name];
                    }
                }
                root.pending = still;
            }
        }
    }

    Timer {
        id: settle

        interval: 400
        onTriggered: {
            root.refresh();

            late.restart();
        }
    }

    Timer {
        id: late

        interval: 800
        onTriggered: root.refresh()
    }

    Connections {
        target: Hyprland

        function onMonitorAdded(): void {
            settle.restart();
        }

        function onMonitorRemoved(): void {
            settle.restart();
        }
    }

    Connections {
        target: Hypr

        function onConfigReloaded(): void {
            root.refresh();
        }
    }

    Component.onCompleted: root.refresh()
}
