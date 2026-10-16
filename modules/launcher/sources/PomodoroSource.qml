import QtQuick
import qs.services
import "../../../services/pomodoro.js" as Logic

QtObject {
    id: root

    required property var search

    readonly property var kinds: ["pomodoro", "pomodorostart"]

    readonly property var ask: Logic.pomodoroAsk(root.search.text)

    readonly property bool intent: !!root.ask

    readonly property var settings: Pomodoro.settings

    readonly property var runningRow: {
        if (!Pomodoro.active)
            return null;
        const left = `${Pomodoro.minutesLeft} min left`;
        return {
            key: "pomodoro:running",
            kind: "pomodoro",
            label: Pomodoro.label,
            detail: Pomodoro.paused ? `paused · ${left}` : left,
            icon: Pomodoro.paused ? "pause_circle" : "timer",
            score: Infinity
        };
    }

    function startRow(ask: var): var {
        const breakMinutes = ask.breakMinutes || root.settings.breakMinutes;
        if (ask.phase === "pomodoro") {
            const focus = ask.minutes || root.settings.focus;
            return {
                key: `pomodorostart:pomodoro:${focus}:${breakMinutes}`,
                kind: "pomodorostart",
                ask: ask,
                label: Pomodoro.active ? "Start the pomodoro over" : "Start a pomodoro",
                detail: `${focus} min focus · ${breakMinutes} min break`,
                icon: "timer_play",
                score: Infinity
            };
        }
        const minutes = ask.minutes || (ask.phase === "focus" ? root.settings.focus : ask.long ? root.settings.longBreak : root.settings.breakMinutes);
        const what = ask.phase === "focus" ? "Focus" : ask.long ? "Long break" : "Break";
        return {
            key: `pomodorostart:${ask.long ? "long" : ask.phase}:${minutes}:0`,
            kind: "pomodorostart",
            ask: ask,
            label: `${what} for ${minutes} min`,
            detail: `until ${TimeFormat.time(new Date(Date.now() + minutes * 60000), false)}`,
            icon: ask.phase === "focus" ? "timer_play" : "coffee",
            score: Infinity
        };
    }

    readonly property var rows: {
        const ask = root.ask;
        if (!ask)
            return [];
        const running = root.runningRow ? [root.runningRow] : [];
        if (ask.phase !== "pomodoro")
            return [root.startRow(ask)].concat(running);
        return !Pomodoro.active || ask.minutes ? running.concat([root.startRow(ask)]) : running;
    }

    readonly property var groups: [
        {
            key: "pomodoro",
            title: "Pomodoro",
            items: root.rows
        }
    ]

    readonly property var phrases: [
        {
            head: "pomodoro ",
            picks: ["25 5", "50 10"]
        },
        {
            head: "break ",
            picks: ["5", "10", "15"]
        }
    ]

    function activate(row: var): void {
        if (row.kind === "pomodoro") {
            Pomodoro.pause();
            return;
        }
        const ask = row.ask;
        root.search.leave(() => Pomodoro.start(ask));
    }

    function actionsFor(row: var): var {
        if (row.kind === "pomodorostart")
            return [
                {
                    icon: row.icon,
                    label: "Start",
                    run: () => root.activate(row)
                }
            ];
        return [
            {
                icon: Pomodoro.paused ? "play_arrow" : "pause",
                label: Pomodoro.paused ? "Resume" : "Pause",
                button: true,
                run: () => Pomodoro.pause()
            },
            {
                icon: "skip_next",
                label: "Skip",
                run: () => Pomodoro.skip()
            },
            {
                icon: "stop",
                label: "Stop",
                run: () => Pomodoro.stop()
            }
        ];
    }
}
