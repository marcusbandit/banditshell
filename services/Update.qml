pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string idle: "idle"
    readonly property string available: "available"
    readonly property string downloading: "downloading"
    readonly property string downloaded: "downloaded"
    readonly property string failed: "failed"

    property string state: root.idle

    property int behind: 0
    property string remoteHead: ""

    property string error: ""

    property date checkedAt: new Date(0)

    readonly property bool busy: root.state === root.downloading

    property bool checking: false

    readonly property string branch: Config.values.updates.branch
    readonly property string remote: Config.values.updates.remote

    readonly property string dir: Quickshell.shellDir

    function check(): void {

        if (root.busy || root.checking)
            return;

        root.checkedBranch = root.branch;
        root.error = "";
        root.checking = true;
        watchdog.restart();

        const q = s => `'${s.replace(/'/g, `'\\''`)}'`;

        checker.command = ["sh", "-c", `if out=$(git -C ${q(root.dir)} fetch --quiet ${q(root.remote)} ${q(root.branch)} 2>&1); then printf 'count=%s\\n' "$(git -C ${q(root.dir)} rev-list --count HEAD..${q(root.remote)}/${q(root.branch)})"; printf 'head=%s\\n' "$(git -C ${q(root.dir)} rev-parse --short ${q(root.remote)}/${q(root.branch)})"; else printf 'error=%s\\n' "$(printf '%s' "$out" | tail -1)"; fi`];
        checker.running = true;
    }

    function download(): void {
        if (root.busy || root.checking || root.state === root.downloaded)
            return;

        root.error = "";
        root.state = root.downloading;
        root.checking = true;
        watchdog.restart();

        const q = s => `'${s.replace(/'/g, `'\\''`)}'`;
        puller.command = ["sh", "-c", `if out=$(git -C ${q(root.dir)} pull --ff-only ${q(root.remote)} ${q(root.branch)} 2>&1); then printf 'head=%s\\n' "$(git -C ${q(root.dir)} rev-parse --short HEAD)"; else printf 'error=%s\\n' "$(printf '%s' "$out" | tail -1)"; fi`];
        puller.running = true;
    }

    function restart(): void {
        const cli = `${Quickshell.env("HOME")}/bin/banditshell`;
        Quickshell.execDetached(["sh", "-c",
            `if [ -x '${cli}' ]; then exec '${cli}' restart; else exec banditshell restart; fi`]);
    }

    Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: root.check()
    }

    Timer {
        id: cycle

        interval: Math.max(0, Config.values.updates.interval) * 60 * 1000
        repeat: true
        running: interval > 0
        onTriggered: root.check()
    }

    property string checkedBranch: ""
    onBranchChanged: if (root.branch !== root.checkedBranch)
        root.check()

    Timer {
        id: watchdog

        interval: 300000

        onTriggered: {
            if (!root.checking)
                return;
            root.checking = false;
            if (root.state === root.downloading) {
                root.state = root.failed;
                root.error = "git gave up halfway";
            }
        }
    }

    Process {
        id: checker

        stdout: StdioCollector {

            onStreamFinished: {
                root.checkedAt = new Date();

                let failure = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("count="))
                        root.behind = Number(line.slice(6)) || 0;
                    else if (line.startsWith("head="))
                        root.remoteHead = line.slice(5).trim();
                    else if (line.startsWith("error="))
                        failure = line.slice(6).trim();
                }

                root.error = failure;

                root.checking = false;
                watchdog.stop();

                if (root.behind > 0)
                    root.state = root.available;
                else if (root.state === root.available || root.state === root.failed)
                    root.state = root.idle;
            }
        }
    }

    Process {
        id: puller

        stdout: StdioCollector {
            onStreamFinished: {
                let failure = "";
                for (const line of text.split("\n")) {
                    if (line.startsWith("head="))
                        root.remoteHead = line.slice(5).trim();
                    else if (line.startsWith("error="))
                        failure = line.slice(6).trim();
                }

                root.checking = false;
                watchdog.stop();

                if (failure !== "") {
                    root.error = failure;

                    root.state = root.failed;
                } else {
                    root.behind = 0;
                    root.state = root.downloaded;
                }
            }
        }
    }
}
