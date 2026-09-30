pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property string hostname: ""
    property string os: ""
    property string kernel: ""
    property string arch: ""

    readonly property string vendor: root.dmi(root.dmiRaw.sysVendor)
    readonly property string product: root.joinDmi([root.dmiRaw.productName, root.dmiRaw.productVersion])
    readonly property string board: root.joinDmi([root.dmiRaw.boardVendor, root.dmiRaw.boardName])
    readonly property string bios: root.joinDmi([root.dmiRaw.biosVendor, root.dmiRaw.biosVersion, root.dmiRaw.biosDate])

    property string cpu: ""
    property int cores: 0
    property int threads: 0

    property real cpuMaxMhz: 0

    property real memoryTotalGb: 0
    property real swapTotalGb: 0

    property var gpus: []

    property var disks: []

    property string rootUsed: ""
    property string rootTotal: ""

    property string compositorVersion: ""
    property string quickshellVersion: ""

    property string version: ""
    property string commitDate: ""

    readonly property string shellDir: Quickshell.shellDir

    readonly property var dmiBlanks: ["To be filled by O.E.M.", "To Be Filled By O.E.M.", "Default string", "None", "Not Specified", "System Product Name", "System Version"]

    function dmi(raw: string): string {
        const s = raw.trim();
        return root.dmiBlanks.indexOf(s) >= 0 ? "" : s;
    }

    function joinDmi(parts: var): string {
        return parts.map(p => root.dmi(p)).filter(p => p).join(" ");
    }

    property real uptimeSeconds: 0
    readonly property string uptime: root.formatDuration(root.uptimeSeconds)

    property int watchers: 0
    readonly property bool sampling: watchers > 0

    function watch(on: bool): void {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
        if (on)
            uptimeFile.reload();
    }

    function formatDuration(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds / 60));
        const days = Math.floor(total / 1440);
        const hours = Math.floor((total % 1440) / 60);
        const minutes = total % 60;

        const bits = [];
        if (days > 0)
            bits.push(`${days}d`);
        if (days > 0 || hours > 0)
            bits.push(`${hours}h`);
        bits.push(`${minutes}m`);
        return bits.join(" ");
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.sampling
        onTriggered: uptimeFile.reload()
    }

    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: root.uptimeSeconds = Number(text().trim().split(/\s+/)[0]) || 0
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostname = text().trim() || Quickshell.env("HOSTNAME")
    }

    Component.onCompleted: {
        if (!root.hostname)
            root.hostname = Quickshell.env("HOSTNAME");
    }

    FileView {
        path: "/etc/os-release"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("PRETTY_NAME="));
            if (line)
                root.os = line.slice("PRETTY_NAME=".length).trim().replace(/^"|"$/g, "");
        }
    }

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    Process {
        running: true
        command: ["uname", "-m"]
        stdout: StdioCollector {
            onStreamFinished: root.arch = text.trim()
        }
    }

    readonly property QtObject dmiRaw: QtObject {
        property string sysVendor: ""
        property string productName: ""
        property string productVersion: ""
        property string boardVendor: ""
        property string boardName: ""
        property string biosVendor: ""
        property string biosVersion: ""
        property string biosDate: ""
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/sys_vendor"
        printErrors: false
        onLoaded: root.dmiRaw.sysVendor = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/product_name"
        printErrors: false
        onLoaded: root.dmiRaw.productName = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/product_version"
        printErrors: false
        onLoaded: root.dmiRaw.productVersion = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/board_vendor"
        printErrors: false
        onLoaded: root.dmiRaw.boardVendor = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/board_name"
        printErrors: false
        onLoaded: root.dmiRaw.boardName = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/bios_vendor"
        printErrors: false
        onLoaded: root.dmiRaw.biosVendor = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/bios_version"
        printErrors: false
        onLoaded: root.dmiRaw.biosVersion = text()
    }

    FileView {
        path: "/sys/devices/virtual/dmi/id/bios_date"
        printErrors: false
        onLoaded: root.dmiRaw.biosDate = text()
    }

    FileView {
        path: "/proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("model name"));
            if (line)
                root.cpu = line.slice(line.indexOf(":") + 1).trim().replace(/\s+/g, " ");
        }
    }

    Process {
        running: true
        command: ["lscpu"]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = {};
                for (const line of text.split("\n")) {
                    const at = line.indexOf(":");
                    if (at > 0)
                        fields[line.slice(0, at).trim()] = line.slice(at + 1).trim();
                }
                const perSocket = Number(fields["Core(s) per socket"]) || 0;
                const sockets = Number(fields["Socket(s)"]) || 1;
                if (perSocket > 0)
                    root.cores = perSocket * sockets;
                root.threads = Number(fields["CPU(s)"]) || 0;
                root.cpuMaxMhz = parseFloat(fields["CPU max MHz"]) || 0;
            }
        }
    }

    FileView {
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const kb = {};
            for (const line of text().split("\n")) {
                const m = line.match(/^(\w+):\s+(\d+)/);
                if (m)
                    kb[m[1]] = Number(m[2]);
            }
            root.memoryTotalGb = (kb.MemTotal || 0) / 1048576;
            root.swapTotalGb = (kb.SwapTotal || 0) / 1048576;
        }
    }

    Process {
        running: true
        command: ["lspci", "-mm"]
        stdout: StdioCollector {
            onStreamFinished: {
                const classes = ["VGA compatible controller", "3D controller", "Display controller"];
                const found = [];
                for (const line of text.split("\n")) {
                    const q = [...line.matchAll(/"([^"]*)"/g)].map(m => m[1]);
                    if (q.length >= 3 && classes.indexOf(q[0]) >= 0)
                        found.push(`${q[1]} ${q[2]}`.trim());
                }
                root.gpus = found;
            }
        }
    }

    Process {
        running: true
        command: ["lsblk", "-J", "-d", "-o", "NAME,SIZE,MODEL,TYPE"]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const all = JSON.parse(text).blockdevices ?? [];
                    root.disks = all.filter(d => d.type === "disk").map(d => ({
                                name: d.name ?? "",
                                size: (d.size ?? "").trim(),
                                model: (d.model ?? "").trim()
                            }));
                } catch (e) {
                    root.disks = [];
                }
            }
        }
    }

    Process {
        running: true
        command: ["df", "-h", "/"]
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                const line = text.split("\n")[1];
                if (!line)
                    return;
                const f = line.trim().split(/\s+/);
                if (f.length >= 3) {
                    root.rootTotal = f[1];
                    root.rootUsed = f[2];
                }
            }
        }
    }

    Process {
        running: Compositor.isHyprland
        command: ["hyprctl", "version", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const v = JSON.parse(text);
                    root.compositorVersion = (v.tag || v.version || "").trim();
                } catch (e) {
                }
            }
        }
    }

    Process {
        running: true
        command: ["qs", "--version"]
        stdout: StdioCollector {
            onStreamFinished: root.quickshellVersion = text.split("\n")[0].split("(")[0].trim()
        }
    }

    Process {
        running: true
        command: ["git", "-C", root.shellDir, "describe", "--tags", "--always", "--dirty"]
        stdout: StdioCollector {
            onStreamFinished: root.version = text.trim()
        }
    }

    Process {
        running: true
        command: ["git", "-C", root.shellDir, "log", "-1", "--format=%cs"]
        stdout: StdioCollector {
            onStreamFinished: root.commitDate = text.trim()
        }
    }
}
