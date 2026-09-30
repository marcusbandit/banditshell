pragma Singleton

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    function token(name: string, fallback: var): var {
        const block = Config.values.clock;
        const value = block ? block[name] : undefined;
        return value === undefined ? fallback : value;
    }

    readonly property int snoozeMinutes: root.token("snoozeMinutes", 9)

    readonly property int ringMinutes: root.token("ringMinutes", 15)

    readonly property int catchUpMinutes: root.token("catchUpMinutes", 60)

    readonly property int timerMax: root.token("timerMax", 3)
    readonly property int alarmMax: root.token("alarmMax", 8)

    readonly property var cloud: {
        const set = root.token("cloud", []);
        return Array.isArray(set) && set.length > 0 ? set : ["claude", "-p"];
    }

    readonly property int cloudSeconds: root.token("cloudSeconds", 120)
    readonly property int cloudReplyChars: root.token("cloudReplyChars", 240)

    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/clock.json`

    property bool loaded: false

    property bool keep: true

    property var places: []

    property var allZones: []

    property string localZone: ""
    readonly property string localCity: root.cityOf(root.localZone)
    property int localOffset: 0

    property var zones: []

    property var offsetMap: ({})

    function validZone(id: string): bool {
        return typeof id === "string" && /^[A-Za-z][A-Za-z0-9_+.-]*(\/[A-Za-z0-9_+.-]+)*$/.test(id) && id.length < 64;
    }

    function cityOf(id: string): string {
        if (!id)
            return "";
        return id.slice(id.lastIndexOf("/") + 1).replace(/_/g, " ");
    }

    function addZone(id: string): void {
        if (!root.validZone(id) || root.places.includes(id))
            return;

        if (id === root.localZone)
            return;
        root.places = [...root.places, id];
        root.save();
        root.refreshOffsets();
    }

    function removeZone(id: string): void {
        if (!root.places.includes(id))
            return;
        root.places = root.places.filter(z => z !== id);
        root.rebuildZones();
        root.save();
    }

    function loadZoneList(): void {
        if (root.allZones.length > 0 || zoneList.running)
            return;
        zoneList.running = true;
    }

    function zoneTime(offsetMinutes: int, at: double): var {
        const there = new Date(at + offsetMinutes * 60000);
        const here = new Date(at + root.localOffset * 60000);
        const hour = there.getUTCHours();
        const minute = there.getUTCMinutes();
        return {
            hour,
            minute,

            hourOfDay: hour + minute / 60,

            dayDelta: root.dayNumber(there) - root.dayNumber(here),
            text: `${root.pad2(hour)}:${root.pad2(minute)}`
        };
    }

    function dayNumber(d: date): int {
        return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 86400000);
    }

    function pad2(n: int): string {
        return n < 10 ? `0${n}` : `${n}`;
    }

    function offsetLabel(deltaMinutes: int): string {
        const sign = deltaMinutes < 0 ? "-" : "+";
        const abs = Math.abs(deltaMinutes);
        const h = Math.floor(abs / 60);
        const m = abs % 60;
        return m === 0 ? `${sign}${h}h` : `${sign}${h}h${root.pad2(m)}`;
    }

    property int watchers: 0

    function watch(on: bool): void {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));

        if (on)
            root.rebuildZones();
    }

    SystemClock {
        id: minuteClock

        precision: SystemClock.Minutes
        enabled: root.watchers > 0
        onDateChanged: root.rebuildZones()
    }

    property var timers: []

    property double tick: 0

    function remainingOf(timer: var, at: double): double {
        if (!timer)
            return 0;
        return timer.paused ? timer.left : Math.max(0, timer.deadline - at);
    }

    function startTimer(seconds: int, label: string): string {
        if (seconds <= 0)
            return "";
        let next = root.timers.slice();
        while (next.length >= root.timerMax) {
            const spent = next.findIndex(t => t.finished);
            if (spent < 0)
                return "";
            next.splice(spent, 1);
        }
        const now = Date.now();
        const total = seconds * 1000;
        const timer = {
            id: root.newId(),
            total,
            deadline: now + total,
            left: 0,
            paused: false,
            finished: false,
            label: label ?? ""
        };
        next.push(timer);
        root.timers = next;
        root.save();
        return timer.id;
    }

    function toggleTimer(id: string): void {
        const timer = root.timers.find(t => t.id === id);
        if (!timer || timer.finished)
            return;
        const now = Date.now();
        if (timer.paused) {
            timer.deadline = now + timer.left;
            timer.left = 0;
            timer.paused = false;
        } else {
            timer.left = Math.max(0, timer.deadline - now);
            timer.paused = true;
        }

        root.timers = root.timers.slice();
        root.save();
    }

    function removeTimer(id: string): void {
        if (!root.timers.some(t => t.id === id))
            return;
        root.timers = root.timers.filter(t => t.id !== id);
        root.save();
    }

    property var alarms: []

    property var ringing: null

    property double ringingSince: 0
    property double ringingLate: 0

    signal fired(alarm: var)
    signal missed(alarm: var)
    signal actionFailed(alarm: var, code: int, output: string)
    signal timerFinished(timer: var)

    function weekdayOf(d: date): int {
        return (d.getDay() + 6) % 7;
    }

    function occurrence(from: date, offset: int, hour: int, minute: int): double {
        return new Date(from.getFullYear(), from.getMonth(), from.getDate() + offset, hour, minute, 0, 0).getTime();
    }

    function nextClockTime(hour: int, minute: int, at: double): double {
        const from = new Date(at);
        const today = root.occurrence(from, 0, hour, minute);
        return today > at ? today : root.occurrence(from, 1, hour, minute);
    }

    function nextFor(alarm: var, at: double): double {
        if (!alarm || !alarm.armed)
            return 0;
        if (alarm.snoozedUntil > at)
            return alarm.snoozedUntil;
        if (alarm.days.length === 0)
            return alarm.at > at ? alarm.at : 0;
        const from = new Date(at);
        for (let i = 0; i <= 7; i++) {
            const when = root.occurrence(from, i, alarm.hour, alarm.minute);
            if (when > at && alarm.days.includes(root.weekdayOf(new Date(when))))
                return when;
        }
        return 0;
    }

    function lastFor(alarm: var, at: double): double {
        if (alarm.days.length === 0)
            return alarm.at <= at ? alarm.at : 0;
        const from = new Date(at);
        for (let i = 0; i <= 7; i++) {
            const when = root.occurrence(from, -i, alarm.hour, alarm.minute);
            if (when <= at && alarm.days.includes(root.weekdayOf(new Date(when))))
                return when;
        }
        return 0;
    }

    function pendingFor(alarm: var, at: double): double {
        if (!alarm.armed)
            return 0;

        if (alarm.snoozedUntil > 0) {
            if (alarm.snoozedUntil > at)
                return 0;
            return alarm.snoozedUntil > alarm.handledUntil ? alarm.snoozedUntil : 0;
        }
        const due = root.lastFor(alarm, at);
        return due > alarm.handledUntil && due <= at ? due : 0;
    }

    function addAlarm(): string {
        if (root.alarms.length >= root.alarmMax)
            return "";
        const now = new Date();
        const at = root.occurrence(now, 0, now.getHours() + 1, 0);
        const alarm = {
            id: root.newId(),
            hour: new Date(at).getHours(),
            minute: 0,
            days: [],
            armed: true,
            label: "",
            mode: "none",
            payload: "",
            at,
            handledUntil: Date.now(),
            snoozedUntil: 0,
            missed: false
        };
        root.alarms = [...root.alarms, alarm];
        root.save();
        return alarm.id;
    }

    function setAlarm(id: string, fields: var): void {
        const alarm = root.alarms.find(a => a.id === id);
        if (!alarm)
            return;
        if (fields.hour !== undefined)
            alarm.hour = Math.max(0, Math.min(23, Math.round(fields.hour)));
        if (fields.minute !== undefined)
            alarm.minute = Math.max(0, Math.min(59, Math.round(fields.minute)));
        if (fields.days !== undefined)
            alarm.days = (fields.days ?? []).filter(d => d >= 0 && d <= 6).sort((a, b) => a - b);
        if (fields.label !== undefined)
            alarm.label = String(fields.label);
        if (fields.mode !== undefined)
            alarm.mode = ["none", "command", "cloud"].includes(fields.mode) ? fields.mode : "none";
        if (fields.payload !== undefined)
            alarm.payload = String(fields.payload);
        if (fields.armed !== undefined)
            alarm.armed = !!fields.armed;
        root.reschedule(alarm);
        root.alarms = root.alarms.slice();
        root.save();
    }

    function reschedule(alarm: var): void {
        const now = Date.now();
        alarm.handledUntil = now;
        alarm.snoozedUntil = 0;
        alarm.missed = false;
        if (alarm.days.length === 0)
            alarm.at = root.nextClockTime(alarm.hour, alarm.minute, now);

        if (root.ringing && root.ringing.id === alarm.id)
            root.clearRinging();
    }

    function setAlarmArmed(id: string, on: bool): void {
        root.setAlarm(id, {
            armed: on
        });
    }

    function removeAlarm(id: string): void {
        const alarm = root.alarms.find(a => a.id === id);
        if (!alarm)
            return;
        if (root.ringing && root.ringing.id === id)
            root.clearRinging();
        root.alarms = root.alarms.filter(a => a.id !== id);
        root.save();
    }

    function snooze(): void {
        const alarm = root.ringing;
        if (!alarm)
            return;
        alarm.snoozedUntil = Date.now() + root.snoozeMinutes * 60000;
        root.clearRinging();
        root.alarms = root.alarms.slice();
        root.save();
    }

    function stop(): void {
        root.answer(false);
    }

    function answer(unanswered: bool): void {
        const alarm = root.ringing;
        if (!alarm)
            return;
        alarm.snoozedUntil = 0;
        alarm.missed = unanswered;
        if (alarm.days.length === 0)
            alarm.armed = false;
        root.clearRinging();
        root.alarms = root.alarms.slice();
        root.save();
    }

    function clearRinging(): void {
        root.ringing = null;
        root.ringingSince = 0;
        root.ringingLate = 0;
    }

    readonly property int tickMs: 1000

    readonly property real napMs: root.tickMs * 20

    Timer {
        interval: root.tickMs
        repeat: true

        running: root.loaded && (root.ringing !== null || root.alarms.some(a => a.armed) || root.timers.some(t => !t.finished && !t.paused))
        onTriggered: root.beat()
    }

    function beat(): void {
        const now = Date.now();
        const slept = root.tick > 0 && now - root.tick > root.napMs;
        root.tick = now;

        if (slept)
            root.refreshOffsets();

        root.sweepTimers(now);
        root.sweepAlarms(now);
    }

    function sweepTimers(now: double): void {
        let changed = false;
        for (const timer of root.timers) {
            if (timer.finished || timer.paused || timer.deadline > now)
                continue;
            timer.finished = true;
            changed = true;
            root.notify("critical", "Timer done", timer.label ? `${timer.label} · ${root.spanLabel(timer.total)}` : root.spanLabel(timer.total));
            root.timerFinished(timer);
        }
        if (changed) {
            root.timers = root.timers.slice();
            root.save();
        }
    }

    function sweepAlarms(now: double): void {

        if (root.ringing && now - root.ringingSince > root.ringMinutes * 60000)
            root.answer(true);

        if (root.ringing)
            return;

        const catchUpMs = root.catchUpMinutes * 60000;
        let changed = false;
        for (const alarm of root.alarms) {
            const due = root.pendingFor(alarm, now);
            if (due <= 0)
                continue;
            const late = now - due;
            alarm.handledUntil = due;
            changed = true;

            if (late > catchUpMs) {

                alarm.missed = true;
                alarm.snoozedUntil = 0;
                if (alarm.days.length === 0)
                    alarm.armed = false;
                root.notify("normal", root.alarmTitle(alarm, due), `Missed ${root.spanLabel(late)} ago. This machine cannot wake itself for an alarm.`);
                root.missed(alarm);
                continue;
            }

            alarm.missed = false;
            root.ringing = alarm;
            root.ringingSince = now;
            root.ringingLate = late;
            root.notify("critical", root.alarmTitle(alarm, due), late > 60000 ? `Late by ${root.spanLabel(late)}. This machine cannot wake itself for an alarm.` : "");
            root.run(alarm);
            root.fired(alarm);
            break;
        }
        if (changed) {
            root.alarms = root.alarms.slice();
            root.save();
        }
    }

    function alarmTitle(alarm: var, due: double): string {
        const at = new Date(due);
        const when = `${root.pad2(at.getHours())}:${root.pad2(at.getMinutes())}`;
        return alarm.label ? `${when}  ${alarm.label}` : `Alarm ${when}`;
    }

    function spanLabel(ms: double): string {
        const total = Math.max(0, Math.round(ms / 1000));
        const h = Math.floor(total / 3600);
        const m = Math.floor((total % 3600) / 60);
        const s = total % 60;
        if (h > 0)
            return m > 0 ? `${h}h ${m}m` : `${h}h`;
        if (m > 0)
            return s > 0 ? `${m}m ${s}s` : `${m}m`;
        return `${s}s`;
    }

    property int serial: 0

    function newId(): string {
        root.serial += 1;
        return `${Date.now().toString(36)}-${root.serial.toString(36)}`;
    }

    function run(alarm: var): void {
        if (!alarm.payload)
            return;

        if (alarm.mode === "command") {
            root.spawn(["sh", "-c", alarm.payload], alarm);
            return;
        }

        if (alarm.mode === "cloud") {
            const template = Array.isArray(root.cloud) ? root.cloud : [];
            if (template.length === 0) {

                root.report(alarm, -1, "The clock.cloud template is empty, so there was nothing to send the message to.");
                return;
            }

            root.spawn(["timeout", "-k", "5", `${root.cloudSeconds}`, ...template, alarm.payload], alarm);
        }
    }

    function notify(urgency: string, summary: string, body: string): void {
        root.spawn(["notify-send", "-a", "banditshell", "-u", urgency, summary, body ?? ""], null);
    }

    function report(alarm: var, code: int, output: string): void {
        const detail = (output ?? "").trim().split("\n").filter(l => l.trim()).pop() ?? "";
        root.notify("critical", `${alarm.mode === "cloud" ? "Cloud message" : "Alarm command"} failed`, detail ? `exit ${code} · ${detail}` : `exit ${code}`);
        root.actionFailed(alarm, code, output ?? "");
    }

    function spawn(argv: var, alarm: var): void {
        taskComponent.createObject(root, {
            command: argv,
            alarm,
            running: true
        });
    }

    Component {
        id: taskComponent

        Process {
            id: task

            property var alarm: null
            property string out: ""
            property string err: ""

            stdout: StdioCollector {
                onStreamFinished: task.out = text
            }

            stderr: StdioCollector {
                onStreamFinished: task.err = text
            }

            onExited: (code, status) => {
                if (task.alarm) {
                    if (code !== 0) {
                        root.report(task.alarm, code, task.err || task.out);
                    } else if (task.alarm.mode === "cloud" && task.out.trim()) {

                        const reply = task.out.trim();
                        root.notify("normal", root.alarmTitle(task.alarm, Date.now()), reply.length > root.cloudReplyChars ? `${reply.slice(0, root.cloudReplyChars)}...` : reply);
                    }
                }

                task.destroy();
            }
        }
    }

    Process {
        id: zoneProc

        running: true

        command: ["sh", "-c", `z=$(timedatectl show -p Timezone --value 2>/dev/null); [ -n "$z" ] || z=$(readlink -f /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||'); [ -n "$z" ] || z=UTC; printf '%s\\n' "$z"`]

        stdout: StdioCollector {
            onStreamFinished: {
                const id = text.trim();
                root.localZone = root.validZone(id) ? id : "UTC";
                root.refreshOffsets();
            }
        }
    }

    Process {
        id: zoneList

        command: ["sh", "-c", "timedatectl list-timezones 2>/dev/null || (cd /usr/share/zoneinfo 2>/dev/null && find . -type f ! -path './posix/*' ! -path './right/*' ! -name '*.tab' ! -name '*.zi' ! -name '*.list' ! -name 'leapseconds' ! -name 'Factory' ! -name 'localtime' | sed 's|^\\./||' | sort)"]

        stdout: StdioCollector {
            onStreamFinished: {

                root.allZones = text.split("\n").map(l => l.trim()).filter(id => root.validZone(id));
            }
        }
    }

    Process {
        id: offsetProc

        property bool again: false

        stdout: StdioCollector {
            onStreamFinished: root.applyOffsets(text)
        }

        onExited: {
            if (!offsetProc.again)
                return;
            offsetProc.again = false;

            Qt.callLater(root.refreshOffsets);
        }
    }

    function refreshOffsets(): void {

        if (!root.localZone)
            return;
        if (offsetProc.running) {
            offsetProc.again = true;
            return;
        }

        const ids = [root.localZone, ...root.places].filter((id, i, all) => root.validZone(id) && all.indexOf(id) === i);
        const list = ids.map(id => `'${id}'`).join(" ");

        offsetProc.command = ["sh", "-c", `for z in ${list}; do printf '%s %s\\n' "$z" "$(TZ="$z" date +%z)"; done`];
        offsetProc.running = true;
    }

    function applyOffsets(text: string): void {
        const map = {};
        for (const line of text.split("\n")) {
            const m = line.trim().match(/^(\S+)\s+([+-])(\d{2})(\d{2})$/);
            if (!m)
                continue;
            map[m[1]] = (m[2] === "-" ? -1 : 1) * (Number(m[3]) * 60 + Number(m[4]));
        }

        if (map[root.localZone] === undefined)
            return;
        root.localOffset = map[root.localZone];
        root.offsetMap = map;
        root.rebuildZones();
    }

    function rebuildZones(): void {
        const at = Date.now();
        const rows = [];
        for (const id of root.places) {
            const offset = root.offsetMap[id];

            if (offset === undefined)
                continue;
            const t = root.zoneTime(offset, at);
            rows.push({
                id,
                city: root.cityOf(id),
                offsetMinutes: offset,
                deltaMinutes: offset - root.localOffset,
                hour: t.hour,
                minute: t.minute,
                hourOfDay: t.hourOfDay,
                dayDelta: t.dayDelta,
                text: t.text
            });
        }
        rows.sort((a, b) => a.deltaMinutes - b.deltaMinutes || a.city.localeCompare(b.city));
        root.zones = rows;
    }

    Timer {
        id: hourly

        interval: 60000
        repeat: false
        running: true

        function rearm(): void {
            const now = new Date();
            hourly.interval = Math.max(1000, root.occurrence(now, 0, now.getHours() + 1, 0) + 1000 - now.getTime());
            hourly.restart();
        }

        onTriggered: {
            root.refreshOffsets();
            hourly.rearm();
        }

        Component.onCompleted: rearm()
    }

    function save(): void {
        if (!root.loaded || !root.keep)
            return;

        store.setText(JSON.stringify({
            zones: root.places,
            timers: root.timers,
            alarms: root.alarms
        }, null, 4) + "\n");
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            let disk = null;
            try {
                disk = JSON.parse(text());
            } catch (e) {

                console.warn(`Clock: ${root.path} is not valid JSON; running with no alarms and leaving the file alone.`, e);
                root.keep = false;
            }
            root.adopt(disk);
        }

        onLoadFailed: err => {

            if (err === FileViewError.FileNotFound) {
                mkdir.running = true;
            } else {
                console.warn(`Clock: could not read ${root.path} (${err}); alarms set now will not be kept.`);
                root.keep = false;
                root.adopt(null);
            }
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
        onExited: root.adopt(null)
    }

    function adopt(disk: var): void {
        if (root.loaded)
            return;

        const now = Date.now();
        const catchUpMs = root.catchUpMinutes * 60000;

        root.places = (Array.isArray(disk?.zones) ? disk.zones : []).filter(id => root.validZone(id));

        root.alarms = (Array.isArray(disk?.alarms) ? disk.alarms : []).filter(a => a && Number.isFinite(a.hour) && Number.isFinite(a.minute)).slice(0, root.alarmMax).map(a => ({
                    id: typeof a.id === "string" && a.id ? a.id : root.newId(),
                    hour: Math.max(0, Math.min(23, Math.round(a.hour))),
                    minute: Math.max(0, Math.min(59, Math.round(a.minute))),
                    days: (Array.isArray(a.days) ? a.days : []).filter(d => Number.isFinite(d) && d >= 0 && d <= 6).sort((x, y) => x - y),
                    armed: !!a.armed,
                    label: typeof a.label === "string" ? a.label : "",
                    mode: ["none", "command", "cloud"].includes(a.mode) ? a.mode : "none",
                    payload: typeof a.payload === "string" ? a.payload : "",
                    at: Number.isFinite(a.at) ? a.at : 0,

                    handledUntil: Number.isFinite(a.handledUntil) ? a.handledUntil : 0,
                    snoozedUntil: Number.isFinite(a.snoozedUntil) ? a.snoozedUntil : 0,
                    missed: !!a.missed
                }));

        for (const alarm of root.alarms)
            if (alarm.days.length === 0 && !alarm.at)
                alarm.at = root.nextClockTime(alarm.hour, alarm.minute, now);

        root.timers = (Array.isArray(disk?.timers) ? disk.timers : []).filter(t => t && Number.isFinite(t.total) && t.total > 0).map(t => ({
                    id: typeof t.id === "string" && t.id ? t.id : root.newId(),
                    total: t.total,
                    deadline: Number.isFinite(t.deadline) ? t.deadline : 0,
                    left: Number.isFinite(t.left) ? Math.max(0, t.left) : 0,
                    paused: !!t.paused,
                    finished: false,
                    label: typeof t.label === "string" ? t.label : ""
                })).map(t => {
            if (!t.paused)
                t.finished = t.deadline <= now;
            return t;
        }).filter(t => t.paused || !t.finished || now - t.deadline <= catchUpMs).slice(0, root.timerMax);

        root.loaded = true;
        root.rebuildZones();
        root.refreshOffsets();
    }

    Component.onCompleted: {
        if (Config.values.clock === undefined)
            console.warn("Clock: config.json has no `clock` block, so the shipped defaults cannot be changed. Add it to Config.defaults; see the contract in services/Clock.qml.");
    }
}
