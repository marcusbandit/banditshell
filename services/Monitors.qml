pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "monitor-rules.js" as MonitorRules

Singleton {
    id: root

    property var outputs: []

    readonly property var active: root.outputs.filter(m => !m.disabled)

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
        if (m.disabled || !(m.width > 0)) {
            const entry = HyprConfig.monitorEntry(m.name);
            return Object.assign({
                output: m.name
            }, MonitorRules.restingFields(m, entry), {
                disabled: !!m.disabled,
                mirror: m.mirror ?? ""
            });
        }
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
            vrr: m.vrr ? 1 : 0,
            disabled: false,
            mirror: m.mirror ?? ""
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
        root.write(spec);
    }

    Connections {
        target: HyprConfig

        function onReadyChanged(): void {
            if (HyprConfig.ready)
                root.flushQueued();
        }

        function onMonitorSettled(output: string, ok: bool, said: string): void {
            root.settled(output, ok, said);
        }
    }

    function plan(specs: var, name: string, change: var): var {
        return MonitorRules.plan(specs, name, change);
    }

    function mirrorChoices(specs: var, name: string): var {
        return MonitorRules.mirrorChoices(specs, name);
    }

    function intent(name: string): var {
        return root.queued[name] ?? root.displaySpec(name);
    }

    function applySpec(spec: var): string {
        return root.applySpecs([spec]);
    }

    function applySpecs(list: var): string {
        const intents = {};
        for (const m of root.outputs)
            intents[m.name] = root.intent(m.name);
        const why = MonitorRules.violation(MonitorRules.guardSpecs(root.outputs, intents, list));
        if (why) {
            console.warn(`Monitors: not applied; ${why}.`);
            return why;
        }
        for (const spec of MonitorRules.writeOrder(list, root.outputs))
            root.write(spec);
        return "";
    }

    signal failed(string output, string said)

    function settled(output: string, ok: bool, said: string): void {
        if (ok)
            return;
        const attempted = root.pending[output] ?? null;
        const rest = Object.assign({}, root.pending);
        delete rest[output];
        root.pending = rest;
        let note = said;
        if (attempted && MonitorRules.turnsOn(attempted, root.outputs)) {
            const kept = MonitorRules.dropTurnOffs(root.queued);
            if (Object.keys(kept).length !== Object.keys(root.queued).length) {
                root.queued = kept;
                note = `${said} · the screens waiting to turn off stay on`;
            }
        }
        console.warn(`Monitors: ${output} was not written; ${note}.`);
        root.failed(output, note);
    }

    function write(spec: var): void {
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

        const fields = MonitorRules.entryFields(spec);
        const entry = HyprConfig.monitorEntry(spec.output);
        if (entry)
            HyprConfig.updateMonitor(entry.id, fields);
        else
            HyprConfig.addMonitor((HyprConfig.outputTable()?.file ?? HyprConfig.outputTables[0]?.file ?? "lua/monitors.lua"), Object.assign({
                output: spec.output
            }, fields));

        settle.restart();

        if (!HyprConfig.applying)
            root.flushQueued();
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

        command: ["hyprctl", "-j", "monitors", "all"]

        stdout: StdioCollector {
            onStreamFinished: {
                let mons = [];
                try {
                    mons = JSON.parse(text);
                } catch (e) {}
                if (!mons.length)
                    return;
                root.outputs = mons.map(m => ({
                        id: m.id,
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
                        disabled: !!m.disabled,
                        mirror: MonitorRules.mirrorSource(m, mons)
                    }));

                if (!root.outputs.some(m => m.name === root.selected))
                    root.selected = root.outputs.find(m => m.focused)?.name ?? root.outputs[0]?.name ?? "";

                const still = Object.assign({}, root.pending);
                for (const name in still) {
                    const m = root.outputs.find(o => o.name === name);
                    if (m) {
                        const s = still[name];
                        const cur = root.specFor(m);
                        const same = !!s.disabled === !!cur.disabled && (s.mirror ?? "") === (cur.mirror ?? "");
                        if (same && (s.disabled || s.mode === cur.mode && s.position === cur.position && Math.abs(s.scale - cur.scale) < 0.001 && s.transform === cur.transform && s.vrr === cur.vrr))
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

    readonly property var hotplugEvents: ["monitoradded", "monitoraddedv2", "monitorremoved", "monitorremovedv2"]

    Connections {
        target: Hyprland

        function onRawEvent(event): void {
            if (root.hotplugEvents.includes(event.name))
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
