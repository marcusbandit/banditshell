pragma Singleton

import QtQuick
import Quickshell
import qs.config
import "activities.js" as Logic

Singleton {
    id: root

    property var entries: []
    property var sounding: []
    property var staged: []
    property double now: Date.now()

    readonly property var timerItems: {
        root.now;
        return Logic.timerItems(Clock.timers, Date.now());
    }

    readonly property var alarmItems: {
        const out = [];
        const ring = Clock.ringing;
        if (ring)
            out.push(Logic.alarmItem(ring.id, Clock.alarmTitle(ring, Clock.ringingSince - Clock.ringingLate), Logic.alarmActions(true)));
        for (const s of root.sounding)
            out.push(Logic.alarmItem(`timer:${s.id}`, s.title, Logic.alarmActions(false)));
        return out;
    }

    readonly property var shown: [...root.staged, ...root.alarmItems, ...root.timerItems, ...Logic.ordered(root.entries).map(Logic.itemOf)]

    function push(spec: var): string {
        const out = Logic.push(root.entries, spec, Date.now());
        if (out.error)
            return out.error;
        root.entries = out.list;
        root.reschedule();
        return "";
    }

    function update(id: string, patch: var): string {
        const out = Logic.update(root.entries, id, patch, Date.now());
        if (out.error)
            return out.error;
        root.entries = out.list;
        root.reschedule();
        return "";
    }

    function end(id: string, outcome: string, lingerMs: var, text: string): string {
        const out = Logic.end(root.entries, id, outcome, Date.now(), lingerMs, text);
        if (out.error)
            return out.error;
        root.entries = out.list;
        root.reschedule();
        return "";
    }

    function remove(id: string): void {
        root.entries = Logic.remove(root.entries, id);
        root.reschedule();
    }

    function lines(): string {
        const at = Date.now();
        return Logic.ordered(root.entries).map(e => Logic.listLine(e, at)).join("\n");
    }

    function activate(item: var): void {
        switch (item?.kind) {
        case "timer":
            Clock.toggleTimer(item.id);
            return;
        case "alarm":
            root.answer(item);
            return;
        case "external":
            root.run(root.entries.find(e => e.id === item.id), item.action ?? "");
            return;
        }
    }

    function run(entry: var, action: string): void {
        if (!entry || entry.state === "ended" || !entry.act)
            return;
        if (typeof entry.act === "function")
            entry.act(entry, action);
        else
            Quickshell.execDetached(["sh", "-c", String(entry.act)]);
    }

    function answer(item: var): void {
        if (item.id.startsWith("timer:")) {
            root.silence(item.id.slice("timer:".length));
            return;
        }
        if (item.action === "snooze")
            Clock.snooze();
        else
            Clock.stop();
    }

    function silence(timerId: string): void {
        root.sounding = root.sounding.filter(s => s.id !== timerId);
    }

    function reschedule(): void {
        const wait = Logic.nextWake(root.entries, Date.now());
        if (wait < 0) {
            wake.stop();
            return;
        }
        wake.interval = wait + 20;
        wake.restart();
    }

    Timer {
        id: wake

        onTriggered: {
            root.entries = Logic.sweep(root.entries, Date.now());
            root.reschedule();
        }
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: Clock.timers.some(t => !t.finished && !t.paused && !t.quiet)

        onTriggered: root.now = Date.now()
    }

    Timer {
        interval: 5000
        repeat: true
        running: root.sounding.length > 0

        onTriggered: {
            const at = Date.now();
            root.sounding = root.sounding.filter(s => s.until > at);
        }
    }

    Connections {
        target: Clock

        function onTimerFinished(timer: var): void {
            if (timer.quiet)
                return;
            root.sounding = [...root.sounding.filter(s => s.id !== timer.id), {
                    id: timer.id,
                    title: timer.label ? `${timer.label} is done` : "Timer done",
                    until: Date.now() + Clock.ringMinutes * 60000
                }];
        }
    }
}
