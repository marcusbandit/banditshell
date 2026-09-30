pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    property MprisPlayer chosen: null

    readonly property var players: Mpris.players?.values ?? []

    readonly property MprisPlayer active: {

        if (chosen && root.players.includes(chosen))
            return chosen;
        return root.players.find(p => p.isPlaying) ?? root.players[0] ?? null;
    }

    readonly property bool available: !!active
    readonly property bool playing: !!active?.isPlaying

    readonly property bool hasTrack: !!active?.trackTitle

    readonly property string title: active?.trackTitle || "nothing playing"
    readonly property string artist: active?.trackArtist || ""
    readonly property string album: active?.trackAlbum || ""
    readonly property string app: active?.identity || ""
    readonly property string artUrl: active?.trackArtUrl || ""

    property real localPosition: 0

    function adopt(): void {
        root.localPosition = root.active?.position ?? 0;
        root.adoptLength();
    }

    property bool adoptNext: false

    readonly property string trackKey: (active?.trackId ?? "") + "/" + (active?.trackTitle ?? "")

    onTrackKeyChanged: {
        root.adoptNext = true;
        root.active?.positionChanged();
    }

    Component.onCompleted: root.adopt()

    readonly property real position: root.localPosition
    readonly property real playerPosition: active?.position ?? 0

    onPlayerPositionChanged: {
        if (root.adoptNext) {
            root.adoptNext = false;
            root.adopt();
        }
    }

    property real heldLength: 0
    property real lastSeekAt: 0

    function adoptLength(): void {
        const reported = root.active?.length ?? 0;

        if (reported > 5)
            root.heldLength = reported;
    }

    readonly property real length: root.heldLength

    onPlayingChanged: {
        if (!root.playing && Date.now() - root.lastSeekAt > 2000)
            root.adoptLength();
    }

    readonly property real progress: length > 0 ? Math.max(0, Math.min(1, position / length)) : 0

    function choose(player: MprisPlayer): void {
        root.chosen = player;
    }

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

    readonly property bool canRaise: !!active?.canRaise

    function raise(): void {
        if (active?.canRaise)
            active.raise();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    readonly property bool canSeek: !!active?.canSeek

    function seekTo(seconds: real): void {
        if (!active?.canSeek)
            return;
        root.lastSeekAt = Date.now();
        root.localPosition = root.length > 0 ? Math.max(0, Math.min(root.length, seconds)) : seconds;
        active.position = seconds;
    }

    function seekBy(offset: real): void {
        if (!active?.canSeek)
            return;
        root.lastSeekAt = Date.now();
        root.localPosition = root.length > 0 ? Math.max(0, Math.min(root.length, root.localPosition + offset)) : Math.max(0, root.localPosition + offset);
        active.seek(offset);
    }

    function timeLabel(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return `${m}:${s.toString().padStart(2, "0")}`;
    }

    property real clockAt: 0

    Timer {
        interval: 1000
        repeat: true
        running: root.playing

        onRunningChanged: if (running)
            root.clockAt = Date.now()

        onTriggered: {
            const now = Date.now();
            const step = (now - root.clockAt) / 1000;
            root.clockAt = now;
            if (root.length > 0)
                root.localPosition = Math.min(root.length, root.localPosition + step);
            else
                root.localPosition = root.localPosition + step;
        }
    }
}
