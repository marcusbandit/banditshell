import QtQuick
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/obs.js" as Durations

QtObject {
    id: root

    required property var search

    readonly property string text: root.search.text
    readonly property var kinds: ["runningtimer"]
    readonly property var asked: /^(?:timers?|running timers?|my timers?|countdowns?)$/i

    readonly property var running: Clock.timers.filter(t => !t.finished && !t.quiet)

    readonly property bool intent: root.running.length > 0 && root.asked.test(root.text)

    readonly property real score: {
        if (!root.running.length || root.text.length < 3)
            return 0;
        if (root.asked.test(root.text))
            return Infinity;
        return Math.max(Ranking.place("timers", root.text), Ranking.place("countdown", root.text)) - 1;
    }

    function timerRow(timer: var, at: double): var {
        return {
            key: `runningtimer:${timer.id}`,
            kind: "runningtimer",
            timerId: timer.id,
            label: timer.label || `${Clock.spanLabel(timer.total)} timer`,
            detail: "",
            columns: [
                {
                    text: Durations.duration(Clock.remainingOf(timer, at)),
                    chars: 7,
                    tone: timer.paused ? "dim" : "lit"
                },
                {
                    text: timer.paused ? "paused" : `ends ${TimeFormat.time(new Date(timer.deadline), false)}`,
                    chars: 11,
                    tone: timer.paused ? "dim" : ""
                }
            ],
            icon: timer.paused ? "timer_pause" : "timer",
            score: root.score
        };
    }

    readonly property var groups: [
        {
            key: "timers",
            title: "Timers",
            items: root.score > 0 ? root.running.map(t => root.timerRow(t, Math.max(Clock.tick, Date.now() - Clock.tickMs))) : []
        }
    ]

    function activate(row: var): void {
        Clock.toggleTimer(row.timerId);
    }

    function actionsFor(row: var): var {
        const timer = Clock.timers.find(t => t.id === row.timerId);
        return [
            {
                icon: timer?.paused ? "play_arrow" : "pause",
                label: timer?.paused ? "Resume" : "Pause",
                run: () => Clock.toggleTimer(row.timerId)
            },
            {
                icon: "close",
                label: "Cancel",
                run: () => Clock.removeTimer(row.timerId)
            }
        ];
    }
}
