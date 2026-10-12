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

    readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/banditshell/update.json`
    readonly property real fetchGap: 30 * 60 * 1000

    property real fetchedAt: 0
    property string fetchedRemote: ""
    property string fetchedBranch: ""
    property bool remembered: false
    property bool fetching: false

    function nameable(name: string): bool {
        return !!name && !name.startsWith("-");
    }

    function refuse(): bool {
        if (root.nameable(root.remote) && root.nameable(root.branch))
            return false;
        root.error = "the update remote or branch is not a name git can take";
        return true;
    }

    function check(): void {
        root.inspect(true);
    }

    function inspect(fetch: bool): void {
        if (root.busy || root.checking)
            return;

        root.checkedBranch = root.branch;
        root.error = "";
        if (root.refuse())
            return;
        root.checking = true;
        root.fetching = fetch;
        watchdog.restart();

        checker.command = ["sh", "-c", `
            if [ "$4" = fetch ] && ! out=$(git -C "$1" fetch --quiet -- "$2" "$3" 2>&1); then
                printf 'error=%s\\n' "$(printf '%s' "$out" | tail -1)"
                exit 0
            fi
            printf 'count=%s\\n' "$(git -C "$1" rev-list --count --end-of-options "HEAD..$2/$3")"
            printf 'head=%s\\n' "$(git -C "$1" rev-parse --short --end-of-options "$2/$3")"
        `, "sh", root.dir, root.remote, root.branch, fetch ? "fetch" : "local"];
        checker.running = true;
    }

    function wake(): void {
        const since = Date.now() - root.fetchedAt;
        const same = root.fetchedRemote === root.remote && root.fetchedBranch === root.branch;
        root.inspect(!same || since < 0 || since >= root.fetchGap);
    }

    function remember(): void {
        root.fetchedAt = Date.now();
        root.fetchedRemote = root.remote;
        root.fetchedBranch = root.branch;
        memory.setText(JSON.stringify({
            fetchedAt: root.fetchedAt,
            remote: root.fetchedRemote,
            branch: root.fetchedBranch
        }));
    }

    function download(): void {
        if (root.busy || root.checking || root.state === root.downloaded)
            return;

        root.error = "";
        if (root.refuse())
            return;
        root.state = root.downloading;
        root.checking = true;
        watchdog.restart();

        puller.command = ["sh", "-c", `
            if out=$(git -C "$1" fetch --quiet -- "$2" "$3" 2>&1) && out=$(git -C "$1" merge --ff-only --quiet FETCH_HEAD 2>&1); then
                printf 'head=%s\\n' "$(git -C "$1" rev-parse --short HEAD)"
            else
                printf 'error=%s\\n' "$(printf '%s' "$out" | tail -1)"
            fi
        `, "sh", root.dir, root.remote, root.branch];
        puller.running = true;
    }

    function restart(): void {
        const cli = `${Quickshell.env("HOME")}/bin/banditshell`;
        Quickshell.execDetached(["sh", "-c",
            `if [ -x '${cli}' ]; then exec '${cli}' restart; else exec banditshell restart; fi`]);
    }

    FileView {
        id: memory

        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                root.fetchedAt = Number(data?.fetchedAt) || 0;
                root.fetchedRemote = `${data?.remote ?? ""}`;
                root.fetchedBranch = `${data?.branch ?? ""}`;
            } catch (e) {
                console.warn(`Update: ${root.statePath} is not valid JSON; checking as if never fetched.`);
            }
            root.remembered = true;
        }

        onLoadFailed: root.remembered = true
    }

    Timer {
        interval: 1500
        running: root.remembered
        repeat: false
        onTriggered: root.wake()
    }

    Timer {
        id: cycle

        interval: Math.max(0, Config.values.updates.interval) * 60 * 1000
        repeat: true
        running: interval > 0
        onTriggered: root.check()
    }

    property string checkedBranch: ""
    onBranchChanged: if (root.checkedBranch !== "" && root.branch !== root.checkedBranch)
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
                if (root.fetching)
                    root.remember();
                root.checkedAt = new Date(root.fetchedAt);

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
