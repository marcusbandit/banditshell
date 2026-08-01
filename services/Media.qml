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

    readonly property string title: active?.trackTitle || "nothing playing"
    readonly property string artist: active?.trackArtist || ""
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

    function previous(): void {
        if (active?.canGoPrevious)
            active.previous();
    }

    function timeLabel(seconds: real): string {
        if (!(seconds > 0))
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
