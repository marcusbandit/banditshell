pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string palettePath: `${Quickshell.env("HOME")}/.config/theme/current/palette.json`
    readonly property string cataloguePath: `${Quickshell.env("HOME")}/.config/theme/current/themes.json`

    property var parsed: null
    readonly property bool live: root.parsed !== null

    property int retries: 0
    readonly property int rapidRetries: 5

    readonly property string fallback: "slate"

    readonly property var literals: ({
            slate: slate
        })

    readonly property var all: {
        if (!root.live)
            return root.literals;
        const only = {};
        only[root.rendered.name] = root.rendered;
        return only;
    }

    readonly property var names: Object.keys(root.all)

    function get(name: string): Theme {
        return root.all[name] ?? (root.live ? root.rendered : root.literals[root.fallback]);
    }

    property var indexed: null

    readonly property var catalogue: root.indexed ?? Object.keys(root.literals).map(n => ({
                name: n,
                dim: root.literals[n].dim,
                mid: root.literals[n].mid,
                bright: root.literals[n].bright,
                alarm: root.literals[n].alarm
            }))

    readonly property var availableNames: root.catalogue.map(t => t.name)

    readonly property string activeName: root.live ? root.rendered.name : root.fallback

    function accentsFor(name: string): var {
        if (root.live && name === root.rendered.name)
            return {
                dim: root.rendered.dim,
                mid: root.rendered.mid,
                bright: root.rendered.bright,
                alarm: root.rendered.alarm
            };

        const t = root.catalogue.find(e => e.name === name) ?? root.get(name);
        return {
            dim: t.dim,
            mid: t.mid,
            bright: t.bright,
            alarm: t.alarm
        };
    }

    property bool switching: false

    function apply(name: string): void {
        if (root.switching || name === root.activeName)
            return;

        if (!root.availableNames.includes(name)) {
            console.warn(`Themes: nothing on this machine renders a theme called ${name}.`);
            return;
        }

        root.switching = true;
        switcher.exec(["theme-set", name]);
    }

    function normalise(raw: string): var {
        let p;
        try {
            p = JSON.parse(raw);
        } catch (e) {
            return null;
        }

        if (!p || typeof p !== "object")
            return null;

        const hex = /^#[0-9a-fA-F]{6}$/;
        const colour = v => typeof v === "string" && hex.test(v);

        if (!Array.isArray(p.ramp) || p.ramp.length !== root.slate.ramp.length || !p.ramp.every(colour))
            return null;
        if (!["dim", "mid", "bright", "alarm"].every(k => colour(p[k])))
            return null;

        return {
            name: typeof p.name === "string" && p.name.length > 0 ? p.name : "rendered",
            ramp: p.ramp.slice(),
            dim: p.dim,
            mid: p.mid,
            bright: p.bright,
            alarm: p.alarm
        };
    }

    function adopt(raw: string): void {
        const next = root.normalise(raw);

        if (!next) {
            if (raw.length > 0)
                console.warn(`Themes: ${root.palettePath} is not a palette, wearing the literals instead.`);
            root.parsed = null;
            return;
        }

        if (JSON.stringify(next) !== JSON.stringify(root.parsed))
            root.parsed = next;
    }

    function normaliseCatalogue(raw: string): var {
        let list;
        try {
            list = JSON.parse(raw);
        } catch (e) {
            return null;
        }

        if (!Array.isArray(list))
            return null;

        const hex = /^#[0-9a-fA-F]{6}$/;
        const colour = v => typeof v === "string" && hex.test(v);
        const named = t => t && typeof t === "object" && typeof t.name === "string" && t.name.length > 0;

        const kept = list.filter(t => named(t) && ["dim", "mid", "bright", "alarm"].every(k => colour(t[k]))).map(t => ({
                    name: t.name,
                    dim: t.dim,
                    mid: t.mid,
                    bright: t.bright,
                    alarm: t.alarm
                }));

        return kept.length > 0 ? kept : null;
    }

    function adoptCatalogue(raw: string): void {
        const next = root.normaliseCatalogue(raw);

        if (!next) {
            if (raw.length > 0)
                console.warn(`Themes: ${root.cataloguePath} is not a theme index, the picker is listing the literals instead.`);
            root.indexed = null;
            return;
        }

        if (JSON.stringify(next) !== JSON.stringify(root.indexed))
            root.indexed = next;
    }

    Component.onCompleted: root.adopt(file.text())

    readonly property Theme rendered: Theme {
        readonly property var p: root.parsed

        name: p ? p.name : root.slate.name
        ramp: p ? p.ramp : root.slate.ramp
        dim: p ? p.dim : root.slate.dim
        mid: p ? p.mid : root.slate.mid
        bright: p ? p.bright : root.slate.bright
        alarm: p ? p.alarm : root.slate.alarm
    }

    FileView {
        id: file

        path: root.palettePath
        watchChanges: true
        printErrors: false
        blockLoading: true

        onFileChanged: {
            root.retries = 0;
            file.reload();
        }

        onLoaded: {
            root.retries = 0;
            root.adopt(file.text());

            index.reload();
        }

        onLoadFailed: err => {

            root.retries++;
            settle.restart();

            if (root.retries === root.rapidRetries)
                console.warn(`Themes: cannot read ${root.palettePath}, wearing the literals and watching for it.`);
        }
    }

    Timer {
        id: settle

        interval: root.retries < root.rapidRetries ? 250 : 30000
        onTriggered: file.reload()
    }

    FileView {
        id: index

        path: root.cataloguePath
        preload: true
        watchChanges: true
        printErrors: false

        onFileChanged: index.reload()
        onLoaded: root.adoptCatalogue(index.text())
    }

    Process {
        id: switcher

        onExited: (code, status) => {
            root.switching = false;
            if (code !== 0)
                console.warn(`Themes: theme-set exited ${code}, so the machine kept the theme it had.`);
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const said = text.trim();
                if (said.length > 0)
                    console.warn(`Themes: theme-set said: ${said}`);
            }
        }
    }

    component Theme: QtObject {
        required property string name
        required property var ramp
        required property color dim
        required property color mid
        required property color bright

        required property color alarm
    }

    readonly property Theme slate: Theme {
        name: "slate"
        ramp: ["#08090b", "#0f1114", "#181b1f", "#1d2126", "#262b31", "#3a4149",
            "#545d67", "#78838f", "#a5aeb8", "#d0d7dd", "#eef2f5"]
        dim: "#5b8fb0"
        mid: "#7fb3d4"
        bright: "#b8dcf0"
        alarm: "#ff7a4d"
    }
}
