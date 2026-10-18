import QtQuick
import Quickshell
import qs.config
import qs.services
import "../system-asks.js" as Asks

QtObject {
    id: root

    required property var search

    readonly property var asked: ScreenRecorder.enabled ? Asks.recordAsk(root.search.text) : null
    readonly property bool near: ScreenRecorder.enabled && !root.asked && Asks.recordNear(root.search.text)
    readonly property bool wanted: root.asked !== null || root.near

    readonly property bool intent: root.asked !== null

    onWantedChanged: if (root.wanted)
        ToolInstaller.probe()

    readonly property var kinds: ["record", "recordstop", "recordinstall", "recordlast"]

    readonly property var phrases: [
        {
            head: "record ",
            picks: ["screen", "area", "window", "screen with sound"]
        }
    ]

    readonly property var caps: ({
            recording: 6
        })

    readonly property var modes: [
        {
            mode: "screen",
            label: "Record the screen",
            icon: "screenshot_monitor"
        },
        {
            mode: "area",
            label: "Record an area",
            icon: "screenshot_region"
        },
        {
            mode: "window",
            label: "Record a window",
            icon: "select_window"
        }
    ]

    function stopRow(): var {
        return {
            key: "record:stop",
            kind: "recordstop",
            label: ScreenRecorder.stopping ? "Saving the recording" : "Stop recording",
            detail: [ScreenRecorder.clock, ScreenRecorder.modeText, ScreenRecorder.current?.sound ? "with sound" : "", ScreenRecorder.stopping ? "" : ScreenRecorder.trouble].filter(Boolean).join(" · "),
            icon: "stop_circle",
            score: Infinity
        };
    }

    function liveStopRow(): var {
        const meant = root.wanted || Asks.stopNear(root.search.text);
        const arming = root.search.armed === "recordstop";
        const row = root.stopRow();
        return Object.assign(row, {
            careful: !meant,
            armed: arming,
            label: arming ? "Press Enter again to stop recording" : row.label,
            detail: arming ? "" : row.detail,
            score: meant ? Infinity : 0.45
        });
    }

    function modeRow(choice: var, sound: bool, score: real): var {
        const picking = choice.mode === "area" && !ScreenRecorder.canPick;
        return {
            key: `record:${choice.mode}${sound ? ":sound" : ""}`,
            kind: picking ? "recordinstall" : "record",
            tool: picking ? "slurp" : "",
            mode: choice.mode,
            sound: sound,
            label: picking ? ToolInstaller.installLabel("slurp") : sound ? `${choice.label} with sound` : choice.label,
            detail: [choice.mode === "screen" ? root.search.screenName : "", ScreenRecorder.starting === choice.mode ? "starting" : "", ScreenRecorder.trouble].filter(Boolean).join(" · "),
            icon: picking ? "download" : choice.icon,
            score: score
        };
    }

    function installRow(): var {
        return {
            key: "record:install",
            kind: "recordinstall",
            tool: "wf-recorder",
            label: ToolInstaller.installLabel("wf-recorder"),
            detail: "",
            icon: "download",
            score: Infinity
        };
    }

    function lastRow(score: real): var {
        const file = ScreenRecorder.lastFile;
        const cut = file.lastIndexOf("/");
        return {
            key: "record:last",
            kind: "recordlast",
            path: file,
            label: file.slice(cut + 1),
            detail: file.slice(0, cut).replace(System.home, "~"),
            icon: "movie",
            score: score
        };
    }

    function rowById(id: string): var {
        if (!ScreenRecorder.enabled)
            return null;
        if (id === "record:stop")
            return ScreenRecorder.recording ? root.stopRow() : null;
        const parts = id.split(":");
        const choice = parts[0] === "record" ? root.modes.find(m => m.mode === parts[1]) : null;
        return choice && ScreenRecorder.ready ? root.modeRow(choice, parts[2] === "sound", 1) : null;
    }

    readonly property var rows: {
        if (!ScreenRecorder.enabled)
            return [];
        if (ScreenRecorder.recording)
            return root.search.text ? [root.liveStopRow()] : [];
        const ask = root.asked;
        if (!root.wanted || ask?.stop)
            return [];
        const score = root.near ? 0.4 : Infinity;
        if (!ToolInstaller.probed)
            return [];
        if (!ScreenRecorder.ready)
            return root.near ? [] : [root.installRow()];
        const sound = !!ask?.sound;
        const first = root.modes.find(m => m.mode === ask?.mode);
        const ordered = first ? [first].concat(root.modes.filter(m => m !== first)) : root.modes;
        const out = ordered.map(choice => root.modeRow(choice, sound, score));
        if (ScreenRecorder.lastFile && !root.near)
            out.push(root.lastRow(score));
        return out;
    }

    readonly property var groups: [
        {
            key: "recording",
            title: "Screen recording",
            items: root.rows
        }
    ]

    function activate(row: var): void {
        switch (row.kind) {
        case "recordstop":
            if (row.careful && root.search.armed !== "recordstop") {
                root.search.armed = "recordstop";
                return;
            }
            root.search.armed = "";
            root.search.leave(() => ScreenRecorder.stop());
            return;
        case "recordinstall":
            ToolInstaller.install(row.tool);
            return;
        case "record":
            {
                const mode = row.mode;
                const sound = row.sound;
                const screen = root.search.screenName;
                const window = root.search.windowTarget();
                root.search.leave(() => ScreenRecorder.start(mode, sound, screen, window));
                return;
            }
        case "recordlast":
            {
                const path = row.path;
                root.search.launch(() => Quickshell.execDetached(["xdg-open", path]));
                return;
            }
        }
    }

    function actionsFor(row: var): var {
        switch (row.kind) {
        case "recordstop":
            return [
                {
                    icon: "stop_circle",
                    label: "Stop",
                    run: () => root.activate(row)
                }
            ];
        case "recordinstall":
            return [
                {
                    icon: "download",
                    label: "Install",
                    run: () => root.activate(row)
                }
            ];
        case "record":
            {
                const other = Object.assign({}, row, {
                    sound: !row.sound
                });
                return [
                    {
                        icon: "fiber_manual_record",
                        label: "Record",
                        run: () => root.activate(row)
                    },
                    {
                        icon: row.sound ? "volume_off" : "volume_up",
                        label: row.sound ? "Record without sound" : "Record with sound",
                        short: row.sound ? "No sound" : "With sound",
                        run: () => root.activate(other)
                    },
                    {
                        icon: "folder_open",
                        label: "Open recordings folder",
                        short: "Folder",
                        tucked: true,
                        run: () => {
                            const folder = ScreenRecorder.folder;
                            root.search.launch(() => Quickshell.execDetached(["xdg-open", folder]));
                        }
                    }
                ];
            }
        case "recordlast":
            {
                const path = row.path;
                return [
                    {
                        icon: "play_circle",
                        label: "Play",
                        run: () => root.activate(row)
                    },
                    {
                        icon: "folder_open",
                        label: "Show in folder",
                        short: "Folder",
                        run: () => root.search.leave(() => System.reveal(path))
                    }
                ];
            }
        }
        return [];
    }
}
