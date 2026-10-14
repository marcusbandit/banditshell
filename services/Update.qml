pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "update.js" as Words

Singleton {
    id: root

    readonly property string idle: "idle"
    readonly property string available: "available"
    readonly property string downloading: "downloading"
    readonly property string downloaded: "downloaded"
    readonly property string failed: "failed"

    property string state: root.idle

    property int behind: 0
    property int ahead: 0

    property string target: ""
    readonly property string remoteHead: root.target.slice(0, 7)

    property string headBranch: ""
    readonly property bool paused: root.headBranch !== "" && root.headBranch !== root.branch
    readonly property bool diverged: root.behind > 0 && root.ahead > 0

    property string error: ""

    property date checkedAt: new Date(0)

    readonly property bool busy: root.state === root.downloading

    property bool checking: false

    readonly property string branch: Config.values.updates.branch
    readonly property string remote: Config.values.updates.remote

    readonly property string dir: Quickshell.shellDir

    readonly property string statePath: `${Config.stateDir}/update.json`
    readonly property real fetchGap: 30 * 60 * 1000

    property real fetchedAt: 0
    property string fetchedRemote: ""
    property string fetchedBranch: ""
    property bool remembered: false
    property bool fetching: false

    readonly property string headline: {
        if (root.state === root.downloaded)
            return "Downloaded - restart to apply";
        if (root.state === root.downloading)
            return "Updating...";
        if (root.state === root.failed)
            return "Update failed - nothing was changed";
        if (root.paused)
            return `This copy is on ${root.headBranch === "HEAD" ? "no branch" : root.headBranch}, so it does not follow ${root.branch}`;
        if (root.diverged)
            return `${root.behind} new on ${root.branch}, but this copy has ${root.ahead} of its own`;
        if (root.behind > 0)
            return `${root.behind} new commit${root.behind === 1 ? "" : "s"} on ${root.branch}`;
        return "You are up to date";
    }

    function nameable(name: string): bool {
        return !!name && !name.startsWith("-");
    }

    function refuse(): bool {
        if (root.nameable(root.remote) && root.nameable(root.branch))
            return false;
        root.error = "the update remote or branch is not a name git can take";
        return true;
    }

    function commit(sha: string): bool {
        return /^[0-9a-f]{40,64}$/.test(sha);
    }

    function ago(when: date): string {
        return Words.ago(when.getTime(), Date.now());
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
            export GIT_TERMINAL_PROMPT=0 LC_ALL=C
            top=$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)
            if [ -z "$top" ] || [ "$top" != "$(cd "$1" && pwd -P)" ]; then
                printf 'failed\\n|fatal: not a git repository\\n'
                exit 0
            fi
            if [ "$4" = fetch ]; then
                out=$(timeout -k 10 120 git -C "$1" fetch --quiet -- "$2" "$3" 2>&1)
                case $? in
                    0) ;;
                    124|137) printf 'failed\\n|timed out\\n'; exit 0 ;;
                    *) echo failed; printf '%s\\n' "$out" | sed 's/^/|/'; exit 0 ;;
                esac
            fi
            printf 'branch=%s\\n' "$(git -C "$1" symbolic-ref --quiet --short HEAD 2>/dev/null || echo HEAD)"
            printf 'head=%s\\n' "$(git -C "$1" rev-parse --verify --quiet HEAD 2>/dev/null)"
            printf 'target=%s\\n' "$(git -C "$1" rev-parse --verify --quiet --end-of-options "$2/$3^{commit}" 2>/dev/null)"
            printf 'count=%s\\n' "$(git -C "$1" rev-list --count --end-of-options "HEAD..$2/$3" 2>/dev/null)"
            printf 'ahead=%s\\n' "$(git -C "$1" rev-list --count --end-of-options "$2/$3..HEAD" 2>/dev/null)"
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
        if (root.busy || root.checking || root.paused || root.diverged || root.state === root.downloaded)
            return;

        root.error = "";
        if (!root.commit(root.target)) {
            root.error = "Nothing has been checked yet. Refresh first.";
            return;
        }
        root.state = root.downloading;
        root.checking = true;
        kept.installedTo = root.target;
        watchdog.restart();

        puller.command = ["sh", "-c", `
            export GIT_TERMINAL_PROMPT=0 LC_ALL=C
            if out=$(git -C "$1" merge --ff-only --quiet "$2" 2>&1); then
                printf 'head=%s\\n' "$(git -C "$1" rev-parse HEAD)"
            else
                echo failed
                printf '%s\\n' "$out" | sed 's/^/|/'
            fi
        `, "sh", root.dir, root.target];
        puller.running = true;
    }

    function restart(): void {
        const cli = `${Quickshell.env("HOME")}/bin/banditshell`;
        Quickshell.execDetached(["sh", "-c",
            `if [ -x '${cli}' ]; then exec '${cli}' restart; else exec banditshell restart; fi`]);
    }

    PersistentProperties {
        id: kept

        reloadableId: "update"

        property string installedTo: ""
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

        interval: 180000

        onTriggered: {
            if (!root.checking)
                return;
            root.checking = false;
            checker.running = false;
            puller.running = false;
            if (root.state === root.downloading) {
                root.state = root.failed;
                root.error = "git stopped answering and was stopped. Refresh to see where this copy stands.";
            } else {
                root.error = "The check stopped answering and was given up.";
            }
        }
    }

    Process {
        id: checker

        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.checking)
                    return;
                root.checking = false;
                watchdog.stop();

                const got = Words.report(text);
                if (!got.failed && root.fetching)
                    root.remember();
                root.checkedAt = new Date(root.fetchedAt);

                if (got.failed) {
                    root.error = Words.explain(got.output, root.branch);
                    console.warn(`Update: ${got.output.join(" / ")}`);
                    return;
                }

                root.headBranch = got.values.branch ?? "";
                root.target = root.commit(got.values.target ?? "") ? got.values.target : "";
                root.behind = root.paused ? 0 : Number(got.values.count) || 0;
                root.ahead = root.paused ? 0 : Number(got.values.ahead) || 0;

                if (kept.installedTo !== "" && got.values.head === kept.installedTo)
                    root.state = root.downloaded;

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
                if (!root.checking)
                    return;
                root.checking = false;
                watchdog.stop();

                const got = Words.report(text);
                if (got.failed) {
                    kept.installedTo = "";
                    root.error = Words.explain(got.output, root.branch);
                    root.state = root.failed;
                    console.warn(`Update: ${got.output.join(" / ")}`);
                    return;
                }

                root.behind = 0;
                root.ahead = 0;
                root.state = root.downloaded;
            }
        }
    }
}
