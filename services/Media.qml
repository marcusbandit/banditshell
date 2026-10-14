pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: (Mpris.players?.values ?? []).filter(p => !(p.dbusName ?? "").includes("playerctld"))

    property MprisPlayer chosen: null
    property MprisPlayer recent: null

    readonly property MprisPlayer active: {
        const list = root.players;
        if (root.chosen && list.includes(root.chosen))
            return root.chosen;
        if (root.recent?.isPlaying && list.includes(root.recent))
            return root.recent;
        const playing = list.find(p => p.isPlaying);
        if (playing)
            return playing;
        if (root.recent && list.includes(root.recent))
            return root.recent;
        return list[0] ?? null;
    }

    readonly property bool available: !!active
    readonly property bool playing: !!active?.isPlaying

    readonly property bool hasTrack: !!active?.trackTitle

    readonly property string title: active?.trackTitle || "nothing playing"
    readonly property string artist: active?.trackArtist || ""
    readonly property string album: active?.trackAlbum || ""
    readonly property string app: active?.identity || ""
    readonly property string artUrl: (active?.trackArtUrl || "").replace("https://open.spotify.com/image/", "https://i.scdn.co/image/")

    readonly property string trackId: root.pathOf(active?.metadata?.["mpris:trackid"])

    function pathOf(value: var): string {
        if (!value)
            return "";
        const text = String(value);
        const wrapped = /QDBusObjectPath\("([^"]*)"\)/.exec(text);
        return wrapped ? wrapped[1] : text;
    }
    readonly property bool isAdvert: root.trackId.includes("/ad/") || root.trackId.startsWith("spotify:ad:")
    readonly property bool isEpisode: root.trackId.includes("/episode/") || root.trackId.startsWith("spotify:episode:")

    readonly property string trackKey: `${root.active?.dbusName ?? ""}/${root.active?.uniqueId ?? 0}`
    property string lastPlayer: ""

    function started(player: MprisPlayer): void {
        root.recent = player;
        if (root.chosen !== player)
            root.chosen = null;
    }

    Instantiator {
        model: root.players

        delegate: Connections {
            required property MprisPlayer modelData

            target: modelData

            function onIsPlayingChanged(): void {
                if (modelData.isPlaying)
                    root.started(modelData);
            }
        }
    }

    function choose(player: MprisPlayer): void {
        root.chosen = player;
    }

    function cycle(step: int): void {
        const list = root.players;
        if (list.length < 2)
            return;
        const at = Math.max(0, list.indexOf(root.active));
        root.chosen = list[(at + step + list.length) % list.length];
    }

    readonly property real seekGuard: 2500
    readonly property real freshWindow: 3000

    property real anchor: 0
    property real anchorAt: Date.now()
    property bool runs: false
    property real anchorRate: 1
    property real lastSeekAt: 0
    property real freshUntil: 0

    readonly property real rate: root.active?.rate > 0 ? root.active.rate : 1
    readonly property bool loopsTrack: root.active?.loopState === MprisLoopState.Track

    function now(): real {
        let t = root.anchor;
        if (root.runs)
            t += (Date.now() - root.anchorAt) / 1000 * root.anchorRate;
        if (root.length > 0)
            t = root.loopsTrack && t >= root.length ? t % root.length : Math.min(root.length, t);
        return Math.max(0, t);
    }

    property real position: 0

    function place(seconds: real): void {
        root.anchor = Math.max(0, seconds);
        root.anchorAt = Date.now();
        root.runs = !!root.active?.isPlaying;
        root.anchorRate = root.active?.rate > 0 ? root.active.rate : 1;
        root.position = root.now();
    }

    onRateChanged: root.place(root.now())

    function hear(reported: real): void {
        const now = Date.now();
        if (now < root.freshUntil) {
            root.place(reported);
            return;
        }
        if (now - root.lastSeekAt < root.seekGuard)
            return;
        if (Math.abs(reported - root.now()) > 0.35)
            root.place(reported);
    }

    readonly property real playerPosition: active?.position ?? 0

    onPlayerPositionChanged: root.hear(root.playerPosition)

    onTrackKeyChanged: {
        const player = root.active?.dbusName ?? "";
        const switched = player !== root.lastPlayer;
        root.lastPlayer = player;

        root.heldLength = 0;
        root.adoptLength();
        root.freshUntil = Date.now() + root.freshWindow;
        root.lastSeekAt = 0;
        root.place(switched ? root.active?.position ?? 0 : 0);
    }

    onPlayingChanged: {
        root.position = root.now();
        root.place(root.position);

        if (!root.playing && Date.now() - root.lastSeekAt > 2000)
            root.adoptLength();
    }

    Component.onCompleted: {
        root.lastPlayer = root.active?.dbusName ?? "";
        root.recent = root.players.find(p => p.isPlaying) ?? null;
        root.adoptLength();
        root.place(root.active?.position ?? 0);
    }

    property real heldLength: 0

    readonly property real reportedLength: root.active?.lengthSupported ? root.active.length : 0

    onReportedLengthChanged: {
        if (root.heldLength === 0 || Date.now() < root.freshUntil)
            root.adoptLength();
    }

    function adoptLength(): void {
        const reported = root.active?.lengthSupported ? root.active.length : 0;
        if (reported > 5)
            root.heldLength = reported;
    }

    readonly property real length: root.heldLength

    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function toggle(): void {
        if (!active)
            return;
        if (active.isPlaying && active.canPause)
            active.pause();
        else if (active.canPlay)
            active.play();
    }

    function next(): void {
        if (active?.canGoNext)
            active.next();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    readonly property bool canRaise: !!active?.canRaise

    function raise(): void {
        if (active?.canRaise)
            active.raise();
    }

    readonly property bool canShuffle: !!active?.canControl && !!active?.shuffleSupported
    readonly property bool shuffle: !!active?.shuffle

    function toggleShuffle(): void {
        if (root.canShuffle)
            active.shuffle = !active.shuffle;
    }

    readonly property bool canLoop: !!active?.canControl && !!active?.loopSupported
    readonly property int loop: active?.loopState ?? MprisLoopState.None

    function cycleLoop(): void {
        if (!root.canLoop)
            return;
        const order = [MprisLoopState.None, MprisLoopState.Playlist, MprisLoopState.Track];
        active.loopState = order[(order.indexOf(active.loopState) + 1) % order.length];
    }

    readonly property bool canSeek: !!active?.canSeek

    function seekTo(seconds: real): void {
        if (!active?.canSeek)
            return;
        const target = root.length > 0 ? Math.max(0, Math.min(root.length, seconds)) : Math.max(0, seconds);
        root.lastSeekAt = Date.now();
        root.freshUntil = 0;
        root.place(target);
        active.position = target;
        verify.restart();
    }

    Timer {
        id: verify

        interval: root.seekGuard + 250

        onTriggered: root.sync()
    }

    function seekBy(offset: real): void {
        root.seekTo(root.now() + offset);
    }

    function timeLabel(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "";
        const total = Math.floor(seconds);
        const h = Math.floor(total / 3600);
        const m = Math.floor(total / 60) % 60;
        const s = total % 60;
        const ss = s.toString().padStart(2, "0");
        return h > 0 ? `${h}:${m.toString().padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    property real stuckSince: 0

    Timer {
        interval: 250
        repeat: true
        running: root.playing

        onTriggered: {
            root.position = root.now();

            const atEnd = root.length > 0 && !root.loopsTrack && root.position >= root.length - 0.05;
            if (!atEnd)
                root.stuckSince = 0;
            else if (root.stuckSince === 0)
                root.stuckSince = Date.now();
            else if (Date.now() - root.stuckSince > 2500) {
                root.stuckSince = Date.now();
                root.sync();
            }
        }
    }

    function sync(): void {
        if (!root.active || probe.running)
            return;
        probe.key = root.trackKey;
        probe.playing = root.playing;
        probe.askedAt = Date.now();
        probe.running = true;
    }

    Process {
        id: probe

        property string key: ""
        property bool playing: false
        property real askedAt: 0

        command: ["busctl", "--user", "get-property", root.active?.dbusName ?? "", "/org/mpris/MediaPlayer2", "org.mpris.MediaPlayer2.Player", "Position"]

        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.trim().match(/^x\s+(-?\d+)$/);
                if (!m || probe.key !== root.trackKey || probe.playing !== root.playing)
                    return;
                if (probe.askedAt - root.lastSeekAt < root.seekGuard)
                    return;
                const lag = root.playing ? (Date.now() - probe.askedAt) / 2000 : 0;
                const heard = parseInt(m[1], 10) / 1e6 + lag;
                if (Math.abs(heard - root.now()) > 0.35)
                    root.place(heard);
            }
        }
    }
}
