pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// UPower, adapted.
//
// `available` is the first thing anything should ask. On a desktop there is no
// battery, and UPower still hands over a display device that reads 0% and
// "unknown"; a widget that trusts it shows a flat battery on a machine that has
// none. Everything below is only meaningful when `available` is true.
Singleton {
    id: root

    readonly property UPowerDevice device: UPower.displayDevice

    readonly property bool available: !!device?.isLaptopBattery

    // ---- THE CHARGE, AT THE FINEST GRAIN THE CELL OFFERS -------------------
    //
    // Watt-hours, NOT UPower's percentage. Percentage arrives already rounded
    // to a whole number: this machine reports it as exactly 24.0 while the
    // energy underneath says 13.18 Wh of 54.9, which is 24.007%. One percent of
    // this cell is half a watt-hour, so anything driven by the percentage sits
    // perfectly still for half an hour and then jumps; driven by the energy it
    // moves in 0.01 Wh steps, about fifty times finer, and the movement is
    // continuous enough to animate.
    //
    // `capacity` is what the cell charges to TODAY (UPower's EnergyFull), not
    // what it charged to new. That is the right denominator for "how full is
    // it": a worn battery at its own full is at 100%, because it is. What it
    // was new is `designCapacity` below, and the ratio of the two is health.
    readonly property real energy: device?.energy ?? 0
    readonly property real capacity: device?.energyCapacity ?? 0

    // 0..1. Falls back to UPower's own figure only when the energy is not there
    // to divide, which is a device that reports a percentage and nothing else.
    readonly property real percentage: root.capacity > 0 ? Math.max(0, Math.min(1, root.energy / root.capacity)) : (device?.percentage ?? 0)

    // THE NUMBER TO WRITE DOWN, which is a different question from how full the
    // tank is drawn. Floored rather than rounded, for the two reasons that
    // point the same way: rounding puts "100%" on a battery at 99.5, which is
    // the one reading anyone actually checks, and it steps the text at the half
    // percent, where nothing visible happens. Floored, the number changes at
    // exactly the moment the battery loses a point, and holds still while the
    // level behind it keeps moving.
    readonly property int percent: Math.floor(root.percentage * 100)

    readonly property bool charging: {
        const s = device?.state;
        return s === UPowerDeviceState.Charging || s === UPowerDeviceState.FullyCharged || s === UPowerDeviceState.PendingCharge;
    }
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged
    readonly property bool onBattery: UPower.onBattery

    // Watts. Negative while discharging in some drivers, so take the magnitude
    // and let `charging` say the direction.
    readonly property real rate: Math.abs(device?.changeRate ?? 0)

    // ---- HOW WORN THE CELL IS ---------------------------------------------
    //
    // NOT device.healthPercentage, which is the obvious answer and the wrong
    // one here: Quickshell reports healthSupported false and healthPercentage 0
    // on this battery, so the menu said "unknown" about a cell that knows
    // perfectly well it is at 96%. UPower's own Capacity property reads
    // 96.3158% for the same device at the same moment, and both numbers it is
    // made of sit in sysfs, so this asks sysfs and keeps the UPower figure as
    // the fallback for a device where that path works and this one does not.
    //
    // Health is what it charges to now over what it charged to new. Capped at
    // 100 because a cell can be delivered slightly over its own design figure,
    // and "103% health" reads as a bug rather than as good news.
    readonly property real designCapacity: sysfs.designWh
    readonly property int cycles: sysfs.cycleCount
    readonly property bool healthKnown: root.health > 0

    readonly property real health: root.designCapacity > 0 && root.capacity > 0 ? Math.min(100, root.capacity / root.designCapacity * 100) : (device?.healthSupported ? device.healthPercentage : 0)

    // Seconds until the interesting end, whichever that is. UPower reports 0
    // when it does not know yet, which is common for the first minute after a
    // plug or unplug.
    readonly property int secondsLeft: charging ? (device?.timeToFull ?? 0) : (device?.timeToEmpty ?? 0)
    readonly property bool estimating: available && secondsLeft <= 0 && !full

    // Below this, the shell is allowed to shout about it.
    readonly property real lowThreshold: 0.2
    readonly property bool low: available && onBattery && percentage <= lowThreshold

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

    // Material Symbols has a clean 0..6 bar ramp for a discharging battery and a
    // RAGGED set for a charging one: 20, 30, 50, 60, 80, 90 exist, 40, 70 and
    // 100 do not. Snapping to the nearest name that is really in the font is why
    // this is a lookup and not arithmetic; computing the name gave
    // `battery_charging_70`, which the font renders as the WORDS, in a menu.
    readonly property var chargingSteps: [20, 30, 50, 60, 80, 90]

    function icon(): string {
        if (!available)
            return "power";
        // `full` leads the comparison now that the percentage is a division
        // rather than UPower's own rounded figure: energy and capacity are both
        // estimates the firmware revises, and a cell that is genuinely full can
        // land a hair under 1.0 and lose its full icon over a rounding error.
        // The state is the authority on being full; the ratio is the fallback
        // for a device that never reports one.
        if (root.full || percentage >= 1)
            return charging ? "battery_charging_full" : "battery_full";
        // Clamped to 6: the font has battery_0_bar through battery_6_bar, and
        // floor(percentage * 7) reaches 7 at exactly 100%. That is unreachable
        // only because the line above catches it first, which is the kind of
        // safety that stops being safe the moment someone edits the guard.
        if (!charging)
            return `battery_${Math.min(6, Math.floor(percentage * 7))}_bar`;

        const want = percentage * 100;
        const step = root.chargingSteps.reduce((best, s) => Math.abs(s - want) < Math.abs(best - want) ? s : best);
        return `battery_charging_${step}`;
    }

    // ---- WHAT SYSFS KNOWS THAT UPOWER WOULD NOT SAY ------------------------

    readonly property QtObject sysfs: QtObject {
        property real designWh: 0
        property int cycleCount: 0
    }

    // A SUBPROCESS rather than a FileView, for two reasons that a FileView
    // cannot cover between them: the directory's name is not known ahead of
    // time (BAT0 on this machine, BAT1 on plenty of others, two of them on a
    // ThinkPad), and the design figure comes in either of two units. Most cells
    // report energy in µWh; some report charge in µAh, which means nothing
    // until it is multiplied by the design voltage. Doing both in the shell is
    // what keeps QML seeing watt-hours and only watt-hours.
    // services/SysInfo.qml finds its thermal zone the same way.
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
            // Two integers, µWh and a count. Anything else is a machine that
            // does not keep these files, and the UPower fallback on `health`
            // stands rather than this writing a zero over it.
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
        // HOURLY, and not because anything is waiting on it. The design figure
        // never moves and the cycle count moves at most once a day; this is
        // only so a shell that has been up for a fortnight is not still quoting
        // the count it read on the day it started.
        interval: 60 * 60 * 1000
        running: root.available
        repeat: true
        onTriggered: probe.running = true
    }

    // ---- THE HEALTH LOG ----------------------------------------------------
    //
    // 96% health means nothing on its own. 96% having been 99% eight months ago
    // is the whole fact, and nothing on the system keeps it: UPower reports the
    // present and forgets. So the shell remembers, in the same state directory
    // Usage.qml keeps its diary in.
    //
    // A record is {d, t, cap, design, cycles}: the local day as a key, the
    // moment it was taken, the watt-hours the cell charges to now, what it
    // charged to new, and the cycles behind it. ONE RECORD PER DAY, so a
    // restarted shell and a second shell on the session both leave one, and the
    // last reading of a day is the one that stands.
    readonly property string logDir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string logPath: `${root.logDir}/battery-health.json`

    // The same two guards Usage.qml runs on, for the same reasons. Nothing is
    // written before the file has been read, because an empty table saved first
    // would replace years of records with nothing. And nothing is written at
    // all if the file could not be read OR could not be parsed: a half-written
    // file still has the history in it, and "recovering" by saving over it is
    // how that history actually gets destroyed.
    property bool logLoaded: false
    property bool logKeep: true

    // Mutated in place, so nothing binds to it raw. Everything reads the
    // derived properties below, which take their dependency through
    // logRevision.
    property var samples: []
    property int logRevision: 0

    // TEN YEARS OF DAYS. A record is about sixty bytes, so the ceiling is a
    // file measured in tens of kilobytes, and no cell outlives the window
    // anyway. It is here so the file has a ceiling at all, which is the
    // difference between a log and a leak.
    readonly property int keepSamples: 3700

    // The local day, as the key. Local rather than UTC because someone reading
    // "since 3 aug" means their own 3rd of August. Padded by hand: toISOString
    // is UTC, and toLocaleDateString depends on a locale that would rekey the
    // entire log the day it changed.
    function dayKey(ms: double): string {
        const d = new Date(ms);
        const m = `0${d.getMonth() + 1}`.slice(-2);
        const day = `0${d.getDate()}`.slice(-2);
        return `${d.getFullYear()}-${m}-${day}`;
    }

    // Take a reading. Cheap and idempotent: called hourly, on startup, and
    // whenever the capacity moves, and it writes nothing if today's record
    // already says what this one would.
    function record(): void {
        if (!root.logLoaded || !root.available || root.capacity <= 0)
            return;

        const now = Date.now();
        const key = root.dayKey(now);
        const sample = {
            d: key,
            t: now,
            // Two decimals, which is the grain sysfs reports in anyway. Full
            // doubles would triple the file for digits that are noise.
            cap: Math.round(root.capacity * 100) / 100,
            design: Math.round(root.designCapacity * 100) / 100,
            cycles: root.cycles
        };

        const at = root.samples.findIndex(s => s.d === key);
        if (at >= 0) {
            const was = root.samples[at];
            // `design` is in the comparison because it can arrive AFTER the
            // first record of a run: sysfs is read by a subprocess and UPower
            // by D-Bus, and either can answer first. Without it, a record
            // written in the gap would keep a design of zero all day, and the
            // health meter's notch reads that day as a divide by nothing.
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

    // Another shell's records, folded into this one's. Same shape as
    // Usage.absorb and there for the same reason: every save rewrites the whole
    // file from an array that was a snapshot of the disk, so without this two
    // shells erase each other's history. Keyed on the day, later reading wins.
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

        // Oldest first, which the derived properties below read as fact. An ISO
        // day sorts lexicographically, so this needs no date parsing.
        root.samples.sort((a, b) => a.d < b.d ? -1 : a.d > b.d ? 1 : 0);
        root.logRevision += 1;
    }

    function saveLog(): void {
        if (!root.logLoaded || !root.logKeep)
            return;
        healthStore.setText(JSON.stringify(root.samples) + "\n");
    }

    // ---- WHAT THE LOG ADDS UP TO -------------------------------------------
    //
    // Each of these reads logRevision first. That is not decoration: the table
    // is mutated in place, so a binding on `samples` alone would never re-run,
    // and touching the revision inside the binding is what gives it the
    // dependency.

    readonly property var firstSample: {
        const live = root.logRevision;
        return root.samples.length > 0 ? root.samples[0] : null;
    }

    readonly property var lastSample: {
        const live = root.logRevision;
        return root.samples.length > 0 ? root.samples[root.samples.length - 1] : null;
    }

    // TWO RECORDS THAT DISAGREE, or nothing. A fresh log says nothing about a
    // trend for its first days, which is honest: one point is not a slope, and
    // a meter that invents one would be worse than a meter that waits.
    readonly property bool tracking: {
        const live = root.logRevision;
        return root.samples.length >= 2;
    }

    // Watt-hours the cell has lost since the log started watching. Positive is
    // wear; a negative reading is the firmware revising its own estimate
    // upward, which happens after a full cycle and is not worth hiding.
    readonly property real lostWh: root.tracking ? root.firstSample.cap - root.lastSample.cap : 0

    // How long the log has been watching, in days.
    readonly property int trackedDays: root.tracking ? Math.max(0, Math.round((root.lastSample.t - root.firstSample.t) / (24 * 60 * 60 * 1000))) : 0

    FileView {
        id: healthStore

        path: root.logPath
        // Watched, because this shell is not the only thing that writes it: a
        // second shell on the session writes the same file. See absorbLog.
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            let disk = [];
            try {
                const data = JSON.parse(text());
                // Taken guardedly. A state file gets truncated by full disks and
                // edited by hand, and one bad record should be dropped rather
                // than poison every reading that walks past it.
                disk = (Array.isArray(data) ? data : []).filter(s => s && typeof s.d === "string" && typeof s.t === "number" && typeof s.cap === "number").sort((a, b) => a.d < b.d ? -1 : a.d > b.d ? 1 : 0);
            } catch (e) {
                // On a RELOAD, say nothing and change nothing: the likeliest
                // unparseable thing here is another shell's write caught
                // halfway, and it fixes itself when that write finishes and
                // fires this again.
                if (root.logLoaded)
                    return;

                console.warn(`Battery: ${root.logPath} is not valid JSON; keeping health history in memory only and leaving the file alone.`, e);
                root.logKeep = false;
            }

            // A reload is news arriving, not a beginning.
            if (root.logLoaded)
                return root.absorbLog(disk);

            root.samples = disk;
            root.logLoaded = true;
            root.logRevision += 1;

            // Deferred, because record() ends in a WRITE and this is the READ's
            // own completion handler. A FileView handed setText from inside the
            // signal it is still emitting drops the operation it is in the
            // middle of and then warns about it. config/Config.qml and
            // services/Usage.qml both wrap their first write for this.
            Qt.callLater(root.record);
        }

        onLoadFailed: err => {
            // Only the first read. A reload can fail too (the state directory
            // wiped under a running shell), and recovering from that as though
            // it were startup would run mkdir again for good measure.
            if (root.logLoaded)
                return;

            if (err === FileViewError.FileNotFound) {
                // A machine this shell has not watched before. Make the
                // directory, then start.
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

    // THE FIRST RECORD OF A RUN needs two things that arrive in either order:
    // the file read, and UPower answering. The log's own load handler covers
    // the case where UPower got there first; this covers the other one, since
    // the capacity going from nothing to a real number IS UPower arriving.
    onCapacityChanged: Qt.callLater(root.record)
    onDesignCapacityChanged: Qt.callLater(root.record)

    Timer {
        // A reading an hour. Capacity moves over months, so this is not
        // sampling; it is making sure a day never passes unrecorded while the
        // shell is up.
        interval: 60 * 60 * 1000
        running: root.logLoaded && root.available
        repeat: true
        onTriggered: root.record()
    }
}
