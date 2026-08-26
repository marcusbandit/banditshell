pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Facts about this machine and about this checkout of the shell, for the
// settings pages that show them.
//
// Nearly everything here is read ONCE. A hostname, a kernel, a processor and
// a git describe do not change while the shell is running, so each is a file
// read or a process spawned at startup and then a string that sits still. The
// one exception is uptime, which is only interesting while somebody is looking
// at it, so it borrows SysInfo's ref-counted `watch`: a page asks for it on
// the way in and lets go on the way out, and the timer runs while anybody is
// asking.
//
// Files through FileView and commands through Process, never a shell script
// that gathers the lot: each answer is one property with one source, so when a
// value is wrong the thing that produced it is the next line down.
Singleton {
    id: root

    property string hostname: ""
    property string os: ""
    property string kernel: ""
    property string cpu: ""

    // Empty until git has answered, which is a few milliseconds after startup;
    // a page prints "unknown" for empty rather than a blank cell.
    property string version: ""
    property string commitDate: ""

    // The checkout that is running, from Quickshell itself rather than from a
    // path written down anywhere, so a moved repo still points at itself.
    readonly property string shellDir: Quickshell.shellDir

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

    // ---- THE MACHINE ---------------------------------------------------------

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

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    // ---- THE SHELL -----------------------------------------------------------

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
