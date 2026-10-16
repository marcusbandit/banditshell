pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "pomodoro.js" as Logic

Singleton {
    id: root

    readonly property var settings: ({
            focus: Math.max(1, Config.values.launcher.powerTools.focusMinutes),
            breakMinutes: Math.max(1, Config.values.launcher.powerTools.breakMinutes),
            longBreak: Math.max(1, Config.values.launcher.powerTools.longBreakMinutes),
            rounds: Math.max(1, Config.values.launcher.powerTools.roundsBeforeLongBreak)
        })

    readonly property string path: `${Config.stateDir}/pomodoro.json`

    property var state: null
    property bool loaded: false

    readonly property var timer: root.state ? Clock.timers.find(t => t.id === root.state.timer) ?? null : null
    readonly property bool active: !!root.timer && !root.timer.finished
    readonly property bool paused: root.active && !!root.timer.paused
    readonly property int minutesLeft: root.active ? Math.max(1, Math.ceil(Clock.remainingOf(root.timer, Math.max(Clock.tick, root.startedAt) || Date.now()) / 60000)) : 0
    readonly property string label: root.active ? Logic.roundLabel(root.state, root.settings) : ""

    property double startedAt: 0

    property bool notifier: false

    Process {
        running: true
        command: ["sh", "-c", "command -v notify-send"]
        onExited: code => root.notifier = code === 0
    }

    function begin(phase: string, minutes: int, round: int, focusMinutes: int, breakMinutes: int): void {
        const next = {
            timer: "",
            phase: phase,
            round: Math.max(0, round),
            focusMinutes: focusMinutes,
            breakMinutes: breakMinutes
        };
        const length = Math.max(1, minutes);
        root.startedAt = Date.now();
        const id = Clock.startQuietTimer(length * 60, Logic.roundLabel(next, root.settings));
        if (!id)
            return;
        const old = root.state?.timer ?? "";
        next.timer = id;
        root.keep(next);
        if (old && old !== id)
            Clock.removeTimer(old);
    }

    function start(ask: var): void {
        if (ask.phase === "break") {
            const long = !!ask.long;
            root.begin(long ? "long" : "break", ask.minutes || (long ? root.settings.longBreak : root.settings.breakMinutes), root.state?.round ?? 0, root.state?.focusMinutes ?? 0, root.state?.breakMinutes ?? 0);
            return;
        }
        root.begin("focus", ask.minutes || root.settings.focus, 1, ask.minutes, ask.breakMinutes);
    }

    function pause(): void {
        if (root.active)
            Clock.toggleTimer(root.state.timer);
    }

    function skip(): void {
        if (!root.state)
            return;
        const next = Logic.nextRound(root.state, root.settings);
        root.begin(next.phase, next.minutes, next.round, root.state.focusMinutes, root.state.breakMinutes);
    }

    function stop(): void {
        const id = root.state?.timer ?? "";
        root.keep(null);
        if (id)
            Clock.removeTimer(id);
    }

    function keep(next: var): void {
        root.state = next;
        if (root.loaded)
            store.setText(JSON.stringify(next ?? {}, null, 4) + "\n");
    }

    function reconcile(): void {
        if (root.loaded && Clock.loaded && root.state && !root.timer)
            root.keep(null);
    }

    Connections {
        target: Clock

        function onTimerFinished(timer: var): void {
            if (!root.state || timer.id !== root.state.timer)
                return;
            const finished = root.state;
            const next = Logic.nextRound(finished, root.settings);
            const said = Logic.notice(finished, next);
            if (root.notifier)
                Quickshell.execDetached(["notify-send", "-a", "banditshell", "-u", "normal", "-c", Notifications.categoryFor("alarm"), said.summary, said.body]);
            root.begin(next.phase, next.minutes, next.round, finished.focusMinutes, finished.breakMinutes);
        }

        function onLoadedChanged(): void {
            root.reconcile();
        }

        function onTimersChanged(): void {
            root.reconcile();
        }
    }

    FileView {
        id: store

        path: root.path
        printErrors: false
        onLoaded: {
            root.state = Logic.readState(store.text());
            root.loaded = true;
            root.reconcile();
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }
}
