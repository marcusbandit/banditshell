pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "system-monitor.js" as Monitor

Singleton {
    id: root

    property int watchers: 0
    readonly property bool sampling: root.watchers > 0

    property var previous: null
    property var top: []
    property var disks: []
    property real uptime: 0
    property int cores: 0
    property int beats: 0

    readonly property int intervalMs: 2000

    function watch(on: bool): void {
        const before = root.sampling;
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
        if (root.sampling === before)
            return;
        SystemInfo.watch(root.sampling);
        if (root.sampling) {
            root.beats = 0;
            root.sample();
        } else {
            root.previous = null;
        }
    }

    function sample(): void {
        if (!sampler.running)
            sampler.running = true;
        if (root.beats % 5 === 0 && !diskReader.running)
            diskReader.running = true;
        root.beats += 1;
    }

    Timer {
        interval: root.previous ? root.intervalMs : 500
        repeat: true
        running: root.sampling
        onTriggered: root.sample()
    }

    Process {
        id: sampler

        command: ["sh", "-c", Monitor.SAMPLE]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Monitor.readSample(text);
                if (!now)
                    return;
                root.uptime = now.uptime;
                if (root.previous)
                    root.top = Monitor.topProcesses(root.previous, now, 5);
                root.previous = root.sampling ? now : null;
            }
        }
    }

    Process {
        id: diskReader

        command: ["df", "-kPT"]
        stdout: StdioCollector {
            onStreamFinished: root.disks = Monitor.readDisks(text)
        }
    }

    Process {
        running: true
        command: ["sh", "-c", "getconf _NPROCESSORS_ONLN 2>/dev/null || nproc"]
        stdout: StdioCollector {
            onStreamFinished: root.cores = Number(text.trim()) || 0
        }
    }

    function quit(pid: int, force: bool): void {
        Quickshell.execDetached(["kill", force ? "-KILL" : "-TERM", String(pid)]);
        resample.restart();
    }

    function quitAsAdministrator(pid: int, name: string): void {
        if (elevated.running)
            return;
        Polkit.expect(`Quit ${name}`, "kill");
        elevated.command = ["pkexec", "/bin/kill", "-TERM", String(pid)];
        elevated.running = true;
    }

    Process {
        id: elevated

        onExited: {
            Polkit.forget();
            resample.restart();
        }
    }

    Timer {
        id: resample

        interval: 400
        onTriggered: if (root.sampling)
            root.sample()
    }
}
