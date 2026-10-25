pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "tour.js" as Logic

Singleton {
    id: root

    readonly property string path: `${Config.stateDir}/tour.json`

    property bool checked: false
    property var stored: Logic.parseState("")

    readonly property bool ready: Config.loaded && root.checked

    property bool running: false
    property bool parting: false
    property var machine: Logic.begin([])
    property string screen: ""

    property var reports: ({})
    property var layouts: ({})
    property var last: ({})

    readonly property var observed: {
        const out = {};
        for (const name of Object.keys(root.reports))
            for (const id of Object.keys(root.reports[name]))
                out[id] = out[id] || root.reports[name][id];
        return out;
    }

    readonly property var chords: {
        if (!root.running)
            return {};
        const binds = HyprConfig.binds;
        const rows = HyprConfig.actionRows;
        return {
            launcher: Logic.chordFor("launcher", binds, rows),
            island: Logic.chordFor("island", binds, rows),
            hotkeys: Logic.chordFor("hotkeys", binds, rows),
            settings: Logic.chordFor("settings", binds, rows)
        };
    }

    readonly property var steps: Logic.plan({
        bare: Appearance.bare,
        sidebar: Logic.sidebarOf(root.layouts),
        chords: root.chords
    })

    readonly property var facts: ({
            apps: DesktopEntries.applications.values.filter(e => !e.noDisplay).length,
            workspaces: Hypr.known,
            binds: HyprConfig.binds.length
        })

    readonly property var step: Logic.current(root.steps, root.machine.done)
    readonly property string phase: root.machine.phase
    readonly property int number: root.step ? root.steps.indexOf(root.step) + 1 : root.steps.length
    readonly property var words: root.step ? Logic.words(root.step, root.facts) : ({})

    onReadyChanged: root.settle()
    Component.onCompleted: {
        Panels.claim("tour", {
            open: args => root.start(args.screen ?? ""),
            toggle: args => root.running ? root.quit() : root.start(args.screen ?? ""),
            isOpen: () => root.running
        });
        root.settle();
    }

    function settle(): void {
        if (!root.ready || root.running)
            return;
        if (Logic.shouldStart(Config.fresh, root.stored))
            root.begin(root.stored.status === "running" ? root.stored.done : [], "");
    }

    function start(screen: string): void {
        root.begin([], screen);
    }

    function begin(done: var, screen: string): void {
        root.parting = false;
        root.screen = screen || Focus.focusedScreen || Quickshell.screens[0]?.name || "";
        root.last = root.observed;
        root.machine = Logic.begin(done, root.steps);
        root.running = true;
        root.keep("running");
    }

    function pass(): void {
        root.machine = Logic.pass(root.machine, root.steps);
        root.keep("running");
    }

    function finish(): void {
        root.running = false;
        root.keep("done");
    }

    function quit(): void {
        if (!root.running)
            return;
        root.running = false;
        root.parting = true;
        root.keep("skipped");
        farewell.restart();
    }

    function report(screen: string, flags: var, layout: string): void {
        root.layouts = Object.assign({}, root.layouts, {
            [screen]: layout
        });
        root.reports = Object.assign({}, root.reports, {
            [screen]: flags
        });
    }

    function forget(screen: string): void {
        const reports = Object.assign({}, root.reports);
        const layouts = Object.assign({}, root.layouts);
        delete reports[screen];
        delete layouts[screen];
        root.reports = reports;
        root.layouts = layouts;
    }

    onObservedChanged: {
        const before = root.last;
        root.last = root.observed;
        if (!root.running)
            return;
        const next = Logic.observe(root.machine, root.steps, before, root.observed);
        if (JSON.stringify(next) === JSON.stringify(root.machine))
            return;
        root.machine = next;
        root.keep("running");
    }

    function keep(status: string): void {
        root.stored = {
            status: status,
            done: root.machine.done
        };
        store.setText(Logic.formatState(root.stored));
    }

    Connections {
        target: Focus

        function onFocusedScreenChanged(): void {
            if (root.running && Focus.focusedScreen)
                root.screen = Focus.focusedScreen;
        }
    }

    Timer {
        id: farewell

        interval: 6000
        onTriggered: root.parting = false
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            root.stored = Logic.parseState(store.text());
            root.checked = true;
        }
        onLoadFailed: root.checked = true
    }
}
