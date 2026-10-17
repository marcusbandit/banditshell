pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "videos.js" as Videos

Singleton {
    id: root

    readonly property bool enabled: (Config.values.launcher.online ?? {}).videos !== false

    property bool found: false
    property bool ffmpeg: false
    property bool probed: false
    property string cookies: ""
    property var queued: null

    readonly property string folder: Downloads.dir || `${System.home}/Downloads`

    property var jobs: []
    property var runs: ({})
    property int made: 0

    function probe(): void {
        if (!root.probed && !prober.running)
            prober.running = true;
    }

    function jobFor(url: string, audio: bool): var {
        for (let i = root.jobs.length - 1; i >= 0; i--) {
            const job = root.jobs[i];
            if (job.url === url && job.audio === audio)
                return job;
        }
        return null;
    }

    function update(id: int, change: var): void {
        root.jobs = root.jobs.map(j => j.id === id ? Object.assign({}, j, change) : j);
    }

    function start(url: string, audio: bool): void {
        root.launch(url, audio, "");
    }

    function retryWithCookies(url: string, audio: bool): void {
        if (root.cookies)
            root.launch(url, audio, root.cookies);
    }

    function launch(url: string, audio: bool, cookies: string): void {
        if (!root.probed) {
            root.queued = [url, audio, cookies];
            root.probe();
            return;
        }
        const running = root.jobFor(url, audio);
        if (!root.found || running && (running.phase === "downloading" || running.phase === "starting" || running.phase === "processing"))
            return;
        root.made += 1;
        const id = root.made;
        root.jobs = root.jobs.filter(j => !(j.url === url && j.audio === audio)).concat([
            {
                id: id,
                url: url,
                audio: audio,
                phase: "starting",
                progress: null,
                title: "",
                file: "",
                error: "",
                signIn: false,
                withCookies: !!cookies
            }
        ]).slice(-12);
        const run = runner.createObject(root, {
            jobId: id,
            audio: audio,
            command: Videos.command(url, audio, root.folder, root.ffmpeg, cookies)
        });
        root.runs[id] = run;
        run.running = true;
    }

    function cancel(id: int): void {
        const run = root.runs[id];
        if (!run)
            return;
        run.cancelled = true;
        run.running = false;
    }

    function notify(summary: string, body: string, icon: string): void {
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", icon, summary, body]);
    }

    Process {
        id: prober

        command: ["sh", "-c", 'command -v yt-dlp >/dev/null && echo yt-dlp; command -v ffmpeg >/dev/null && echo ffmpeg; command -v python3 >/dev/null && python3 -I "$1" | sed "s/^/cookies=/"; true', "sh", `${Quickshell.shellDir}/scripts/browser-cookies.py`]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.found = lines.indexOf("yt-dlp") >= 0;
                root.ffmpeg = lines.indexOf("ffmpeg") >= 0;
                root.cookies = (lines.find(l => l.indexOf("cookies=") === 0) ?? "").slice(8);
                root.probed = true;
                const waiting = root.queued;
                root.queued = null;
                if (waiting)
                    root.launch(waiting[0], waiting[1], waiting[2]);
            }
        }
    }

    Component {
        id: runner

        Process {
            id: run

            property int jobId: 0
            property bool audio: false
            property bool cancelled: false
            property string title: ""
            property string file: ""
            property string complaint: ""

            stdout: SplitParser {
                onRead: line => {
                    const progress = Videos.readProgress(line);
                    if (progress) {
                        root.update(run.jobId, {
                            phase: progress.status === "finished" ? "processing" : "downloading",
                            progress: progress
                        });
                        return;
                    }
                    if (line.indexOf("@@title ") === 0) {
                        run.title = line.slice(8);
                        root.update(run.jobId, {
                            title: run.title
                        });
                    } else if (line.indexOf("@@file ") === 0) {
                        run.file = line.slice(7);
                    }
                }
            }

            stderr: SplitParser {
                onRead: line => {
                    if (line.indexOf("ERROR") === 0 || !run.complaint && line.trim())
                        run.complaint = line.trim();
                }
            }

            onExited: code => {
                if (run.cancelled) {
                    root.update(run.jobId, {
                        phase: "cancelled"
                    });
                } else if (code === 0 && run.file) {
                    root.update(run.jobId, {
                        phase: "done",
                        file: run.file
                    });
                    root.notify(run.audio ? "Audio downloaded" : "Video downloaded", run.title || run.file.split("/").pop(), "folder-download");
                } else {
                    root.update(run.jobId, {
                        phase: "failed",
                        error: Videos.shortError(run.complaint),
                        signIn: Videos.needsSignIn(run.complaint)
                    });
                    root.notify("Download failed", Videos.shortError(run.complaint) || run.title, "dialog-error");
                }
                delete root.runs[run.jobId];
                run.destroy();
            }
        }
    }
}
