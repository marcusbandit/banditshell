pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// MPRIS, adapted.
//
// "The player" is not a thing MPRIS has: a machine can have five, and browsers
// register one per tab. So this picks: whatever is playing, else whatever played
// last, else the first that exists. Sticking to the last CHOSEN one while it
// still exists matters more than picking cleverly, because a control that jumps
// to a different player mid-press is worse than one pointed at the wrong player.
Singleton {
    id: root

    property MprisPlayer chosen: null

    readonly property var players: Mpris.players?.values ?? []

    readonly property MprisPlayer active: {
        // Whatever the user last acted on, while it lasts.
        if (chosen && root.players.includes(chosen))
            return chosen;
        return root.players.find(p => p.isPlaying) ?? root.players[0] ?? null;
    }

    readonly property bool available: !!active
    readonly property bool playing: !!active?.isPlaying

    // Something with a NAME, which is not the same question as `available`.
    //
    // A player REGISTERS when the application starts, not when it plays: an open
    // Spotify that has never been asked for anything is a live MPRIS player with
    // an empty track. That is worth showing in the media menu, which is where you
    // go to pick a player, and is exactly what must not appear anywhere else: a
    // preview whose whole job is to say what is playing has nothing to say.
    readonly property bool hasTrack: !!active?.trackTitle

    readonly property string title: active?.trackTitle || "nothing playing"
    readonly property string artist: active?.trackArtist || ""
    readonly property string album: active?.trackAlbum || ""
    readonly property string app: active?.identity || ""
    readonly property string artUrl: active?.trackArtUrl || ""

    readonly property real position: active?.position ?? 0
    readonly property real length: active?.length ?? 0
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

    // Bring the player itself up. The preview says what is playing, and the
    // question it cannot answer is always "what IS this", so the artwork is a
    // way back to the application that knows. Not every player offers it: a
    // browser tab is a window MPRIS cannot raise on its own.
    readonly property bool canRaise: !!active?.canRaise

    function raise(): void {
        if (active?.canRaise)
            active.raise();
    }

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    // Seeking is a capability a player advertises on its own, separate from
    // playing at all: a browser tab streaming live radio has a position and no
    // way to move it. The scrubber takes input only while this is true.
    readonly property bool canSeek: !!active?.canSeek

    // Go to a place in the track, in seconds from its start.
    function seekTo(seconds: real): void {
        if (!active?.canSeek)
            return;
        active.position = Math.max(0, Math.min(root.length, seconds));
        reask.restart();
    }

    // Move by an amount, in seconds, signed.
    function seekBy(offset: real): void {
        if (!active?.canSeek)
            return;
        active.seek(offset);
        reask.restart();
    }

    // A seek is a REQUEST. The player answers it with a Seeked signal when it
    // has moved, and until then the position it reports is the old one, which
    // matters most for a paused track: nothing else polls a paused player, so
    // a seek it acknowledged quietly would show the old place until the next
    // press of play. So the position is asked for again a moment after every
    // seek, once, whether or not the player already said.
    Timer {
        id: reask

        interval: 250
        onTriggered: root.active?.positionChanged()
    }

    // m:ss. Zero is a real answer here, the start of a track, and only a
    // number that is not a time at all gets nothing.
    function timeLabel(seconds: real): string {
        if (!isFinite(seconds) || seconds < 0)
            return "";
        const total = Math.floor(seconds);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return `${m}:${s.toString().padStart(2, "0")}`;
    }

    // Position does not push updates, so it has to be asked. Only while
    // something is actually playing: a paused track's position does not move.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.active?.positionChanged()
    }
}
