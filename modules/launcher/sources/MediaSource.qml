import QtQuick
import qs.services
import "../../../services/ranking.js" as Ranking

QtObject {
    id: root

    required property var search

    readonly property string text: root.search.text
    readonly property var kinds: ["nowplaying"]
    readonly property var asked: /^(?:now playing|playing|music|song|track|media|player|what'?s playing)$/i

    readonly property real score: {
        if (!Media.hasTrack || root.text.length < 3)
            return 0;
        if (root.asked.test(root.text))
            return Infinity;
        return Math.max(Ranking.place("now playing", root.text), Ranking.place("music song track media player playing", root.text) - 0.5, Ranking.place(Media.title, root.text), Ranking.place(Media.artist, root.text) - 0.25, Ranking.place(Media.app, root.text) - 0.5);
    }

    readonly property var groups: [
        {
            key: "media",
            title: "Playing",
            items: root.score > 0 ? [
                {
                    key: `nowplaying:${Media.trackKey}:${Media.title}`,
                    kind: "nowplaying",
                    label: Media.title,
                    detail: Media.artist || Media.app,
                    iconSource: Media.artUrl,
                    icon: "music_note",
                    slider: Media.canSeek && Media.length > 0 ? {
                        value: () => Media.position,
                        set: v => Media.seekTo(v),
                        to: Media.length,
                        warnAbove: Media.length,
                        step: 5,
                        text: () => Media.timeLabel(Media.position)
                    } : undefined,
                    score: root.score
                }
            ] : []
        }
    ]

    function activate(row: var): void {
        Media.toggle();
    }

    function actionsFor(row: var): var {
        return [
            {
                icon: Media.playing ? "pause" : "play_arrow",
                label: Media.playing ? "Pause" : "Play",
                run: () => Media.toggle()
            },
            {
                icon: "skip_previous",
                label: "Previous",
                short: "",
                run: () => Media.previous()
            },
            {
                icon: "skip_next",
                label: "Next",
                short: "",
                run: () => Media.next()
            }
        ];
    }
}
