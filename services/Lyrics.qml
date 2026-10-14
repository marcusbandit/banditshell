pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "lyrics.js" as Parse

Singleton {
    id: root

    readonly property string api: "https://lrclib.net/api"
    readonly property string client: "banditshell (https://github.com/marcusbandit/banditshell)"

    readonly property bool enabled: Config.values.media.lyrics
    readonly property real lead: Config.values.media.lyricsLead

    property int demand: 0

    function hold(): void {
        root.demand++;
    }

    function release(): void {
        root.demand = Math.max(0, root.demand - 1);
    }

    readonly property bool eligible: root.enabled && Media.hasTrack && !Media.isAdvert && !Media.isEpisode
    readonly property string key: root.eligible ? [Media.active?.dbusName ?? "", Media.artist, Media.title, Media.album].join("\n") : ""

    readonly property string spotifyId: root.spotifyIdOf(Media.trackId)

    function spotifyIdOf(trackId: string): string {
        const m = /(?:\/com\/spotify\/track\/|spotify:track:)([A-Za-z0-9]+)$/.exec(trackId ?? "");
        return m ? m[1] : "";
    }

    function spotifyIdNow(): string {
        return root.spotifyIdOf(Media.pathOf(Media.active?.metadata?.["mpris:trackid"]));
    }

    onSpotifyIdChanged: {
        const job = root.job;
        if (job && !job.id && root.spotifyId && job.key === root.key) {
            job.id = root.spotifyId;
            root.askSpicy();
        }
    }

    property string state: "idle"
    property string source: ""
    property var lines: []
    property var plainLines: []
    property var writers: []

    property bool spicyAbsent: false

    readonly property bool synced: root.state === "synced"
    readonly property bool plain: root.state === "plain"
    readonly property bool ready: root.synced || root.plain
    readonly property bool loading: root.state === "loading"

    property var cache: ({})
    property var order: []
    readonly property int cacheSize: 64

    property var job: null

    readonly property var spicyWaits: [300, 700, 1200, 2000, 3000, 4000]
    readonly property int lrclibAfter: 1800

    function indexAt(t: real): int {
        return root.synced ? Parse.lineAt(root.lines, t + root.lead) : -1;
    }

    function progressOf(words: var, t: real): real {
        return Parse.progress(words, t + root.lead);
    }

    function gapFillAt(entry: var, t: real): real {
        return Parse.gapFill(entry, t + root.lead);
    }

    function layout(widths: var, space: real, room: real): var {
        return Parse.layout(widths, space, room);
    }

    function litWidth(row: var, widths: var, position: real): real {
        return Parse.litWidth(row, widths, position);
    }

    function remember(key: string, found: var): void {
        root.cache[key] = found;
        root.order = root.order.filter(k => k !== key).concat([key]);
        while (root.order.length > root.cacheSize)
            delete root.cache[root.order.shift()];
    }

    function show(found: var): void {
        root.source = found.source ?? "";
        root.writers = found.writers ?? [];
        if (found.kind === "synced") {
            root.plainLines = [];
            root.lines = found.lines;
            root.state = "synced";
        } else if (found.kind === "plain") {
            root.lines = [];
            root.plainLines = found.lines;
            root.state = "plain";
        } else {
            root.lines = [];
            root.plainLines = [];
            root.state = found.kind;
        }
    }

    function rank(found: var): int {
        if (!found)
            return 0;
        switch (found.kind) {
        case "synced":
            return found.source === "Spicy Lyrics" ? 6 : 5;
        case "plain":
            return found.source === "Spicy Lyrics" ? 4 : 3;
        case "instrumental":
            return 2;
        default:
            return 1;
        }
    }

    function decide(): void {
        const job = root.job;
        if (!job || job.key !== root.key)
            return;
        const best = root.rank(job.spicy) >= root.rank(job.lrclib) ? job.spicy : job.lrclib;
        const spicyBest = job.spicy?.kind === "synced";
        const finished = spicyBest || ((job.spicyDone || !job.id) && job.lrclibDone);

        if (best && (best.kind === "synced" || finished))
            root.show(best);
        else if (finished)
            root.show({
                kind: job.failed ? "failed" : "missing",
                source: ""
            });
        else
            root.state = "loading";

        if (finished) {
            if (!job.failed && best)
                root.remember(job.key, best);
            root.finish();
        }
    }

    function finish(): void {
        spicyRetry.stop();
        lrclibLater.stop();
        root.abort();
        root.job = null;
    }

    onKeyChanged: root.begin()
    onDemandChanged: if (root.demand > 0)
        root.begin()

    function begin(): void {
        const key = root.key;
        if (!key) {
            root.finish();
            root.show({
                kind: "idle"
            });
            return;
        }
        if (root.job?.key === key)
            return;

        const id = root.spotifyIdNow();
        const hit = root.cache[key];
        if (hit && (hit.source === "Spicy Lyrics" || !id)) {
            root.finish();
            root.show(hit);
            return;
        }
        if (root.demand <= 0) {
            root.finish();
            root.show({
                kind: "idle"
            });
            return;
        }

        root.finish();
        root.job = {
            key: key,
            id: id,
            spicy: undefined,
            lrclib: hit ?? undefined,
            spicyDone: false,
            lrclibDone: !!hit,
            tries: 0,
            failed: false
        };
        if (hit)
            root.show(hit);
        else {
            root.lines = [];
            root.plainLines = [];
            root.state = "loading";
        }

        if (root.job.id) {
            root.askSpicy();
            if (!hit)
                lrclibLater.restart();
        } else
            root.askLrclib();
    }

    function askSpicy(): void {
        const job = root.job;
        if (!job || !job.id || spicy.running)
            return;
        spicy.key = job.key;
        spicy.command = ["python3", Quickshell.shellPath("scripts/spicy-lyrics.py"), job.id];
        spicy.running = true;
    }

    Process {
        id: spicy

        property string key: ""

        stdout: StdioCollector {
            onStreamFinished: {
                const job = root.job;
                if (!job)
                    return;
                if (spicy.key !== job.key) {
                    if (job.id && !job.spicyDone)
                        Qt.callLater(root.askSpicy);
                    return;
                }
                let content = null;
                try {
                    content = text.trim() ? JSON.parse(text) : null;
                } catch (e) {
                    content = null;
                }
                if (!content) {
                    job.tries++;
                    if (job.tries < root.spicyWaits.length) {
                        spicyRetry.interval = root.spicyWaits[job.tries];
                        spicyRetry.restart();
                    } else {
                        job.spicyDone = true;
                        if (!job.lrclibDone && !root.pending)
                            root.askLrclib();
                        root.decide();
                    }
                    return;
                }
                job.spicyDone = true;
                root.spicyAbsent = content.Type === "Absent";
                const model = Parse.fromSpicy(content, Media.length);
                if (model?.synced)
                    job.spicy = {
                        kind: "synced",
                        lines: model.synced,
                        writers: model.writers,
                        source: "Spicy Lyrics"
                    };
                else if (model?.plain)
                    job.spicy = {
                        kind: "plain",
                        lines: model.plain,
                        writers: model.writers,
                        source: "Spicy Lyrics"
                    };
                if (job.spicy?.kind !== "synced" && !job.lrclibDone && !root.pending)
                    root.askLrclib();
                root.decide();
            }
        }
    }

    Timer {
        id: spicyRetry

        onTriggered: root.askSpicy()
    }

    Timer {
        id: lrclibLater

        interval: root.lrclibAfter

        onTriggered: {
            if (root.job && !root.job.lrclibDone && !root.pending)
                root.askLrclib();
        }
    }

    property var pending: null

    function abort(): void {
        if (root.pending) {
            const xhr = root.pending;
            root.pending = null;
            xhr.abort();
        }
        timeout.stop();
    }

    function request(url: string, done: var): void {
        const xhr = new XMLHttpRequest();
        root.pending = xhr;
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE || root.pending !== xhr)
                return;
            root.pending = null;
            timeout.stop();
            let body = null;
            try {
                body = xhr.status === 200 ? JSON.parse(xhr.responseText) : null;
            } catch (e) {
                body = null;
            }
            done(xhr.status, body);
        };
        xhr.open("GET", url);
        xhr.setRequestHeader("Lrclib-Client", root.client);
        xhr.send();
        timeout.restart();
    }

    Timer {
        id: timeout

        interval: 9000

        onTriggered: {
            const job = root.job;
            root.abort();
            if (!job)
                return;
            job.lrclibDone = true;
            job.failed = !job.spicy;
            root.decide();
        }
    }

    function lrclibFound(record: var): var {
        if (!record)
            return null;
        if (record.syncedLyrics) {
            const lines = Parse.fromLrc(Parse.parseLrc(record.syncedLyrics), Media.length || record.duration || 0);
            if (lines.some(l => !l.gap))
                return {
                    kind: "synced",
                    lines: lines,
                    source: "lrclib.net"
                };
        }
        if (record.plainLyrics)
            return {
                kind: "plain",
                lines: Parse.plain(record.plainLyrics),
                source: "lrclib.net"
            };
        if (record.instrumental)
            return {
                kind: "instrumental",
                source: "lrclib.net"
            };
        return null;
    }

    function askLrclib(): void {
        const job = root.job;
        if (!job || job.lrclibDone)
            return;
        lrclibLater.stop();

        const wanted = {
            title: Media.title,
            artist: Media.artist,
            album: Media.album,
            length: Media.length || Media.reportedLength
        };

        const steps = [
            `get?${Parse.query({
                track_name: wanted.title,
                artist_name: wanted.artist,
                album_name: wanted.album,
                duration: wanted.length > 0 ? Math.round(wanted.length) : ""
            })}`,
            `search?${Parse.query({
                track_name: Parse.cleanTitle(wanted.title),
                artist_name: Parse.firstArtist(wanted.artist)
            })}`,
            `search?${Parse.query({
                q: `${Parse.cleanTitle(wanted.title)} ${Parse.firstArtist(wanted.artist)}`
            })}`
        ];

        let fallback = null;

        const settle = found => {
            if (root.job !== job)
                return;
            job.lrclibDone = true;
            job.lrclib = found;
            root.decide();
        };

        const step = i => {
            if (root.job !== job)
                return;
            if (i >= steps.length) {
                settle(root.lrclibFound(fallback));
                return;
            }
            root.request(`${root.api}/${steps[i]}`, (status, body) => {
                if (root.job !== job)
                    return;
                if (status === 0) {
                    job.failed = !job.spicy;
                    settle(root.lrclibFound(fallback));
                    return;
                }
                const found = Array.isArray(body) ? Parse.pick(body, wanted) : body;
                if (found?.syncedLyrics || found?.instrumental) {
                    settle(root.lrclibFound(found));
                    return;
                }
                if (found?.plainLyrics && !fallback)
                    fallback = found;
                step(i + 1);
            });
        };

        step(0);
    }

    function retry(): void {
        if (!root.key)
            return;
        delete root.cache[root.key];
        root.finish();
        root.begin();
    }
}
