pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// WHETHER THE PUBLIC REPO IS AHEAD OF THIS MACHINE, and what to do about it.
//
// The shell is its own update channel: the author pushes to GitHub, and the
// copy running on the machine is a checkout. So the question "is there an
// update" is a question GIT can answer, and this service asks it once at every
// launch - fetch the tracked branch from the public remote and count what it
// has that the local HEAD does not. A quiet interval re-check keeps an
// up-for-days session honest about pushes that landed after the boot.
//
// THE STATE MACHINE, five states and one direction through them:
//
//   idle        the checkout is current, or nothing is confirmed yet. The
//               marker is quiet: grey, a size down, still there - it is the
//               way in to "search for update" as much as a report.
//   available   the remote is ahead. RED, full size, above the clock.
//   downloading  the pull is running.
//   downloaded  the pull landed. BLUE, and a restart applies it.
//   failed      the pull tried and did not land. AMBER, wearing a glyph of
//               its own - because "a push is waiting" and "the pull hit
//               something" are different facts, and a failed pull wearing
//               the waiting red would ask for a download that will not land
//               any better on a second press.
//
// A downloaded state is TERMINAL until the restart: a later re-check finds the
// checkout current (the pull already landed) and would happily flip the blue
// back to nothing, taking the restart prompt with it. So a check may raise
// idle -> available but is never allowed to lower downloaded. A FAILED state
// is the opposite of terminal: it is an alarm about a reason, and a later
// check that comes back clean - or still merely counts commits - is the
// reason gone, and resolves the amber to whatever the checkout's real state
// is. Idle does not carry stale alarms; that is what the menu's error line is
// for.
//
// The WORK is git against Quickshell.shellDir, the folder this shell was
// loaded from. When the shell came up from the last-known-good snapshot
// instead (see bin/banditshell's start_backup), there is no .git in that
// folder, git says so on stderr, and the error is captured for the menu
// rather than blinked on the bar: a shell running from a snapshot is itself
// the reason it did not come up from the checkout.
Singleton {
    id: root

    // The five states, named so no call site spells a string.
    readonly property string idle: "idle"
    readonly property string available: "available"
    readonly property string downloading: "downloading"
    readonly property string downloaded: "downloaded"
    readonly property string failed: "failed"

    property string state: root.idle

    // HOW FAR BEHIND the checkout is, in commits, and WHICH commit the remote
    // is on, for the menu's caption.
    property int behind: 0
    property string remoteHead: ""

    // WHAT WENT WRONG, said in the menu rather than on the bar. An offline
    // machine is not an emergency; the next check clears it.
    property string error: ""

    // WHEN THE LAST COMPLETED CHECK finished, for the menu's "checked ago".
    property date checkedAt: new Date(0)

    readonly property bool busy: root.state === root.downloading

    // A GIT OPERATION IS IN FLIGHT, from the moment one is asked for until its
    // output has been READ WHOLE. Not the same thing as the process running:
    // there is a gap between a process exiting and its collector finishing,
    // and reassigning a Process's command inside that gap force-closes the old
    // stream and delivers its parse half-drunk (this shipped as a first check
    // that reliably reported a count and no head). Every launcher asks this
    // flag and only the collectors clear it.
    property bool checking: false

    // WHICH BRANCH IS TRACKED, a setting and not a decision of this file's,
    // and a CONFIG choice, not a menu one: `updates.branch` in config.json,
    // main by default. The binding makes the branch's `changed` signal the
    // re-check's trigger, so editing the file asks the new branch's question
    // at once, live, like every other setting.
    readonly property string branch: Config.values.updates.branch
    readonly property string remote: Config.values.updates.remote

    // THE CHECKOUT, wherever the shell was actually loaded from.
    readonly property string dir: Quickshell.shellDir

    // ---- THE CHECK ---------------------------------------------------------
    //
    // One shell line: fetch the tracked branch from the public remote, then
    // print the count and the remote head as marked lines. Marked, because git
    // writes progress and notices onto the same stream (stderr is folded in)
    // and a parser that trusted the whole of stdout would one day read a
    // "hint:" as a number.
    function check(): void {
        // A pull and a check racing in both directions answers two different
        // questions with one fetch; the download owns the remote until it is
        // done. And a second check starting inside the first's drain gap
        // would half-read it - see `checking`.
        if (root.busy || root.checking)
            return;

        root.checkedBranch = root.branch;
        root.error = "";
        root.checking = true;
        watchdog.restart();

        const q = s => `'${s.replace(/'/g, `'\\''`)}'`;
        // The command reports its own fate ON THE STREAM (`count=`/`head=` on
        // success, `error=` on failure) rather than through the exit code, so
        // the collector holds everything the parse needs.
        checker.command = ["sh", "-c", `if out=$(git -C ${q(root.dir)} fetch --quiet ${q(root.remote)} ${q(root.branch)} 2>&1); then printf 'count=%s\\n' "$(git -C ${q(root.dir)} rev-list --count HEAD..${q(root.remote)}/${q(root.branch)})"; printf 'head=%s\\n' "$(git -C ${q(root.dir)} rev-parse --short ${q(root.remote)}/${q(root.branch)})"; else printf 'error=%s\\n' "$(printf '%s' "$out" | tail -1)"; fi`];
        checker.running = true;
    }

    // ---- THE DOWNLOAD ------------------------------------------------------
    //
    // A FAST-FORWARD OR NOTHING. The checkout is the machine's copy of a branch
    // the author pushes to; if the two have diverged, merging is a decision a
    // person makes at a terminal, not one an indicator makes on a click, so
    // --ff-only refuses and the menu says why.
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

    // ---- THE RESTART -------------------------------------------------------
    //
    // THROUGH THE CLI, not a kill of our own process: the CLI's restart proves
    // the shell came back up, and falls to the last-known-good snapshot when
    // the checkout does not load - which is exactly the risk of running code
    // that only just arrived. Detached, because this process is the thing
    // being replaced.
    function restart(): void {
        const cli = `${Quickshell.env("HOME")}/bin/banditshell`;
        Quickshell.execDetached(["sh", "-c",
            `if [ -x '${cli}' ]; then exec '${cli}' restart; else exec banditshell restart; fi`]);
    }

    // THE LAUNCH CHECK, delayed a beat: the session is still standing its own
    // network up at boot, and a fetch raced against it answers "no" for
    // reasons that are not the repo's. The interval check below carries the
    // rest of the schedule.
    Timer {
        interval: 1500
        running: true
        repeat: false
        onTriggered: root.check()
    }

    // The re-check while the shell is up. Minutes from config; 0 disables it
    // and makes the launch the only automatic check, which is the contract the
    // config block promises.
    Timer {
        id: cycle

        interval: Math.max(0, Config.values.updates.interval) * 60 * 1000
        repeat: true
        running: interval > 0
        onTriggered: root.check()
    }

    // A branch flip re-asks at once. The Timer above carries the schedule;
    // this carries Config's own promise - edit config.json and the shell
    // follows live. Guarded by NAME as well as by `checking`, because the
    // binding also fires once at startup with the value it was already going
    // to say, and that is not a flip.
    property string checkedBranch: ""
    onBranchChanged: if (root.branch !== root.checkedBranch)
        root.check()

    // NO GIT OPERATION OWNS THE REMOTE FOREVER. `checking` is only cleared by
    // a collector's completion, and a collector whose process never ran (no
    // git, no network stack at the moment of spawn) never completes: without
    // this, one dead spawn would silence the indicator for the rest of the
    // session. A fetch that genuinely needs a minute gets it; anything past
    // five is a stuck process, and the machine goes back to asking.
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
            // MARKED LINES ONLY. `count=` and `head=` are this command's own
            // output; anything else on the stream was git talking and is
            // ignored on purpose. An `error=` line means the fetch itself
            // failed, and its payload is git's own complaint.
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

                // CLEARED BEFORE the state moves, not after: a listener on the
                // other side of that signal must be able to act at once (a
                // menu press arriving in the same tick as the answer it
                // reacts to), and it would be refused by a stale in-flight
                // flag.
                root.checking = false;
                watchdog.stop();

                // The directions a check moves the state: idle up to
                // available, and a FAILED state resolved - the alarm's reason
                // is a pull that would not land, and a check that comes back
                // with an ordinary answer is that reason gone. Never down
                // from downloaded - see the class comment.
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

                // Same order as the checker's: the flag goes before the state,
                // so whatever the transition wakes can act.
                root.checking = false;
                watchdog.stop();

                if (failure !== "") {
                    root.error = failure;
                    // FAILED, not available: the red state says "a press will
                    // get it", and that would be a lie the second time
                    // running. Amber says what happened, and the menu says
                    // git's own complaint.
                    root.state = root.failed;
                } else {
                    root.behind = 0;
                    root.state = root.downloaded;
                }
            }
        }
    }
}
