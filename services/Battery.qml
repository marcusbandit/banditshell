pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice

    readonly property bool available: !!device?.isLaptopBattery

    readonly property real energy: device?.energy ?? 0
    readonly property real capacity: device?.energyCapacity ?? 0

    readonly property real percentage: root.capacity > 0 ? Math.max(0, Math.min(1, root.energy / root.capacity)) : (device?.percentage ?? 0)

    readonly property int percent: Math.floor(root.percentage * 100)

    readonly property bool charging: {
        const s = device?.state;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged || s === UPowerDeviceState.PendingCharge;
    }
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery

    readonly property real rate: Math.abs(device?.changeRate ?? 0)

    readonly property real designCapacity: sysfs.designWh
    readonly property int cycles: sysfs.cycleCount
    readonly property bool healthKnown: root.health > 0

    readonly property real health: root.designCapacity > 0 && root.capacity > 0 ? Math.min(100, root.capacity / root.designCapacity * 100) : (device?.healthSupported ? device.healthPercentage : 0)

    readonly property int secondsLeft: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)
    readonly property bool estimating: available && secondsLeft <= 0 && !full

    readonly property real lowThreshold: 0.15
    readonly property real rearmThreshold: 0.2

    readonly property bool low: available && onBattery && percentage <= lowThreshold

    readonly property bool reading: available && capacity > 0 && energy > 0

    property bool warned: false

    function considerWarning(): void {
        if (!root.reading)
            return;

        if (root.percentage > root.rearmThreshold) {
            root.warned = false;
            return;
        }

        if (!root.low || root.warned)
            return;

        root.warned = true;

        const left = root.timeLabel();
        root.notify("critical", `Battery low, ${root.percent}%`, left && left !== "estimating" ? `${left}. Find a charger.` : "Find a charger.");
    }

    function notify(urgency: string, summary: string, body: string): void {
        warner.command = ["notify-send", "-a", "banditshell", "-u", urgency, summary, body ?? ""];
        warner.running = true;
    }

    Process {
        id: warner
    }

    onPercentageChanged: root.considerWarning()
    onOnBatteryChanged: root.considerWarning()
    onReadingChanged: root.considerWarning()

    readonly property string state: !available ? "no battery" : full ? "full" : charging ? "charging" : onBattery ? "on battery" : "plugged in"

    function timeLabel(): string {
        if (!available || full)
            return "";
        if (estimating)
            return "estimating";
        const mins = Math.round(secondsLeft / 60);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        const left = h > 0 ? `${h}h ${m}m` : `${m}m`;
        return charging ? `${left} to full` : `${left} left`;
    }

    readonly property var chargingSteps: [20, 30, 50, 60, 80, 90]

    function icon(): string {
        if (!available)
            return "power";

        if (root.full || percentage >= 1)
            return charging ? "battery_charging_full" : "battery_full";

        if (!charging)
            return `battery_${Math.min(6, Math.floor(percentage * 7))}_bar`;

        const want = percentage * 100;
        const step = root.chargingSteps.reduce((best, s) => Math.abs(s - want) < Math.abs(best - want) ? s : best);
        return `battery_charging_${step}`;
    }

    readonly property QtObject sysfs: QtObject {
        property real designWh: 0
        property int cycleCount: 0
    }

    Process {
        id: probe

        running: true
        command: ["sh", "-c", `
for b in /sys/class/power_supply/BAT*; do
  [ -d "$b" ] || continue
  d=0
  [ -r "$b/energy_full_design" ] && d=$(cat "$b/energy_full_design")
  if [ "$d" = 0 ] && [ -r "$b/charge_full_design" ] && [ -r "$b/voltage_min_design" ]; then
    d=$(( $(cat "$b/charge_full_design") * $(cat "$b/voltage_min_design") / 1000000 ))
  fi
  c=0
  [ -r "$b/cycle_count" ] && c=$(cat "$b/cycle_count")
  echo "$d $c"
  exit 0
done
`]

        stdout: StdioCollector {

            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                if (parts.length < 2)
                    return;

                const design = Number(parts[0]);
                const count = Number(parts[1]);
                if (Number.isFinite(design) && design > 0)
                    root.sysfs.designWh = design / 1000000;
                if (Number.isFinite(count) && count >= 0)
                    root.sysfs.cycleCount = count;
            }
        }
    }

    Timer {

        interval: 60 * 60 * 1000
        running: root.available
        repeat: true
        onTriggered: probe.running = true
    }

    readonly property string logDir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string logPath: `${root.logDir}/battery-health.json`

    property bool logLoaded: false
    property bool logKeep: true

    property var samples: []
    property int logRevision: 0

    readonly property int keepSamples: 3700

    function dayKey(ms: double): string {
        const d = new Date(ms);
        const m = `0${d.getMonth() + 1}`.slice(-2);
        const day = `0${d.getDate()}`.slice(-2);
        return `${d.getFullYear()}-${m}-${day}`;
    }

    function record(): void {
        if (!root.logLoaded || !root.available || root.capacity <= 0)
            return;

        const now = Date.now();
        const key = root.dayKey(now);
        const sample = {
            d: key,
            t: now,

            cap: Math.round(root.capacity * 100) / 100,
            design: Math.round(root.designCapacity * 100) / 100,
            cycles: root.cycles
        };

        const at = root.samples.findIndex(s => s.d === key);
        if (at >= 0) {
            const was = root.samples[at];

            if (was.cap === sample.cap && was.cycles === sample.cycles && was.design === sample.design)
                return;
            root.samples[at] = sample;
        } else {
            root.samples.push(sample);
            root.pruneLog();
        }

        root.logRevision += 1;
        root.saveLog();
    }

    function pruneLog(): void {
        if (root.samples.length > root.keepSamples)
            root.samples = root.samples.slice(root.samples.length - root.keepSamples);
    }

    function absorbLog(disk: var): void {
        const known = new Map();
        for (const s of root.samples)
            known.set(s.d, s);

        let news = false;
        for (const s of disk) {
            const mine = known.get(s.d);
            if (!mine) {
                root.samples.push(s);
                known.set(s.d, s);
                news = true;
            } else if (s.t > mine.t) {
                mine.t = s.t;
                mine.cap = s.cap;
                mine.design = s.design;
                mine.cycles = s.cycles;
                news = true;
            }
        }

        if (!news)
            return;

        root.samples.sort((a, b) => a.d < b.d ? -1 : a.d > b.d ? 1 : 0);
        root.logRevision += 1;
    }

    function saveLog(): void {
        if (!root.logLoaded || !root.logKeep)
            return;
        healthStore.setText(JSON.stringify(root.samples) + "\n");
    }

    readonly property var firstSample: {
        const live = root.logRevision;
        return root.samples.length > 0 ? root.samples[0] : null;
    }

    readonly property var lastSample: {
        const live = root.logRevision;
        return root.samples.length > 0 ? root.samples[root.samples.length - 1] : null;
    }

    readonly property bool tracking: {
        const live = root.logRevision;
        return root.samples.length >= 2;
    }

    readonly property real lostWh: root.tracking ? root.firstSample.cap - root.lastSample.cap : 0

    readonly property int trackedDays: root.tracking ? Math.max(0, Math.round((root.lastSample.t - root.firstSample.t) / (24 * 60 * 60 * 1000))) : 0

    FileView {
        id: healthStore

        path: root.logPath

        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            let disk = [];
            try {
                const data = JSON.parse(text());

                disk = (Array.isArray(data) ? data : []).filter(s => s && typeof s.d === "string" && typeof s.t === "number" && typeof s.cap === "number").sort((a, b) => a.d < b.d ? -1 : a.d > b.d ? 1 : 0);
            } catch (e) {

                if (root.logLoaded)
                    return;

                console.warn(`Battery: ${root.logPath} is not valid JSON; keeping health history in memory only and leaving the file alone.`, e);
                root.logKeep = false;
            }

            if (root.logLoaded)
                return root.absorbLog(disk);

            root.samples = disk;
            root.logLoaded = true;
            root.logRevision += 1;

            Qt.callLater(root.record);
        }

        onLoadFailed: err => {

            if (root.logLoaded)
                return;

            if (err === FileViewError.FileNotFound) {

                logDirMk.running = true;
            } else {
                console.warn(`Battery: could not read ${root.logPath} (${err}); keeping health history in memory only.`);
                root.logKeep = false;
                root.logLoaded = true;
                root.record();
            }
        }
    }

    Process {
        id: logDirMk

        command: ["mkdir", "-p", root.logDir]
        onExited: {
            root.logLoaded = true;
            root.record();
        }
    }

    onCapacityChanged: Qt.callLater(root.record)
    onDesignCapacityChanged: Qt.callLater(root.record)

    Timer {

        interval: 60 * 60 * 1000
        running: root.logLoaded && root.available
        repeat: true
        onTriggered: root.record()
    }
}
