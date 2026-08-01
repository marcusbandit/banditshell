pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU, memory and temperature, read straight from the kernel.
//
// /proc and /sys rather than a helper process, because these are three files and
// spawning `top` once a second to parse its output would cost more than the
// numbers are worth.
//
// CPU load is not a number the kernel reports: /proc/stat counts JIFFIES since
// boot, so a percentage only exists between two readings. The first sample after
// startup therefore has nothing to compare against and is deliberately dropped,
// rather than being shown as a meaningless "100% since boot".
Singleton {
    id: root

    // 0..1
    property real cpu: 0
    property real memory: 0
    property real swap: 0
    // Celsius, 0 when nothing sensible is exposed.
    property real temperature: 0

    property real memoryUsedGb: 0
    property real memoryTotalGb: 0

    // Sampling stops when nothing is looking. Menus ask for it while open.
    property int watchers: 0
    readonly property bool sampling: watchers > 0

    function watch(on: bool): void {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
        if (on)
            root.poll();
    }

    function poll(): void {
        stat.reload();
        meminfo.reload();
        thermal.reload();
    }

    property var lastStat: null

    Timer {
        interval: 1500
        repeat: true
        running: root.sampling
        onTriggered: root.poll()
    }

    FileView {
        id: stat

        path: "/proc/stat"
        printErrors: false

        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("cpu "));
            if (!line)
                return;
            const f = line.trim().split(/\s+/).slice(1).map(Number);
            // user nice system idle iowait irq softirq steal
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);

            const prev = root.lastStat;
            root.lastStat = {
                idle: idle,
                total: total
            };
            if (!prev)
                return;

            const dTotal = total - prev.total;
            const dIdle = idle - prev.idle;
            if (dTotal > 0)
                root.cpu = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
        }
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        printErrors: false

        onLoaded: {
            const kb = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    kb[m[1]] = Number(m[2]);
            }
            // MemAvailable, not MemFree: free memory excludes cache, which the
            // kernel will hand back on demand, so MemFree reads as "almost none"
            // on a perfectly healthy machine.
            if (kb.MemTotal > 0) {
                root.memory = 1 - kb.MemAvailable / kb.MemTotal;
                root.memoryTotalGb = kb.MemTotal / 1048576;
                root.memoryUsedGb = (kb.MemTotal - kb.MemAvailable) / 1048576;
            }
            if (kb.SwapTotal > 0)
                root.swap = 1 - kb.SwapFree / kb.SwapTotal;
        }
    }

    // Which thermal zone is the CPU is machine-specific, so this is resolved once
    // by name rather than guessed at zone0.
    property string thermalPath: ""

    Process {
        id: findThermal

        running: true
        command: ["sh", "-c", "for z in /sys/class/thermal/thermal_zone*; do t=$(cat $z/type 2>/dev/null); case $t in x86_pkg_temp|k10temp|cpu*|acpitz) echo $z/temp; exit;; esac; done; ls /sys/class/thermal/thermal_zone0/temp 2>/dev/null"]

        stdout: StdioCollector {
            onStreamFinished: root.thermalPath = text.trim()
        }
    }

    FileView {
        id: thermal

        path: root.thermalPath
        printErrors: false

        onLoaded: {
            const milli = Number(text().trim());
            if (milli > 0)
                root.temperature = milli / 1000;
        }
    }
}
