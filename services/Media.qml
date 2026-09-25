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

    // THE CLOCK IS OURS. The player's own position is adopted exactly once
    // per track and never argued with afterwards: bridges answer a seek with
    // stale numbers and drop durations mid-flight, and a bar wired straight
    // to those answers thrashes - pip sliding home and out, end time
    // blinking, on every press of an arrow. So the shell keeps the clock
    // itself: it advances while playing, jumps when a seek is asked (the
    // player is expected to accept the input, and does), and the player's
    // word is taken again only when the track changes.
    property real localPosition: 0

    function adopt(): void {
        root.localPosition = root.active?.position ?? 0;
        root.adoptLength();
    }

    // Adoption asks the player first - position is fetched, not guessed -
    // and takes the answer when it arrives, exactly once. At boot the last
    // fetched value is fresh enough.
    property bool adoptNext: false

    onTrackKeyChanged: {
        root.adoptNext = true;
        root.freshTrack = true;
        freshWindow.restart();
        root.active?.positionChanged();
    }

    Component.onCompleted: root.adopt()

    // What the shell believes the place in the track to be.
    readonly property real position: root.localPosition
    readonly property real playerPosition: active?.position ?? 0

    onPlayerPositionChanged: {
        if (root.adoptNext) {
            root.adoptNext = false;
            root.adopt();
        }
    }

    // LENGTH, ADOPTED LIKE THE CLOCK. Measured on the live bus: the bridge
    // tells the true duration while paused, says nothing while playing, and
    // answers a seek with a wrong number while it buffers - a pause the
    // shell cannot tell from a hand's, which is why every reactive length
    // eventually believed garbage. So the length is never streamed in: it
    // is adopted at boot, at a track change, and when playing stops more
    // than a breath after the last seek - the breath is the buffer's
    // signature; a hand's pause comes later, or not after a seek at all.
    property real heldLength: 0
    property real lastSeekAt: 0

    function adoptLength(): void {
        const reported = root.active?.length ?? 0;
        // A real track is not shorter than five seconds; anything that small
        // is the bridge's buffering noise, not a duration.
        if (reported > 5)
            root.heldLength = reported;
    }

    readonly property real length: root.heldLength

    onPlayingChanged: {
        if (!root.playing && Date.now() - root.lastSeekAt > 2000)
            root.adoptLength();
    }
    // A length of zero is not "at the start": several bridges report no
    // duration until the player tells them, and live streams never do. The
    // division is guarded, because position over zero would otherwise come
    // back infinity and the clamp would call that "the end".
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
        root.lastSeekAt = Date.now();
        root.localPosition = root.length > 0 ? Math.max(0, Math.min(root.length, seconds)) : seconds;
        active.position = seconds;
    }

    // Move by an amount, in seconds, signed.
    function seekBy(offset: real): void {
        if (!active?.canSeek)
            return;
        root.lastSeekAt = Date.now();
        root.localPosition = root.length > 0 ? Math.max(0, Math.min(root.length, root.localPosition + offset)) : Math.max(0, root.localPosition + offset);
        active.seek(offset);
    }

    // A seek is a REQUEST - sent, not confirmed. The clock above jumped the
    // moment it was asked; the player catching up is its own business.

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

    // The local clock, one second to the second while something plays. It
    // holds at the end of a timed track, and runs free past any known end
    // for a live one.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: {
            if (root.length > 0)
                root.localPosition = Math.min(root.length, root.localPosition + 1);
            else
                root.localPosition = root.localPosition + 1;
        }
    }
}
