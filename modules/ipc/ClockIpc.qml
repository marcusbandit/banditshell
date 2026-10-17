pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import qs.services
import "../cli.js" as Words

Scope {
    id: root

    readonly property string clockUnread: "the clock has not read its state file yet; ask again in a moment"

    function withClock(answer: var): string {
        return Clock.loaded ? answer() : root.clockUnread;
    }

    function pickTimer(handle: string, matches: var): var {
        const want = String(handle ?? "").trim();
        if (want)
            return (/^\d+$/.test(want) ? Clock.timers[Number(want) - 1] : Clock.timers.find(t => t.id === want)) ?? null;
        const at = Date.now();
        return Clock.timers.filter(matches).sort((a, b) => Clock.remainingOf(a, at) - Clock.remainingOf(b, at))[0] ?? null;
    }

    function pickAlarm(handle: string): var {
        const want = String(handle ?? "").trim();
        if (!want)
            return null;
        return (/^\d+$/.test(want) ? Clock.alarms[Number(want) - 1] : Clock.alarms.find(a => a.id === want)) ?? null;
    }

    function timerFields(timer: var, index: int, at: double): var {
        return [`${index}`, Clock.spanLabel(Clock.remainingOf(timer, at)), timer.finished ? "done" : timer.paused ? "paused" : "running", timer.label || "-", `(${timer.id})`];
    }

    function alarmFields(alarm: var, index: int, at: double): var {
        const next = Clock.nextFor(alarm, at);
        const state = Clock.ringing && Clock.ringing.id === alarm.id ? "ringing" : alarm.missed ? "missed" : alarm.armed ? "armed" : "off";

        const when = alarm.snoozedUntil > at ? `snoozed, in ${Clock.spanLabel(next - at)}` : next > 0 ? `in ${Clock.spanLabel(next - at)}` : "-";
        const action = alarm.mode === "command" ? `run: ${alarm.payload}` : alarm.mode === "cloud" ? `ask: ${alarm.payload}` : "-";
        return [`${index}`, Words.hhmm(alarm.hour, alarm.minute), Words.dayWords(alarm.days), state, when, alarm.label || "-", action, `(${alarm.id})`];
    }

    function armAlarm(handle: string, on: bool): string {
        return root.withClock(() => {
            const alarm = root.pickAlarm(handle);
            if (!alarm)
                return handle ? `no such alarm: ${handle}` : "which alarm? (banditshell clock alarm list)";
            Clock.setAlarmArmed(alarm.id, on);
            return Words.columns([root.alarmFields(alarm, Clock.alarms.indexOf(alarm) + 1, Date.now())]);
        });
    }

    IpcHandler {
        target: "timer"

        function start(spec: string, label: string): string {
            return root.withClock(() => {
                const secs = Words.duration(spec);
                if (secs <= 0)
                    return `not a duration: "${spec}" (10m, 90s, 1h30m, 2h, or a bare number of minutes)`;
                const id = Clock.startTimer(secs, label ?? "");

                if (!id)
                    return `no room: ${Clock.timerMax} timers at a time and all of them are running`;
                const timer = Clock.timers.find(t => t.id === id);
                return Words.columns([root.timerFields(timer, Clock.timers.indexOf(timer) + 1, Date.now())]);
            });
        }

        function pause(handle: string): string {
            return root.withClock(() => {
                const timer = root.pickTimer(handle, t => !t.finished && !t.paused);
                if (!timer)
                    return handle ? `no such timer: ${handle}` : "nothing is counting";
                if (timer.finished)
                    return `that one has already gone off (${timer.id})`;
                if (timer.paused)
                    return `already paused, ${Clock.spanLabel(timer.left)} left (${timer.id})`;
                Clock.toggleTimer(timer.id);
                return `paused, ${Clock.spanLabel(timer.left)} left (${timer.id})`;
            });
        }

        function resume(handle: string): string {
            return root.withClock(() => {
                const timer = root.pickTimer(handle, t => t.paused && !t.finished);
                if (!timer)
                    return handle ? `no such timer: ${handle}` : "nothing is paused";
                if (timer.finished)
                    return `that one has already gone off (${timer.id})`;
                if (!timer.paused)
                    return `already running, ${Clock.spanLabel(Clock.remainingOf(timer, Date.now()))} left (${timer.id})`;
                Clock.toggleTimer(timer.id);
                return `running, ${Clock.spanLabel(Clock.remainingOf(timer, Date.now()))} left (${timer.id})`;
            });
        }

        function toggle(handle: string): string {
            return root.withClock(() => {
                const timer = root.pickTimer(handle, t => !t.finished);
                if (!timer)
                    return handle ? `no such timer: ${handle}` : "no timer to pause";
                if (timer.finished)
                    return `that one has already gone off (${timer.id})`;
                return timer.paused ? resume(timer.id) : pause(timer.id);
            });
        }

        function cancel(handle: string): string {
            return root.withClock(() => {
                const timer = root.pickTimer(handle, t => t.finished) ?? root.pickTimer(handle, t => true);
                if (!timer)
                    return handle ? `no such timer: ${handle}` : "no timers";
                Clock.removeTimer(timer.id);
                return `cancelled ${timer.label || Clock.spanLabel(timer.total)} (${timer.id})`;
            });
        }

        function status(): string {
            return root.withClock(() => {
                if (Clock.timers.length === 0)
                    return `no timers (${Clock.timerMax} at a time)`;
                const at = Date.now();
                return Words.columns(Clock.timers.map((timer, i) => root.timerFields(timer, i + 1, at)));
            });
        }
    }

    IpcHandler {
        target: "alarm"

        function add(time: string, days: string, label: string, mode: string, payload: string): string {
            return root.withClock(() => {
                const minutes = Words.timeOfDay(time);
                if (minutes < 0)
                    return `not a time: "${time}" (07:00, 7:30pm, 0700, or a bare hour)`;
                const repeat = Words.repeatDays(days);
                if (repeat === null)
                    return `not a repeat: "${days}" (mon,wed / mon-fri / weekdays / weekends / daily / once)`;
                const action = mode || "none";
                if (!["none", "command", "cloud"].includes(action))
                    return `not an action: "${mode}" (command or cloud)`;

                if (action !== "none" && !payload)
                    return `${action} needs something to ${action === "command" ? "run" : "say"}`;
                const id = Clock.addAlarm();
                if (!id)
                    return `no room: ${Clock.alarmMax} alarms is the lot`;

                Clock.setAlarm(id, {
                    hour: Math.floor(minutes / 60),
                    minute: minutes % 60,
                    days: repeat,
                    label: label ?? "",
                    mode: action,
                    payload: payload ?? ""
                });
                const alarm = Clock.alarms.find(a => a.id === id);
                return Words.columns([root.alarmFields(alarm, Clock.alarms.indexOf(alarm) + 1, Date.now())]);
            });
        }

        function list(): string {
            return root.withClock(() => {
                if (Clock.alarms.length === 0)
                    return `no alarms (${Clock.alarmMax} is the lot)`;
                const at = Date.now();
                return Words.columns(Clock.alarms.map((alarm, i) => root.alarmFields(alarm, i + 1, at)));
            });
        }

        function remove(handle: string): string {
            return root.withClock(() => {
                const alarm = root.pickAlarm(handle);
                if (!alarm)
                    return handle ? `no such alarm: ${handle}` : "which alarm? (banditshell clock alarm list)";
                Clock.removeAlarm(alarm.id);
                return `removed ${Words.hhmm(alarm.hour, alarm.minute)}${alarm.label ? ` ${alarm.label}` : ""} (${alarm.id})`;
            });
        }

        function enable(handle: string): string {
            return root.armAlarm(handle, true);
        }

        function disable(handle: string): string {
            return root.armAlarm(handle, false);
        }

        function snooze(): string {
            if (!Clock.ringing)
                return "nothing is ringing";
            const alarm = Clock.ringing;
            Clock.snooze();
            return `snoozed ${Words.hhmm(alarm.hour, alarm.minute)} for ${Clock.snoozeMinutes}m (${alarm.id})`;
        }

        function stop(): string {
            if (!Clock.ringing)
                return "nothing is ringing";
            const alarm = Clock.ringing;
            Clock.stop();

            return `stopped ${Words.hhmm(alarm.hour, alarm.minute)}, ${alarm.days.length === 0 ? "disarmed" : `next ${Words.dayWords(alarm.days)}`} (${alarm.id})`;
        }

        function status(): string {
            return root.withClock(() => {
                const at = Date.now();
                const armed = Clock.alarms.filter(a => a.armed);
                let soonest = null;
                for (const alarm of armed) {
                    const when = Clock.nextFor(alarm, at);
                    if (when > 0 && (!soonest || when < soonest.when))
                        soonest = {
                            alarm,
                            when
                        };
                }

                const ring = Clock.ringing;
                const next = soonest ? `${Words.hhmm(soonest.alarm.hour, soonest.alarm.minute)} ${Words.dayWords(soonest.alarm.days)}, ${soonest.alarm.snoozedUntil > at ? "snoozed, " : ""}in ${Clock.spanLabel(soonest.when - at)}` : "-";
                return [`alarms     ${Clock.alarms.length} of ${Clock.alarmMax}`, `armed      ${armed.length}`, `next       ${next}`, `ringing    ${ring ? `${Words.hhmm(ring.hour, ring.minute)}${ring.label ? ` ${ring.label}` : ""}, ${Clock.spanLabel(at - Clock.ringingSince)} so far${Clock.ringingLate > 60000 ? `, late by ${Clock.spanLabel(Clock.ringingLate)}` : ""}` : "none"}`, `policy     snooze ${Clock.snoozeMinutes}m, gives up after ${Clock.ringMinutes}m, catches up within ${Clock.catchUpMinutes}m`].join("\n");
            });
        }
    }

    IpcHandler {
        target: "zone"

        function list(): string {
            return root.withClock(() => {
                const at = Date.now();
                const rows = [[Clock.localCity || "-", Clock.zoneTime(Clock.localOffset, at).text, "here", `(${Clock.localZone || "unknown"})`]];
                for (const zone of Clock.zones) {
                    const there = Clock.zoneTime(zone.offsetMinutes, at);
                    const day = there.dayDelta === 0 ? "" : there.dayDelta < 0 ? " yesterday" : " tomorrow";
                    rows.push([zone.city, there.text, `${Clock.offsetLabel(zone.deltaMinutes)}${day}`, `(${zone.id})`]);
                }

                const pending = Clock.places.filter(id => !Clock.zones.some(z => z.id === id));
                const table = rows.length > 1 ? Words.columns(rows) : `${Words.columns(rows)}\nno places yet (banditshell clock zone add <place>)`;
                return pending.length > 0 ? `${table}\nmeasuring ${pending.join(", ")}` : table;
            });
        }

        function find(text: string): string {
            const want = String(text ?? "").trim();
            if (!want)
                return "which place? (banditshell clock zone find <text>)";
            if (Clock.allZones.length === 0) {
                Clock.loadZoneList();
                return "reading this machine's zone list; ask again in a moment";
            }
            const near = Words.zoneMatches(want, Clock.allZones);
            return near.length > 0 ? near.join("\n") : `nothing here is called that: ${want}`;
        }

        function add(place: string): string {
            return root.withClock(() => {
                const want = String(place ?? "").trim();
                if (!want)
                    return "which place? (banditshell clock zone find <text>)";
                if (Clock.allZones.length === 0) {
                    Clock.loadZoneList();
                    return "reading this machine's zone list; ask again in a moment";
                }
                const near = Words.zoneMatches(want, Clock.allZones);
                if (near.length === 0)
                    return `no such place: ${want} (banditshell clock zone find ${want})`;
                if (near.length > 1)
                    return `${want} could be any of ${near.length} (banditshell clock zone find ${want})`;
                const id = near[0];

                if (id === Clock.localZone)
                    return `${Clock.cityOf(id)} is this machine's own zone, which the panel draws already`;
                if (Clock.places.includes(id))
                    return `already on the list: ${id}`;
                Clock.addZone(id);
                return `added ${Clock.cityOf(id)} (${id})`;
            });
        }

        function remove(place: string): string {
            return root.withClock(() => {
                const want = Words.zoneKey(place);
                if (!want)
                    return "which place? (banditshell clock zone list)";
                const hits = Clock.places.filter(id => Words.zoneKey(id) === want || Words.zoneKey(Clock.cityOf(id)) === want);
                if (hits.length === 0)
                    return `not on the list: ${place} (banditshell clock zone list)`;
                if (hits.length > 1)
                    return `${place} is ${hits.length} of them; name the id (banditshell clock zone list)`;
                Clock.removeZone(hits[0]);
                return `removed ${Clock.cityOf(hits[0])} (${hits[0]})`;
            });
        }
    }
}
