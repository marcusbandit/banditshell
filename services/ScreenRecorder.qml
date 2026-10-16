pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "recording.js" as Logic
import "obs.js" as Durations

Singleton {
    id: root

    readonly property var settings: Config.values.launcher.systemControls ?? {}
    readonly property bool enabled: root.settings.recording !== false

    readonly property string backend: Logic.pickBackend(Object.keys(ToolInstaller.found))
    readonly property bool ready: !!root.backend
    readonly property bool canPick: ToolInstaller.has("slurp")

    readonly property string script: `${Quickshell.shellDir}/scripts/screen-record.sh`
    readonly property string stateDir: Quickshell.env("XDG_RUNTIME_DIR") ? `${Quickshell.env("XDG_RUNTIME_DIR")}/banditshell` : `${Config.cacheDir}/run`

    property string videosDir: ""
    readonly property string folder: Logic.folderFor(root.settings.recordingFolder, root.videosDir, Files.home)

    property var current: null
    property string starting: ""
    property bool sound: false
    property string screenName: ""
    property string windowAddress: ""
    property string expected: ""
    property double expectedSince: 0
    property bool stopping: false
    property int droppedPid: 0
    property int deadTicks: 0
    property string lastFile: ""
    property string trouble: ""
    property double now: Date.now()

    readonly property bool recording: root.current !== null
    readonly property bool busy: root.recording || !!root.starting || !!root.expected
    readonly property string clock: root.recording ? Durations.duration(root.now - root.current.started) : ""
    readonly property string modeText: root.recording ? Logic.modeLabel(root.current.mode) : ""

    function start(mode: string, withSound: bool, screenName: string, windowAddress: string): void {
        if (root.busy || !root.ready)
            return;
        root.trouble = "";
        root.starting = mode;
        root.sound = withSound;
        root.screenName = screenName || Hypr.focusedScreen || "";
        root.windowAddress = windowAddress;
        if (mode === "area") {
            if (!root.canPick)
                return root.giveUp("slurp is needed to pick an area");
            areaPicker.running = true;
        } else if (mode === "window") {
            windowLister.running = true;
        } else {
            settleLauncher.restart();
        }
    }

    function giveUp(why: string): void {
        root.starting = "";
        root.trouble = why;
    }

    function launch(target: var): void {
        const mode = root.starting;
        root.starting = "";
        const file = `${root.folder}/${Logic.fileName(new Date())}`;
        const command = Logic.recorderCommand(root.backend, file, target, root.sound);
        if (!command.length)
            return root.giveUp("nothing to record");
        root.expected = file;
        root.expectedSince = Date.now();
        Quickshell.execDetached([root.script, "start", root.stateDir, file, mode, root.sound ? "sound" : "quiet", ...command]);
        stateFile.reload();
    }

    function stop(): void {
        if (!root.recording || root.stopping)
            return;
        root.stopping = true;
        stopWatch.restart();
        Quickshell.execDetached([root.script, "stop", root.stateDir]);
    }

    function drop(): void {
        if (root.current)
            root.droppedPid = root.current.pid;
        root.deadTicks = 0;
        Quickshell.execDetached([root.script, "tidy", root.stateDir]);
        root.lose();
    }

    function checkAlive(comm: string): void {
        if (!root.current)
            return;
        if (Logic.isRecorderName(comm))
            root.deadTicks = 0;
        else
            root.drop();
    }

    function missing(): void {
        if (!root.current)
            return;
        root.deadTicks += 1;
        if (root.deadTicks >= 3)
            root.drop();
    }

    function adopt(text: string): void {
        const state = Logic.parseState(text);
        if (!state) {
            root.lose();
            return;
        }
        if (root.current?.pid === state.pid || state.pid === root.droppedPid)
            return;
        if (root.expected && state.file === root.expected)
            root.expected = "";
        root.current = state;
        root.deadTicks = 0;
        alive.path = `/proc/${state.pid}/comm`;
        alive.reload();
    }

    function lose(): void {
        if (root.current) {
            root.lastFile = root.current.file;
            root.current = null;
            root.stopping = false;
            stopWatch.stop();
            result.reload();
        } else if (root.expected && Date.now() - root.expectedSince > 8000) {
            root.expected = "";
            root.trouble = "the recorder did not start";
        } else if (root.expected && Date.now() - root.expectedSince > 1500) {
            result.reload();
        }
    }

    function settle(text: string): void {
        const done = Logic.parseResult(text);
        if (root.expected && done.file === root.expected) {
            root.expected = "";
            root.trouble = done.complaint || "the recorder stopped at once";
            root.notify("Recording failed", root.trouble, "dialog-error");
            return;
        }
        if (done.file !== root.lastFile)
            return;
        if (done.size > 0) {
            root.trouble = "";
            root.notify("Recording saved", root.lastFile.split("/").pop(), "media-record");
        } else {
            root.lastFile = "";
            root.trouble = done.complaint || "nothing was saved";
            root.notify("Recording failed", root.trouble, "dialog-error");
        }
    }

    function notify(summary: string, body: string, icon: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", icon, summary, body]);
    }

    Component.onCompleted: {
        stateFile.reload();
        videos.running = true;
    }

    Timer {
        interval: root.recording ? 1000 : 250
        repeat: true
        running: root.recording || !!root.expected
        onTriggered: {
            root.now = Date.now();
            stateFile.reload();
            if (root.current)
                alive.reload();
        }
    }

    Timer {
        id: stopWatch

        interval: 20000
        onTriggered: {
            if (!root.recording)
                return;
            root.stopping = false;
            root.trouble = "the recorder would not stop";
        }
    }

    Timer {
        id: settleLauncher

        interval: 350
        onTriggered: root.launch({
            output: root.screenName
        })
    }

    FileView {
        id: stateFile

        path: `${root.stateDir}/recording`
        printErrors: false

        onLoaded: root.adopt(stateFile.text())
        onLoadFailed: root.lose()
    }

    FileView {
        id: result

        path: `${root.stateDir}/result`
        printErrors: false

        onLoaded: root.settle(result.text())
    }

    FileView {
        id: alive

        printErrors: false

        onLoaded: root.checkAlive(alive.text().trim())
        onLoadFailed: root.missing()
    }

    Process {
        id: videos

        command: ["sh", "-c", "xdg-user-dir VIDEOS 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: {
                const dir = text.trim();
                root.videosDir = dir && dir !== Files.home ? dir : "";
            }
        }
    }

    Process {
        id: areaPicker

        command: ["slurp"]

        stdout: StdioCollector {
            id: areaPicked
        }

        onExited: code => {
            const geometry = code === 0 ? areaPicked.text.trim() : "";
            if (!Logic.geometryParts(geometry))
                return root.giveUp("");
            root.launch({
                geometry: geometry
            });
        }
    }

    Process {
        id: windowLister

        command: ["sh", "-c", "hyprctl -j clients && printf '\\036' && hyprctl -j monitors"]

        stdout: StdioCollector {
            id: windowList
        }

        onExited: code => {
            const parts = code === 0 ? Logic.splitDocuments(windowList.text) : [];
            const clients = parts[0] ?? [];
            if (!root.canPick) {
                const box = Logic.windowBox(clients, root.windowAddress);
                return box ? root.launch({
                    geometry: box
                }) : root.giveUp("no window to record");
            }
            const boxes = Logic.windowBoxes(clients, parts[1] ?? []);
            if (!boxes.length)
                return root.giveUp("no window to record");
            windowPicker.boxes = boxes;
            windowPicker.running = true;
        }
    }

    Process {
        id: windowPicker

        property var boxes: []

        command: ["slurp", "-r"]
        stdinEnabled: true

        onStarted: {
            windowPicker.write(windowPicker.boxes.join("\n") + "\n");
            windowPicker.stdinEnabled = false;
        }

        stdout: StdioCollector {
            id: windowPicked
        }

        onExited: code => {
            windowPicker.stdinEnabled = true;
            const geometry = code === 0 ? windowPicked.text.trim() : "";
            if (!Logic.geometryParts(geometry))
                return root.giveUp("");
            root.launch({
                geometry: geometry
            });
        }
    }
}
