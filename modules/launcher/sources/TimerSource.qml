import QtQuick
import Quickshell
import qs.services
import "../../../services/ranking.js" as Ranking
import "../../../services/obs.js" as Durations

QtObject {
    id: root

    required property var search

    readonly property string text: root.search.text
    readonly property var kinds: ["runningtimer", "pendingreminder"]
    readonly property var asked: /^(?:timers?|running timers?|my timers?|countdowns?)$/i
    readonly property var askedReminders: /^(?:reminders?|my reminders?|pending reminders?|upcoming reminders?)$/i

    readonly property var pending: Clock.alarms.filter(a => a.armed && a.days.length === 0 && a.at > Date.now()).sort((a, b) => a.at - b.at)
    readonly property bool remindersAsked: root.pending.length > 0 && root.askedReminders.test(root.text)

    readonly property var running: Clock.timers.filter(t => !t.finished && !t.quiet)

    readonly property bool intent: root.running.length > 0 && root.asked.test(root.text) || root.remindersAsked

    readonly property real score: {
        if (!root.running.length || root.text.length < 3)
            return 0;
        if (root.asked.test(root.text))
            return Infinity;
        return Math.max(Ranking.place("timers", root.text), Ranking.place("countdown", root.text)) - 1;
    }

    function timerRow(timer: var, at: double): var {
        const ends = timer.paused ? "paused" : `ends ${TimeFormat.time(new Date(timer.deadline), false)}`;
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
                    text: ends,
                    chars: TimeFormat.clock24 ? 11 : 13,
                    tone: timer.paused ? "dim" : ""
                }
            ],
            icon: timer.paused ? "timer_pause" : "timer",
            score: root.score
        };
    }

    function reminderRow(alarm: var): var {
        const when = new Date(alarm.at);
        return {
            key: `pendingreminder:${alarm.id}`,
            kind: "pendingreminder",
            alarmId: alarm.id,
            label: alarm.label || "Reminder",
            detail: "",
            columns: [
                {
                    text: TimeFormat.clock(when.getHours(), when.getMinutes()),
                    chars: TimeFormat.clock24 ? 5 : 8,
                    tone: "lit"
                },
                {
                    text: TimeFormat.dateText(when, "headline"),
                    chars: 12,
                    tone: "dim"
                }
            ],
            icon: "notifications_active",
            score: Infinity
        };
    }

    readonly property var groups: [
        {
            key: "reminders",
            title: "Reminders",
            items: root.remindersAsked ? root.pending.map(a => root.reminderRow(a)) : []
        },
        {
            key: "timers",
            title: "Timers",
            items: root.score > 0 ? root.running.map(t => root.timerRow(t, Math.max(Clock.tick, Date.now() - Clock.tickMs))) : []
        }
    ]

    function later(row: var, minutes: int): void {
        const alarm = Clock.alarms.find(a => a.id === row.alarmId);
        if (!alarm)
            return;
        const moved = new Date(alarm.at + minutes * 60000);
        Clock.setAlarm(alarm.id, {
            hour: moved.getHours(),
            minute: moved.getMinutes(),
            at: moved.getTime()
        });
        Quickshell.execDetached(["notify-send", "-a", "banditshell", "-i", "update", alarm.label || "Reminder", `Moved to ${TimeFormat.clock(moved.getHours(), moved.getMinutes())}`]);
    }

    function activate(row: var): void {
        if (row.kind === "pendingreminder") {
            root.later(row, 15);
            return;
        }
        Clock.toggleTimer(row.timerId);
    }

    function actionsFor(row: var): var {
        if (row.kind === "pendingreminder")
            return [
                {
                    icon: "update",
                    label: "15 minutes later",
                    run: () => root.later(row, 15)
                },
                {
                    icon: "schedule",
                    label: "An hour later",
                    run: () => root.later(row, 60)
                },
                {
                    icon: "close",
                    label: "Clear",
                    run: () => Clock.removeAlarm(row.alarmId)
                }
            ];
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
