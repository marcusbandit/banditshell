pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Facts about this machine and about this checkout of the shell, for the
// settings pages that show them: the whole inventory a phone puts under
// "About phone", from the board the machine is built on down to the disks in
// it.
//
// Nearly everything here is read ONCE. A hostname, a kernel, a processor, a
// firmware date and a git describe do not change while the shell is running,
// so each is a file read or a process spawned at startup and then a value that
// sits still. The one exception is uptime, which is only interesting while
// somebody is looking at it, so it borrows SysInfo's ref-counted `watch`: a
// page asks for it on the way in and lets go on the way out, and the timer
// runs while anybody is asking.
//
// Files through FileView and commands through Process, never a shell script
// that gathers the lot: each answer is one property with one source, so when a
// value is wrong the thing that produced it is the next line down. The three
// commands that return a table (lspci, lsblk, df) are one process each because
// the table IS the one source; splitting them would be three processes reading
// the same output.
//
// Every string is "" until known and a page prints "unknown" for empty rather
// than a blank cell. Numbers are 0 until known and a page hides the row.
Singleton {
    id: root

    // ---- IDENTITY ------------------------------------------------------------

    property string hostname: ""
    property string os: ""
    property string kernel: ""
    property string arch: ""

    // ---- MACHINE, FROM THE DMI TABLES ----------------------------------------

    // Each label is several sysfs files, so the files land in `dmiRaw` below
    // and the label is rebuilt whenever any of them arrives; the order they
    // load in does not matter that way.
    readonly property string vendor: root.dmi(root.dmiRaw.sysVendor)
    readonly property string product: root.joinDmi([root.dmiRaw.productName, root.dmiRaw.productVersion])
    readonly property string board: root.joinDmi([root.dmiRaw.boardVendor, root.dmiRaw.boardName])
    readonly property string bios: root.joinDmi([root.dmiRaw.biosVendor, root.dmiRaw.biosVersion, root.dmiRaw.biosDate])

    // ---- PROCESSOR -------------------------------------------------------------

    property string cpu: ""
    property int cores: 0
    property int threads: 0
    // MHz, 0 when lscpu does not report a ceiling (a VM, some ARM boards).
    property real cpuMaxMhz: 0

    // ---- MEMORY ----------------------------------------------------------------

    property real memoryTotalGb: 0
    property real swapTotalGb: 0

    // ---- GRAPHICS AND STORAGE --------------------------------------------------

    // "<vendor> <device>" per adapter, in bus order.
    property var gpus: []
    // { name, size, model } per whole disk, partitions excluded.
    property var disks: []
    // Human strings straight from df ("704G", "1.9T"), because a page that
    // reformatted them would only be reproducing what df already chose.
    property string rootUsed: ""
    property string rootTotal: ""

    // ---- SOFTWARE ----------------------------------------------------------------

    property string compositorVersion: ""
    property string quickshellVersion: ""

    // Empty until git has answered, which is a few milliseconds after startup.
    property string version: ""
    property string commitDate: ""

    // The checkout that is running, from Quickshell itself rather than from a
    // path written down anywhere, so a moved repo still points at itself.
    readonly property string shellDir: Quickshell.shellDir

    // Firmware writes these in the fields it has no answer for, and each one
    // is a sentence a page would otherwise print as a product name.
    readonly property var dmiBlanks: ["To be filled by O.E.M.", "To Be Filled By O.E.M.", "Default string", "None", "Not Specified", "System Product Name", "System Version"]

    function dmi(raw: string): string {
        const s = raw.trim();
        return root.dmiBlanks.indexOf(s) >= 0 ? "" : s;
    }

    // Several DMI fields into one label, dropping the blanks, so a board with
    // no version is "Z590 GAMING X" and not "Z590 GAMING X Default string".
    function joinDmi(parts: var): string {
        return parts.map(p => root.dmi(p)).filter(p => p).join(" ");
    }

    // ---- UPTIME, SAMPLED ONLY WHILE WATCHED ---------------------------------

    property real uptimeSeconds: 0
    readonly property string uptime: root.formatDuration(root.uptimeSeconds)

    property int watchers: 0
    readonly property bool sampling: watchers > 0

    function watch(on: bool): void {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
        if (on)
            uptimeFile.reload();
    }

    // "3d 4h 12m", with the leading zero units dropped so a machine up for
    // twenty minutes says "20m" and not "0d 0h 20m". Never empty: a fresh boot
    // is "0m", because a row with nothing in it reads as broken rather than as
    // new.
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

    // ---- IDENTITY READERS ------------------------------------------------------

    // /etc/hostname first, the environment as the fallback: the file is what
    // the kernel was told at boot, and HOSTNAME is only set by some shells.
    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: root.hostname = text().trim() || Quickshell.env("HOSTNAME")
    }

    Component.onCompleted: {
        if (!root.hostname)
            root.hostname = Quickshell.env("HOSTNAME");
    }

    // PRETTY_NAME is the one line of os-release meant to be shown to a person;
    // it is usually quoted and occasionally not, so the quotes are stripped
    // rather than assumed.
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

    // ---- MACHINE READERS ---------------------------------------------------------
    //
    // The DMI id directory is world-readable for exactly these fields (the
    // serials beside them are root-only, and are not asked for).

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

    // ---- PROCESSOR READERS -------------------------------------------------------

    // The first "model name" line: every core repeats it, and the vendor pads
    // the string with runs of spaces that would be printed as-is.
    FileView {
        path: "/proc/cpuinfo"
        printErrors: false
        onLoaded: {
            const line = text().split("\n").find(l => l.startsWith("model name"));
            if (line)
                root.cpu = line.slice(line.indexOf(":") + 1).trim().replace(/\s+/g, " ");
        }
    }

    // lscpu rather than counting /proc/cpuinfo, because the physical core
    // count is a topology question (cores per socket times sockets) and lscpu
    // has already worked the topology out. LC_ALL=C because the max MHz is
    // printed with the locale's decimal mark, and "4400,0000" is not a number
    // to JavaScript.
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

    // ---- MEMORY READER -------------------------------------------------------------
    //
    // Read once here, unlike SysInfo's copy of the same file, which is sampled
    // for the numbers that move. The totals do not move, and a page that shows
    // them when SysInfo is not watching would otherwise show zero.

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

    // ---- GRAPHICS READER -----------------------------------------------------------

    // `-mm` puts every field in quotes, so a line is read as its quoted
    // fields in order: class, vendor, device, then the subsystem pair. The
    // three display classes are what a person means by "the GPU"; a laptop
    // with a dGPU has one VGA and one 3D controller and should list both.
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

    // ---- STORAGE READERS -------------------------------------------------------------

    // `-d` lists whole devices only and TYPE still says which of those are
    // disks, since loop devices and zram also count as whole devices. LC_ALL=C
    // so a size reads "1.8T" and not "1,8T".
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

    // Second line only; the first is the header. Fields: filesystem, size,
    // used, available, use%, mount.
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

    // ---- SOFTWARE READERS ----------------------------------------------------------------

    // Only under Hyprland: `running` is the gate, so on niri no process is
    // spawned to fail. `tag` is the release name ("v0.56.1"); `version` is the
    // fallback for a build made off a commit that has no tag.
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

    // "Quickshell 0.3.0 (revision ..., distributed by ...)": the part before
    // the parenthesis is the version, the rest is provenance for a bug report.
    Process {
        running: true
        command: ["qs", "--version"]
        stdout: StdioCollector {
            onStreamFinished: root.quickshellVersion = text.split("\n")[0].split("(")[0].trim()
        }
    }

    // `describe` rather than `rev-parse`: a tag when there is one, the short
    // hash when there is not, and "-dirty" when the working tree does not
    // match, which is the honest thing for a version line to admit.
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
