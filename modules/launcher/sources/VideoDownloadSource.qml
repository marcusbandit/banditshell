import QtQuick
import Quickshell
import qs.services
import "../../../services/videos.js" as Videos
import "../search.js" as Search

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["video"]

    readonly property var asked: VideoDownloads.enabled ? Videos.videoUrl(root.search.text) : null
    readonly property bool listing: VideoDownloads.enabled && root.search.text.toLowerCase() === "downloads" && VideoDownloads.jobs.length > 0

    onAskedChanged: if (root.asked)
        VideoDownloads.probe()

    readonly property var caps: ({
            videos: 12
        })

    function jobRow(job: var, rank: real): var {
        const what = job.audio ? "audio" : "video";
        const progress = Videos.progressText(job.progress);
        const label = {
            starting: `Downloading ${what}`,
            downloading: `Downloading ${what}`,
            processing: job.audio ? "Converting audio" : "Joining video and sound",
            done: job.title || job.file.split("/").pop(),
            failed: `Download ${what} failed`,
            cancelled: `Download ${what} stopped`
        }[job.phase];
        const detail = {
            starting: job.title,
            downloading: [progress, job.title].filter(Boolean).join(" · "),
            processing: job.title,
            done: [Search.shortPath(job.file.slice(0, job.file.lastIndexOf("/")) || "/", Files.home), job.file.slice(job.file.lastIndexOf(".") + 1)].join(" · "),
            failed: job.error,
            cancelled: job.title
        }[job.phase];
        return {
            key: `video:${job.audio ? "audio" : "video"}:${job.url}`,
            kind: "video",
            url: job.url,
            audio: job.audio,
            job: job,
            label: label,
            detail: detail ?? "",
            icon: job.phase === "done" ? job.audio ? "audio_file" : "video_file" : job.phase === "failed" ? "error" : "download",
            score: rank
        };
    }

    function offerRow(url: string, host: string, audio: bool, rank: real): var {
        return {
            key: `video:${audio ? "audio" : "video"}:${url}`,
            kind: "video",
            url: url,
            audio: audio,
            job: null,
            label: audio ? "Download audio" : "Download video",
            detail: host,
            icon: audio ? "music_note" : "movie",
            score: rank
        };
    }

    readonly property var rows: {
        if (root.listing)
            return VideoDownloads.jobs.slice().reverse().map((job, i) => root.jobRow(job, 10 - i * 0.01));
        const asked = root.asked;
        if (!asked || VideoDownloads.probed && !VideoDownloads.found)
            return [];
        return (asked.audioOnly ? [true] : [false, true]).map((audio, i) => {
            const job = VideoDownloads.jobFor(asked.url, audio);
            return job ? root.jobRow(job, 8 - i * 0.01) : root.offerRow(asked.url, asked.host, audio, 8 - i * 0.01);
        });
    }

    readonly property var groups: [
        {
            key: "videos",
            title: "Download",
            items: root.rows
        }
    ]

    function activate(row: var): void {
        const first = root.actionsFor(row)[0];
        if (first)
            first.run();
    }

    function actionsFor(row: var): var {
        const job = row.job;
        if (job && (job.phase === "starting" || job.phase === "downloading" || job.phase === "processing"))
            return [
                {
                    icon: "stop",
                    label: "Stop",
                    run: () => VideoDownloads.cancel(job.id)
                }
            ];
        if (job && job.phase === "done") {
            const file = job.file;
            return [
                {
                    icon: "play_arrow",
                    label: "Open",
                    run: () => root.search.launch(() => Files.openWith(file))
                },
                {
                    icon: "drive_file_move",
                    label: "Show in folder",
                    run: () => root.search.leave(() => Files.reveal(file))
                },
                {
                    icon: "refresh",
                    label: "Download again",
                    short: "Again",
                    run: () => VideoDownloads.start(row.url, row.audio)
                }
            ];
        }
        return [
            {
                icon: "download",
                label: job ? "Try again" : row.label,
                run: () => VideoDownloads.start(row.url, row.audio)
            }
        ];
    }
}
