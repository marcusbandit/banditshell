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
    readonly property string verifying: "verifying"
    readonly property string restarting: "restarting"
    readonly property string updated: "updated"
    readonly property string rolledback: "rolledback"
    readonly property string failed: "failed"

    property string state: root.idle

    property int behind: 0
    property int ahead: 0

    property string target: ""
    readonly property string remoteHead: root.target.slice(0, 7)

    property string headBranch: ""
    readonly property bool paused: root.headBranch !== "" && !Words.following(root.headBranch, root.branch)
    readonly property bool diverged: root.behind > 0 && root.ahead > 0

    property string error: ""
    property string phaseText: ""
    property var warnings: []

    property var entries: []
    property string summaryText: ""
    property string buttonText: "Update"
    property bool restartNeeded: false

    property var result: null
    readonly property bool resultPending: root.result !== null && root.result.shown !== true
    readonly property string resultText: Words.outcomeText(root.result, root.version)
    readonly property bool wentBackByHand: Words.byHand(root.result)
    readonly property string skipped: root.wentBackByHand && root.commit(root.result.to ?? "") ? root.result.to : ""
    readonly property string skippedVersion: root.skipped === "" ? "" : root.result.toLabel || root.skipped.slice(0, 7)
    readonly property bool canReinstall: root.resultPending && root.skipped !== "" && !root.busy && !root.paused

    property date checkedAt: new Date(0)

    readonly property bool busy: root.state === root.downloading || root.state === root.verifying || root.state === root.restarting

    property bool checking: false

    readonly property string channel: Words.channelOf(Config.values.updates.channel)
    readonly property string branch: Words.branchFor(Config.values.updates.channel, Config.values.updates.branch)
    readonly property string channelLabel: Words.channelText(Config.values.updates.channel, Config.values.updates.branch)
    readonly property string version: WhatsNew.version
    property string targetVersion: ""
    property string previous: ""
    property string previousVersion: ""
    readonly property bool canGoBack: root.commit(root.previous) && !root.busy && !root.paused
    property bool goingBack: false
    readonly property string remote: Config.values.updates.remote

    readonly property string dir: Quickshell.shellDir
    readonly property string cli: Quickshell.shellPath("cli/banditshell")

    readonly property string statePath: `${Config.stateDir}/update.json`
    readonly property string resultPath: `${Config.stateDir}/update/result.json`
    readonly property string progressPath: `${Config.stateDir}/update/progress.log`
    readonly property real fetchGap: 30 * 60 * 1000

    property real fetchedAt: 0
    property string fetchedRemote: ""
    property string fetchedBranch: ""
    property bool remembered: false
    property bool fetching: false

    property string lastPhase: ""
    property real startedAt: 0

    readonly property string headline: {
        if (root.state === root.updated)
            return "Updated";
        if (root.state === root.rolledback)
            return root.wentBackByHand ? "Back on the previous version" : "Update rolled back";
        if (root.state === root.restarting)
            return root.goingBack ? "Going back..." : "Restarting...";
        if (root.state === root.verifying)
            return "Checking it loads...";
        if (root.state === root.downloading)
            return "Updating...";
        if (root.state === root.failed)
            return root.goingBack ? "Going back failed" : "Update failed";
        if (root.paused)
            return `This copy is on ${root.headBranch === "HEAD" ? "no branch" : root.headBranch}, so it does not follow ${root.branch}`;
        if (root.diverged)
            return `${root.behind} new on ${root.branch}, but this copy has ${root.ahead} of its own`;
        if (root.behind > 0)
            return `${root.behind} new commit${root.behind === 1 ? "" : "s"} on ${root.branch}`;
        return "You are up to date";
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
        root.checking = true;
        root.fetching = fetch;
        watchdog.restart();

        checker.command = fetch ? ["bash", root.cli, "update", "check", "--json"] : ["bash", root.cli, "update", "check", "--json", "--no-fetch"];
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

    function apply(): void {
        if (root.busy || root.checking || root.paused || root.diverged)
            return;

        root.error = "";
        if (!root.commit(root.target)) {
            root.error = "Nothing has been checked yet. Refresh first.";
            return;
        }
        root.take(root.target);
    }

    function reinstall(): void {
        if (!root.canReinstall || root.checking)
            return;

        const sha = root.skipped;
        root.dismissResult();
        if (Config.values.updates.skip === sha)
            Config.set("updates.skip", "");
        root.error = "";
        root.take(sha);
    }

    function take(sha: string): void {
        root.goingBack = false;
        root.state = root.downloading;
        root.phaseText = "Getting it...";
        root.warnings = [];
        root.lastPhase = "";
        root.startedAt = Math.floor(Date.now() / 1000) - 1;
        watchdog.restart();
        silence.restart();

        Quickshell.execDetached(["bash", root.cli, "update", "apply", "--detach", "--to", sha]);
    }

    function goBack(): void {
        if (!root.canGoBack)
            return;

        root.error = "";
        root.goingBack = true;
        root.state = root.restarting;
        root.phaseText = "Going back...";
        root.warnings = [];
        root.lastPhase = "";
        root.startedAt = Math.floor(Date.now() / 1000) - 1;
        watchdog.restart();
        silence.restart();

        Quickshell.execDetached(["bash", root.cli, "update", "rollback", "--detach"]);
    }

    function restart(): void {
        Quickshell.execDetached(["setsid", "bash", root.cli, "restart"]);
    }

    function dismissResult(): void {
        if (root.result === null)
            return;
        const kept = JSON.parse(JSON.stringify(root.result));
        kept.shown = true;
        resultFile.setText(JSON.stringify(kept));
        root.result = kept;
        if (root.state === root.updated || root.state === root.rolledback)
            root.state = root.idle;
    }

    function followProgress(text: string): void {
        const started = root.startedAt;
        const lines = String(text ?? "").split("\n");
        const warnings = [];
        let last = null;
        let failure = [];
        let back = false;
        for (const line of lines) {
            const phase = Words.phaseOf(line);
            if (phase === null || (Number(phase.at) || 0) < started)
                continue;
            last = phase;
            if (phase.phase === "goback")
                back = true;
            if (phase.phase === "warning")
                warnings.push(phase.text);
            else if (phase.phase === "failed")
                failure = phase.output ?? [phase.text ?? ""];
        }
        if (last === null)
            return;
        const settled = last.phase === "done" || last.phase === "rolledback" || last.phase === "failed";
        const fresh = Date.now() / 1000 - (Number(last.at) || 0) < 600;
        if (!root.busy && started === 0 && (settled || !fresh))
            return;

        silence.stop();
        root.goingBack = back;
        root.lastPhase = last.phase;
        root.phaseText = last.text ?? "";
        root.warnings = warnings;
        if (last.phase === "stage" || last.phase === "apply")
            root.state = root.downloading;
        else if (last.phase === "verify")
            root.state = root.verifying;
        else if (last.phase === "restart" || last.phase === "health" || last.phase === "goback")
            root.state = root.restarting;
        else if (last.phase === "done") {
            root.behind = 0;
            root.ahead = 0;
            root.state = root.updated;
            resultFile.reload();
            Qt.callLater(root.inspect, false);
        } else if (last.phase === "rolledback") {
            root.previous = "";
            root.state = root.rolledback;
            resultFile.reload();
        } else if (last.phase === "failed") {
            root.state = root.failed;
            root.error = Words.explain(failure, root.branch);
        }
        if (settled)
            watchdog.stop();
    }

    function takeResult(text: string): void {
        const data = Words.parseCheck(text);
        if (data === null || typeof data.ok !== "boolean") {
            root.result = null;
            return;
        }
        root.result = data;
        if (data.shown === true)
            return;
        if (data.ok) {
            root.state = root.updated;
            root.behind = 0;
        } else {
            root.state = root.rolledback;
            if (data.to && Config.values.updates.skip !== data.to)
                Config.set("updates.skip", data.to);
        }
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
                if (root.fetchedAt > 0)
                    root.checkedAt = new Date(root.fetchedAt);
            } catch (e) {
                console.warn(`Update: ${root.statePath} is not valid JSON; checking as if never fetched.`);
            }
            root.remembered = true;
        }

        onLoadFailed: root.remembered = true
    }

    FileView {
        id: resultFile

        path: root.resultPath
        printErrors: false
        watchChanges: true

        onFileChanged: resultFile.reload()
        onLoaded: root.takeResult(text())
        onLoadFailed: root.result = null
    }

    FileView {
        id: progressFile

        path: root.progressPath
        printErrors: false
        watchChanges: true

        onFileChanged: progressFile.reload()
        onLoaded: root.followProgress(text())
    }

    Timer {
        interval: 700
        running: root.busy
        repeat: true
        onTriggered: {
            progressFile.reload();
            resultFile.reload();
        }
    }

    Timer {
        id: silence

        interval: 30000
        onTriggered: {
            if (!root.busy || root.lastPhase !== "")
                return;
            root.state = root.failed;
            root.error = `${root.goingBack ? "Going back" : "The update"} did not start. banditshell update status tells where this copy stands.`;
        }
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

        interval: 600000

        onTriggered: {
            if (!root.checking && !root.busy)
                return;
            root.checking = false;
            checker.running = false;
            if (root.busy) {
                root.state = root.failed;
                root.error = "The update stopped answering and was stopped. Refresh to see where this copy stands.";
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

                const got = Words.parseCheck(text);
                if (got === null) {
                    root.error = "The check gave no answer.";
                    console.warn("Update: banditshell update check printed nothing readable");
                    return;
                }
                if (got.state === "error") {
                    root.error = Words.explain(got.output ?? [], root.branch);
                    console.warn(`Update: ${(got.output ?? []).join(" / ")}`);
                    return;
                }

                if (root.fetching)
                    root.remember();
                root.checkedAt = new Date(root.fetchedAt);

                const counts = got.state === "available" || got.state === "diverged";
                root.headBranch = got.headBranch ?? "";
                root.target = root.commit(got.target ?? "") ? got.target : "";
                root.targetVersion = got.targetVersion ?? "";
                root.previous = root.commit(got.previous ?? "") ? got.previous : "";
                root.previousVersion = got.previousVersion ?? "";
                root.behind = counts ? Number(got.behind) || 0 : 0;
                root.ahead = counts ? Number(got.ahead) || 0 : 0;
                root.entries = got.entries ?? [];
                root.summaryText = got.summary ?? "";
                root.buttonText = got.button ?? "Update";
                root.restartNeeded = got.class?.restart === true;

                if (root.busy || root.state === root.updated || root.state === root.rolledback)
                    return;
                if (root.behind > 0)
                    root.state = root.available;
                else if (root.state === root.available || root.state === root.failed)
                    root.state = root.idle;
            }
        }
    }
}
