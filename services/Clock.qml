pragma Singleton

// The action runners below are a Component that reaches back to this singleton
// by id, which is the arrangement this pragma exists for: it binds the outer id
// at definition time instead of leaving it to whatever creation context the
// object happens to be made in. Half the shell already declares it for the same
// reason (shell.qml, modules/Ipc.qml, the pickers).
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Other places, countdowns, and things that go off. The clock panel's data.
//
// A singleton because the panel that draws this is a menu body, and a menu body
// is unloaded the moment its menu closes. A countdown that only exists while
// somebody is looking at it is not a countdown, and an alarm that only rings
// while its panel is open is not an alarm. So the deadlines, the beat and the
// firing all live here, and the panel is only ever drawing.
//
// ------------------------------------------------------------------
// WHY NO ZONE CONVERSION IN THIS FILE GOES THROUGH THE JS ENGINE.
//
// Both of the reasons were MEASURED on this machine rather than assumed, because
// the answer differs between Qt builds and getting it wrong is invisible.
//
// There is no Intl at all. A probe under Qml Runtime 6.11.1 reports
// `typeof Intl === "undefined"`, so `Intl.DateTimeFormat` with a `timeZone`
// option does not exist. That much would be survivable: it throws, and a thing
// that throws gets fixed.
//
// The second one is the trap, and it is why this note is at the top of the file
// rather than beside the code. `Date.prototype.toLocaleString` ACCEPTS an
// options object containing a timeZone, does not throw, and silently IGNORES the
// zone. Probed against Asia/Tokyo it returned character for character the same
// string as the plain local call. A world clock built on it would compile, run,
// pass a glance, and quietly show Copenhagen's time under nine different city
// names. There is no error to notice and no exception to catch; the only way to
// find out is to already know what time it is in Tokyo.
//
// So offsets come from the system, which is the only thing here that actually
// holds the tz database: one `sh` per refresh running `TZ=<id> date +%z` in a
// loop over every configured zone plus the local one, which is one process for
// the whole set rather than one per zone. It is exact where a hand-written table
// would not be: TZ=Asia/Kathmandu comes back +0545 and TZ=America/St_Johns comes
// back -0230, so the quarter- and half-hour zones are simply right.
//
// Refreshes are deliberately rare (on load, when a place is added, at the top of
// each hour, and whenever the wall clock is seen to jump). Between them
// everything is arithmetic: add offsetMinutes to the epoch millisecond and read
// the UTC components back off the result. NEVER assemble a zone's wall clock out
// of LOCAL components; that applies this machine's own offset a second time, and
// the error is exactly the local offset, which is invisible from a UTC machine
// and two hours out from here in summer.
//
// ------------------------------------------------------------------
// THIS CANNOT WAKE A SLEEPING MACHINE, and nobody should have to discover that
// by oversleeping.
//
// systemd's `WakeSystem=` is the only route to an RTC wake, and systemd.timer(5)
// says of it: "this functionality requires privileges and is thus generally only
// available in the system service manager". This is a user-session shell, so it
// has no such route, and no amount of care in here creates one.
//
// What it does instead is measure against ABSOLUTE deadlines in epoch
// milliseconds rather than counting a duration down. A counter stops when the
// machine suspends; time does not. So a deadline that passed during a suspend is
// noticed on the first beat after resume and fires there, reporting how late it
// is, rather than being silently skipped or silently restarted.
//
// ------------------------------------------------------------------
// A COMMAND-MODE ALARM RUNS A SHELL COMMAND THE USER WROTE.
//
// As the user, with the user's environment, at a time the user chose, with no
// confirmation and no sandbox. That is precisely a cron line and it is trusted
// precisely as far, for the reason cron is: an alarm that pops a "are you sure"
// dialog at 07:00 is not an alarm. The payload goes to `sh -c` verbatim, so it
// gets pipes, globs and semicolons like any other shell line.
//
// The one string in this file that IS policed is the IANA zone id, and the
// difference is worth stating: the payload is a command the user typed on
// purpose, while a zone id arrives from a list, from disk, or from the CLI, and
// nobody typing "Asia/Tokyo" means it to be a command. See validZone.
Singleton {
    id: root

    // ------------------------------------------------------------------
    // CONFIGURATION.
    //
    // Read through this rather than straight off Config, for the window in which
    // this file exists and `Config.defaults.clock` does not. A key absent from
    // the defaults does not exist at all in this shell (set() refuses it and
    // merge() drops it), so a plain read comes back undefined and poisons the
    // first arithmetic that touches it; this project has shipped that bug three
    // times. The fallbacks below are the same numbers the contract asks the
    // integrator to put in Config.defaults, so behaviour does not change when
    // they land, and Component.onCompleted says out loud, once, when they have
    // not. They are dead code the moment the schema carries the block.
    //
    // Reading `Config.values` INSIDE the function is not incidental: a QML
    // binding captures every property touched while it evaluates, including
    // inside the functions it calls, so the tokens below re-evaluate when the
    // config live-reloads. services/Usage.qml documents the same trick from the
    // other side, where forDay() reads `revision` for it.
    function token(name: string, fallback: var): var {
        const block = Config.values.clock;
        const value = block ? block[name] : undefined;
        return value === undefined ? fallback : value;
    }

    // GNOME's number, and the historical one every alarm clock has used since
    // the mechanical ones: nine minutes.
    readonly property int snoozeMinutes: root.token("snoozeMinutes", 9)

    // How long a ringing alarm rings before it gives up on being answered. A
    // permanent accent on the screen is worse than a missed alarm you can see,
    // so an unanswered one stops itself and leaves its row marked missed.
    readonly property int ringMinutes: root.token("ringMinutes", 15)

    // HOW LATE IS STILL WORTH RINGING. The whole point of absolute deadlines is
    // that a deadline missed during a suspend fires on resume, but that argument
    // runs out somewhere: an alarm from Tuesday going off on Friday afternoon is
    // not the alarm anybody set, and running its COMMAND three days late could
    // be actively wrong (the shutdown you scheduled for midnight arriving in the
    // middle of Friday's work). So inside this window a stale deadline fires
    // normally and says how late it is; outside it the alarm is marked missed,
    // its action does NOT run, and one quiet notification says so. An hour is
    // the default because an hour is roughly "you stepped out", and beyond that
    // the alarm has stopped being about now.
    readonly property int catchUpMinutes: root.token("catchUpMinutes", 60)

    // The caps. Owned here rather than by the panel because this is what holds
    // the lists; a panel that merely stopped DRAWING past the cap would still be
    // ticking things nobody can reach.
    readonly property int timerMax: root.token("timerMax", 3)
    readonly property int alarmMax: root.token("alarmMax", 8)

    // HOW TO SEND A MESSAGE TO CLAUDE, as an argv template with the message
    // appended as the last argument.
    //
    // The shape is not invented here: services/AppIcons.qml already asks Claude
    // for an icon through `Config.values.apps.claude`, an argv array with the
    // prompt appended last, and a second convention for the same job would be a
    // second thing to keep in step. A separate token rather than a reuse of that
    // one because they are different errands: the icon fetcher is allowed to
    // write files (`--permission-mode acceptEdits`) and an alarm saying "remind
    // me what I was doing" has no business being allowed to.
    //
    // VERIFIED on this machine rather than guessed: `claude` resolves to
    // /usr/bin/claude, and its own --help documents `-p, --print` as "Print
    // response and exit (useful for pipes)" with the prompt as the positional
    // argument. So `claude -p "<message>"` is a real non-interactive invocation
    // and is the default. It is a template and not a hardcoded binary precisely
    // so it can be pointed at something else entirely; anything that takes its
    // message as a trailing argument fits.
    //
    // THE DEFAULT IN Config.defaults MUST BE THE EMPTY ARRAY, and the real
    // default lives here instead, which looks backwards until you read merge().
    // A NON-EMPTY default array is treated as a fixed-length tuple: "return
    // Array.isArray(over) && (base.length === 0 || over.length === base.length)
    // ? over : base". So shipping ["claude", "-p"] as the schema's default would
    // silently refuse every user value that is not exactly two arguments, which
    // is every interesting one: the whole point of a template is that somebody
    // adds a flag to it. An EMPTY default is documented there as "a list, not a
    // tuple", and whatever the user writes survives at any length. Empty
    // therefore means "not configured" rather than "configured to nothing", and
    // is what falls through to the built-in below.
    readonly property var cloud: {
        const set = root.token("cloud", []);
        return Array.isArray(set) && set.length > 0 ? set : ["claude", "-p"];
    }

    // How long a cloud message may take before it is killed, and how much of the
    // reply comes back as a notification.
    //
    // ONLY CLOUD MODE IS TIME-LIMITED, and the asymmetry is deliberate. A cloud
    // message is a network call that can hang forever with nothing to show for
    // it. A COMMAND is the user's own, and the most obvious alarm command on
    // this machine is something that plays a sound until you stop it: putting a
    // stopwatch on that would be this file deciding how long the user's alarm is
    // allowed to be, which cron does not do either.
    readonly property int cloudSeconds: root.token("cloudSeconds", 120)
    readonly property int cloudReplyChars: root.token("cloudReplyChars", 240)

    // ------------------------------------------------------------------
    // WHERE THE STATE LIVES.
    //
    // Beside usage.json and the icon table, because this is the same kind of
    // thing: a record the shell keeps for itself about what the user set up.
    // Quickshell's own per-instance state path is rejected here for the reason
    // Usage.qml states, that it is derived from the config's location, so
    // launching from a moved checkout would silently fork the file.
    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/clock.json`

    // WHETHER THE FILE HAS BEEN READ YET. Every write is a write of the whole
    // document and the document starts empty, so a save that landed before the
    // first read finished would replace every alarm with none. Nothing writes
    // and no alarm fires until the disk has had its say.
    property bool loaded: false

    // WHETHER THE FILE MAY BE WRITTEN AT ALL. Down when a file exists but could
    // not be read OR could not be UNDERSTOOD, and the second half is the one
    // that matters most: a truncated file reads back perfectly and then fails to
    // parse, so the case likeliest to produce a broken file arrives down the
    // SUCCESSFUL load path. Usage.qml makes the same bargain for the same
    // reason. The shell still runs with an empty set in memory so the panel has
    // something honest to draw; it just does not save over bytes it could not
    // make sense of.
    property bool keep: true

    // ------------------------------------------------------------------
    // PLACES.

    // The user's list, as IANA ids, in the order they were added. The DERIVED
    // rows are `zones` below; this is the thing that is persisted.
    property var places: []

    // Everything the machine knows, for the picker. Empty until loadZoneList()
    // is called, because 598 strings are not worth holding for a panel that has
    // never been opened.
    property var allZones: []

    // The machine's own zone, its city, and its offset east of UTC in minutes.
    property string localZone: ""
    readonly property string localCity: root.cityOf(root.localZone)
    property int localOffset: 0

    // THE DRAWN ROWS, rebuilt whenever the offsets or the list change, and
    // SORTED BY OFFSET so the panel's day bars read west to east down the
    // column. Sorted here rather than in the panel because the sort is what
    // makes the row of pips a scale, and a derived order stated once cannot
    // drift from a stored order somebody has to maintain.
    //
    // Each entry: { id, city, offsetMinutes, deltaMinutes, hour, minute,
    //               hourOfDay, dayDelta, text }
    //
    // `deltaMinutes` is the offset FROM HERE, which is the number a person says
    // out loud; `offsetMinutes` is from UTC, which is the number the arithmetic
    // uses. `hour`/`minute`/`hourOfDay`/`dayDelta`/`text` are a snapshot, fresh
    // to the minute while somebody is watching (see `watch`) and stale
    // otherwise; anything that wants them exact drives zoneTime() off its own
    // clock instead.
    property var zones: []

    // id -> minutes east of UTC, as last measured. Kept apart from `zones` so a
    // list change can be redrawn without waiting for another process.
    property var offsetMap: ({})

    // A zone id that is safe to put on a command line, and nothing else.
    //
    // These reach `sh -c`. Unlike an alarm's payload, which the user wrote as a
    // command on purpose, a zone id arrives from a list, from a state file, or
    // from the CLI, and nobody typing a city name is asking to run anything. The
    // tz database's own naming is letters, digits, underscore, dot, plus and
    // minus in slash-separated components (Etc/GMT+5 and America/Port-au-Prince
    // are both real), which contains no quote, no space and no shell
    // metacharacter, so a single-quoted id built from this cannot escape its
    // quotes.
    function validZone(id: string): bool {
        return typeof id === "string" && /^[A-Za-z][A-Za-z0-9_+.-]*(\/[A-Za-z0-9_+.-]+)*$/.test(id) && id.length < 64;
    }

    // "Europe/Copenhagen" -> "Copenhagen". Underscores are the tz database's
    // spaces and mean nothing to a reader.
    function cityOf(id: string): string {
        if (!id)
            return "";
        return id.slice(id.lastIndexOf("/") + 1).replace(/_/g, " ");
    }

    function addZone(id: string): void {
        if (!root.validZone(id) || root.places.includes(id))
            return;
        // The local zone is the panel's first block, not a row in the list, so
        // adding it would draw the same place twice with one of the copies
        // labelled "+0h". If the machine's zone changes later the row simply
        // becomes redundant, which is honest and self-correcting; silently
        // filtering it out of the list at read time would be this file
        // swallowing something the user asked for.
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

    // The picker's list, fetched once and kept. Idempotent, so the panel may
    // call it every time its field opens.
    function loadZoneList(): void {
        if (root.allZones.length > 0 || zoneList.running)
            return;
        zoneList.running = true;
    }

    // WHAT THE WALL CLOCK READS at `at` in a zone `offsetMinutes` east of UTC.
    //
    // The one conversion in the file, and the reason it is a function rather
    // than a stamped value: it is pure arithmetic on an epoch millisecond, so
    // anything with its own clock can drive it at whatever grain it draws at,
    // and nothing here has to tick on that thing's behalf.
    //
    // getUTC* off a SHIFTED instant, never the local getters: the shift has
    // already put the zone's wall clock into the number, and reading it back
    // locally would add this machine's offset a second time.
    function zoneTime(offsetMinutes: int, at: double): var {
        const there = new Date(at + offsetMinutes * 60000);
        const here = new Date(at + root.localOffset * 60000);
        const hour = there.getUTCHours();
        const minute = there.getUTCMinutes();
        return {
            hour,
            minute,
            // Fractional hours, which is what a 24-hour bar wants: a pip placed
            // from whole hours jumps once an hour and reads as broken.
            hourOfDay: hour + minute / 60,
            // -1 yesterday, 0 the same day, +1 tomorrow, relative to here. Whole
            // days apart rather than a comparison of dates, so it survives a
            // month and a year boundary without a single branch.
            dayDelta: root.dayNumber(there) - root.dayNumber(here),
            text: `${root.pad2(hour)}:${root.pad2(minute)}`
        };
    }

    // Days since the epoch, off the UTC components of an already-shifted date.
    function dayNumber(d: date): int {
        return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 86400000);
    }

    function pad2(n: int): string {
        return n < 10 ? `0${n}` : `${n}`;
    }

    // "+9h", "-4h30", "+5h45". Minutes only when there are any, because "+9h00"
    // is four characters spent saying nothing.
    function offsetLabel(deltaMinutes: int): string {
        const sign = deltaMinutes < 0 ? "-" : "+";
        const abs = Math.abs(deltaMinutes);
        const h = Math.floor(abs / 60);
        const m = abs % 60;
        return m === 0 ? `${sign}${h}h` : `${sign}${h}h${root.pad2(m)}`;
    }

    // ------------------------------------------------------------------
    // WHO IS WATCHING.
    //
    // SysInfo.qml's idiom, for the same reason: the snapshot fields on `zones`
    // are only worth refreshing while something is drawing them, and a clock
    // bound to labels nobody can see still wakes the render thread every minute
    // for the life of the shell. A panel calls watch(true) as it opens and
    // watch(false) as it closes. A panel that would rather not is free to skip
    // it entirely and call zoneTime() off its own SystemClock, which is the
    // cheaper route and the one the clock menu takes.
    property int watchers: 0

    function watch(on: bool): void {
        root.watchers = Math.max(0, root.watchers + (on ? 1 : -1));
        // Immediately, not on the next minute boundary: a panel opening at
        // 14:59:58 would otherwise draw two seconds of yesterday's snapshot.
        if (on)
            root.rebuildZones();
    }

    SystemClock {
        id: minuteClock

        precision: SystemClock.Minutes
        enabled: root.watchers > 0
        onDateChanged: root.rebuildZones()
    }

    // ------------------------------------------------------------------
    // COUNTDOWNS.
    //
    // Each: { id, total, deadline, left, paused, finished, label }, all
    // milliseconds. `deadline` is an absolute epoch instant and is the only
    // thing a running timer is measured against; `left` is what is stored while
    // PAUSED, because a paused timer genuinely has no deadline yet and inventing
    // one would make it start counting again the moment the shell restarted.
    //
    // The array is rebuilt only when a timer is added, removed or changes state,
    // NOT once a second. Rebuilding it per beat would change the identity of
    // every record every second and churn whatever model is drawing it. What
    // moves per second is `tick` below; the remaining time is a function of it.
    property var timers: []

    // The epoch millisecond of the last beat, which only advances while the beat
    // is running (a timer alive, an alarm armed, or something ringing). Bind to
    // this for a per-second refresh; it costs nothing when there is nothing to
    // count.
    property double tick: 0

    function remainingOf(timer: var, at: double): double {
        if (!timer)
            return 0;
        return timer.paused ? timer.left : Math.max(0, timer.deadline - at);
    }

    // A new countdown. Returns its id, or "" when there was no room: the cap is
    // enforced here because this is what holds the list, and a panel that merely
    // stopped drawing past it would leave timers running with no way to reach
    // them. A FINISHED timer is only waiting to be acknowledged, so it gives up
    // its slot before a running one is ever refused.
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

    // Pause a running one, resume a paused one. A finished one is not a state
    // with two sides, so it answers nothing.
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
        // Reassigned rather than mutated in place, because a var property only
        // notifies on assignment and the panel binds to the array.
        root.timers = root.timers.slice();
        root.save();
    }

    function removeTimer(id: string): void {
        if (!root.timers.some(t => t.id === id))
            return;
        root.timers = root.timers.filter(t => t.id !== id);
        root.save();
    }

    // ------------------------------------------------------------------
    // ALARMS.
    //
    // Each: {
    //   id, hour, minute,
    //   days,          // 0 = Monday .. 6 = Sunday. EMPTY means one-shot.
    //   armed, label,
    //   mode,          // "none" | "command" | "cloud"
    //   payload,
    //   at,            // one-shot only: the absolute instant it is due
    //   handledUntil,  // watermark; nothing at or before this can fire again
    //   snoozedUntil,  // 0 unless snoozed
    //   missed
    // }
    //
    // MONDAY IS ZERO, which is not JavaScript's convention and is deliberate:
    // the panel's day pills are labelled from `Qt.locale().dayName(i + 1,
    // Locale.NarrowFormat)` for i in 0..6, which is Monday-first with no
    // seven-entry table anywhere, and the index that labels a pill has to be the
    // index that arms it. weekdayOf() below is the one place the two
    // conventions meet.
    //
    // `handledUntil` is the whole of how firing stays exact across restarts and
    // suspends. It is not "when it last rang": it is "no occurrence at or before
    // this instant may fire", which is the same statement for an alarm that rang
    // and for an alarm that was created ten minutes after its own time. Set it
    // to now whenever an alarm is created, armed or rescheduled, and to the
    // occurrence itself when one is dealt with. It persists, so an alarm due
    // while the shell was down has a watermark from before that deadline and
    // fires (or is marked missed) the moment the shell is back, and one that
    // already rang cannot ring twice however stale the file's other fields are.
    property var alarms: []

    // The alarm demanding an answer right now, or null. The panel draws its
    // block from this, and the shell window opens the clock menu pinned when it
    // goes non-null: an alarm is the one thing permitted to interrupt, and it
    // does not violate the "nothing at a glance" doctrine, because it is a
    // request the user made earlier arriving when they asked for it.
    property var ringing: null

    // When the current ringing started, and how late it already was when it did.
    property double ringingSince: 0
    property double ringingLate: 0

    // Announcements. `fired` and `missed` carry the alarm record; `actionFailed`
    // carries what went wrong so a panel can say it without re-running anything.
    signal fired(alarm: var)
    signal missed(alarm: var)
    signal actionFailed(alarm: var, code: int, output: string)
    signal timerFinished(timer: var)

    // JavaScript's Sunday-first day number, in this file's Monday-first terms.
    function weekdayOf(d: date): int {
        return (d.getDay() + 6) % 7;
    }

    // The epoch instant of hour:minute on the local day `offset` days from `d`.
    // Built through Date rather than by adding milliseconds, because a
    // daylight-saving day is 23 or 25 hours long and Date knows that where
    // arithmetic on 86400000 does not.
    function occurrence(from: date, offset: int, hour: int, minute: int): double {
        return new Date(from.getFullYear(), from.getMonth(), from.getDate() + offset, hour, minute, 0, 0).getTime();
    }

    // The next time the wall clock reads hour:minute, strictly after `at`. What
    // a ONE-SHOT alarm means, resolved once into an absolute instant rather than
    // being re-derived from the hour every time it is read: an alarm set at
    // 22:00 for 07:00 means tomorrow morning, and an instant says so where a
    // pair of numbers has to be asked twice.
    function nextClockTime(hour: int, minute: int, at: double): double {
        const from = new Date(at);
        const today = root.occurrence(from, 0, hour, minute);
        return today > at ? today : root.occurrence(from, 1, hour, minute);
    }

    // The next occurrence strictly after `at`, or 0 if the alarm has none.
    // Eight days of walk rather than a modular calculation on weekdays: eight
    // covers a full week plus the wrap in every case, and a loop that asks Date
    // for each candidate cannot get a DST boundary wrong.
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

    // The most recent occurrence at or before `at`, which is what a catch-up
    // asks for: not "when is it next" but "what did I sleep through".
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

    // The occurrence this alarm owes an answer for right now, or 0.
    function pendingFor(alarm: var, at: double): double {
        if (!alarm.armed)
            return 0;
        // A snooze outranks the schedule and suspends it: nine minutes cannot
        // reach the next daily occurrence, so there is nothing to arbitrate, and
        // letting the schedule fire underneath a snooze would mean the thing you
        // just postponed going off anyway.
        if (alarm.snoozedUntil > 0) {
            if (alarm.snoozedUntil > at)
                return 0;
            return alarm.snoozedUntil > alarm.handledUntil ? alarm.snoozedUntil : 0;
        }
        const due = root.lastFor(alarm, at);
        return due > alarm.handledUntil && due <= at ? due : 0;
    }

    // A new alarm at the next whole hour, armed, one-shot, with its editor's
    // work already half done. Not at 00:00: a new alarm that starts at midnight
    // is a new alarm you have to fix before it is worth anything.
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

    // Patch one alarm. Every field the editor can touch comes through here, so
    // there is one place that re-derives the schedule afterwards; the editor
    // writes through on every scrub and has no Done button, which only works
    // because this is cheap and idempotent.
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

    // Point an alarm at its next occurrence and forget everything it was
    // carrying about the last one. Editing an alarm at 07:30 that is set for
    // 07:00 must not make it go off immediately, which is exactly what moving
    // the watermark to now buys.
    function reschedule(alarm: var): void {
        const now = Date.now();
        alarm.handledUntil = now;
        alarm.snoozedUntil = 0;
        alarm.missed = false;
        if (alarm.days.length === 0)
            alarm.at = root.nextClockTime(alarm.hour, alarm.minute, now);
        // If the alarm being rescheduled is the one currently ringing, the
        // ringing is about an occurrence that no longer exists.
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

    // Nine minutes more. The recoverable answer, and the one the panel gives the
    // big target: Apple's own heat-map testing found equal-sized Stop and Snooze
    // produced up to thirty percent more oversleeping, so the cost of a mis-hit
    // here is asymmetric and the layout says so.
    function snooze(): void {
        const alarm = root.ringing;
        if (!alarm)
            return;
        alarm.snoozedUntil = Date.now() + root.snoozeMinutes * 60000;
        root.clearRinging();
        root.alarms = root.alarms.slice();
        root.save();
    }

    // Done with it. A repeating alarm rolls to its next matching day, which
    // needs no code: the watermark is already past the occurrence that rang, so
    // nextFor finds the following one. A one-shot disarms, because "the next
    // 07:00" has happened and re-arming is a decision, not a default.
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

    // ------------------------------------------------------------------
    // THE BEAT.
    //
    // One timer, at second grain, RUNNING ONLY while there is something to
    // count. It compares Date.now() against absolute deadlines rather than
    // decrementing anything, for the reason in the header: a decrementing
    // counter stops with the machine and time does not.
    //
    // A second is the right grain because a second is what the panel draws: the
    // countdown numerals cut per second and no zone row shows seconds at all.
    readonly property int tickMs: 1000

    // How late a beat has to be to mean the machine slept, derived from the beat
    // rather than being a constant of its own. Usage.qml makes the same test at
    // minute grain and spends three beats of slack on it; a second-grained beat
    // is coalesced far more often on a busy machine, so this is more generous in
    // ticks and still a fraction of the time any real suspend takes. What it
    // triggers is only an offset refresh, so being wrong costs one process.
    readonly property real napMs: root.tickMs * 20

    Timer {
        interval: root.tickMs
        repeat: true
        // Not before the file has been read: a beat that ran first would be
        // deciding about alarms that are still on the disk.
        //
        // A PAUSED timer does not count as something to count. It has no
        // deadline to compare against and its numerals do not move, so including
        // it would leave this ticking, and `tick` moving, for the life of the
        // shell over a countdown that is by definition not counting.
        running: root.loaded && (root.ringing !== null || root.alarms.some(a => a.armed) || root.timers.some(t => !t.finished && !t.paused))
        onTriggered: root.beat()
    }

    function beat(): void {
        const now = Date.now();
        const slept = root.tick > 0 && now - root.tick > root.napMs;
        root.tick = now;

        // Coming back from a suspend is the one moment the offsets are most
        // likely to be wrong (the machine may have crossed a DST boundary, or
        // been carried somewhere), and the cheapest moment to notice.
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
        // An alarm nobody answered stops itself. See ringMinutes: an accent
        // sitting on the screen forever is worse than a missed alarm you can
        // see, and the row keeps the mark so it is still visible afterwards.
        if (root.ringing && now - root.ringingSince > root.ringMinutes * 60000)
            root.answer(true);

        // One at a time, deliberately. Two alarms set for the same minute are a
        // real thing, and a panel showing both at once would have to say which
        // Snooze belongs to which; the second one is not lost, because its
        // watermark is untouched and it is picked up on the next beat after the
        // first is answered.
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
                // TOO LATE TO BE THE ALARM ANYBODY SET. It does not ring and its
                // action does not run; see catchUpMinutes for why running a
                // stale command is the part that could actually do harm. It says
                // so once, quietly, because an alarm that silently evaporated is
                // indistinguishable from an alarm that never worked.
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

    // Titled by the occurrence that actually came due rather than by the alarm's
    // stored hour and minute, which are the same thing for every alarm this shell
    // creates and are NOT the same thing for a snoozed one: a 07:00 alarm snoozed
    // twice arrives at 07:18, and a notification headed 07:00 would be reporting
    // the wrong event by eighteen minutes.
    function alarmTitle(alarm: var, due: double): string {
        const at = new Date(due);
        const when = `${root.pad2(at.getHours())}:${root.pad2(at.getMinutes())}`;
        return alarm.label ? `${when}  ${alarm.label}` : `Alarm ${when}`;
    }

    // "2h 13m", "45m", "20s". Two units at most, because a third is precision
    // nobody reads off a lateness.
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

    // Unique for as long as this shell runs, and stable on disk afterwards. The
    // millisecond alone is not enough: two alarms added inside one turn would
    // share it, and the id is what every mutation looks a record up by.
    property int serial: 0

    function newId(): string {
        root.serial += 1;
        return `${Date.now().toString(36)}-${root.serial.toString(36)}`;
    }

    // ------------------------------------------------------------------
    // WHAT AN ALARM DOES WHEN IT GOES OFF.
    //
    // Two modes and a notification. The notification is not one of the modes: it
    // happens on EVERY firing, whatever the action is or is not, because an
    // action can be entirely silent (a file touched, a message sent) and an
    // alarm you cannot tell went off is not an alarm.
    //
    // COMMAND is `sh -c <payload>` and is trusted exactly as far as a cron line;
    // the header states that in full. CLOUD sends the payload as a MESSAGE
    // rather than running it, through the configurable argv template above, with
    // the message appended as the last argument.
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
                // A template nobody can run is not a failure to report later; it
                // is a misconfiguration to report now, in the same place every
                // other failure lands.
                root.report(alarm, -1, "The clock.cloud template is empty, so there was nothing to send the message to.");
                return;
            }
            // WRAPPED IN `timeout`, unlike a command. A cloud message is a
            // network call that can hang with nothing to show for it; a user's
            // own command is very often something that plays a sound until it is
            // stopped, and putting a stopwatch on that would be this file
            // deciding how long an alarm may be. -k gives it five seconds to
            // die politely before the kill.
            root.spawn(["timeout", "-k", "5", `${root.cloudSeconds}`, ...template, alarm.payload], alarm);
        }
    }

    // A notification, sent the way anything else on this session sends one.
    //
    // Through notify-send and the bus rather than by reaching into Notifs.qml,
    // and the reason is that this shell IS the notification server: the message
    // goes out and comes straight back in through NotificationServer, so an
    // alarm arrives as an ordinary notification with an ordinary lifecycle,
    // ordinary history, and an ordinary way to dismiss it. Constructing an entry
    // by hand would have produced a second kind of notification that looks the
    // same and behaves differently, which is exactly the thing that goes wrong
    // six months later.
    //
    // CRITICAL, for both alarms and timers, which is not a decoration: Notifs'
    // timeoutFor returns 0 for a critical notification, so it stays until it is
    // acted on. The default timeout is five seconds, and a kitchen timer whose
    // only announcement vanishes after five seconds has announced nothing. A
    // missed alarm is normal urgency, because it is a report rather than a
    // demand.
    //
    // AND NO ICON, which was a mistake worth leaving the reason for. The first
    // version passed `-i alarm`, `-i timer`, `-i error`, which are Material
    // Symbols glyph names, the vocabulary components/Icon.qml uses everywhere
    // else in this shell. notify-send's -i is a FREEDESKTOP ICON THEME name,
    // which is a different vocabulary entirely, and the running shell answered
    // every firing with `WARN: Could not load icon "alarm" at size QSize(80, 80)`
    // and then drew nothing. Naming a real theme icon instead (Adwaita has
    // alarm-symbolic) would work on this machine and depend on the installed
    // theme everywhere else. Sending no icon is both correct and better: the
    // badge is a slot for the SENDER'S own artwork, this sender is the shell and
    // has none, and NotifEntry's fallback is a Material Symbols glyph drawn in
    // the shell's own colour, which is the right picture and was always going to
    // be reached anyway.
    function notify(urgency: string, summary: string, body: string): void {
        root.spawn(["notify-send", "-a", "banditshell", "-u", urgency, summary, body ?? ""], null);
    }

    // A FAILED ACTION IS REPORTED, NOT SWALLOWED. An alarm whose whole purpose
    // was to run something, that ran nothing, and said nothing, is worse than an
    // alarm that never fired: it looks like it worked.
    function report(alarm: var, code: int, output: string): void {
        const detail = (output ?? "").trim().split("\n").filter(l => l.trim()).pop() ?? "";
        root.notify("critical", `${alarm.mode === "cloud" ? "Cloud message" : "Alarm command"} failed`, detail ? `exit ${code} · ${detail}` : `exit ${code}`);
        root.actionFailed(alarm, code, output ?? "");
    }

    // One process per errand, made and destroyed, rather than one shared slot.
    // A Process is a single slot: handing it a new command line while the last
    // one is still running drops the one in flight, and firings arrive in bursts
    // (an alarm's action, its notification, and a timer finishing in the same
    // second all want a process at once).
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

            // Null for a notification, which reports nothing and is only being
            // fired and forgotten.
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
                        // A CLOUD MESSAGE THAT GOT AN ANSWER SAYS SO. Without
                        // this the whole mode is invisible: the message goes out,
                        // something replies, and the reply lands on a stdout
                        // nobody is reading. Trimmed to a notification's worth,
                        // because this is a notification and not a transcript.
                        const reply = task.out.trim();
                        root.notify("normal", root.alarmTitle(task.alarm, Date.now()), reply.length > root.cloudReplyChars ? `${reply.slice(0, root.cloudReplyChars)}...` : reply);
                    }
                }
                // Deferred by the engine, so the collectors that are still
                // reporting into this object are not pulled out from under
                // themselves mid-signal.
                task.destroy();
            }
        }
    }

    // ------------------------------------------------------------------
    // THE SYSTEM'S SIDE OF THE ZONES.

    Process {
        id: zoneProc

        running: true
        // timedatectl first because it is the session's own answer; the symlink
        // is what every machine without systemd-timedated still has, and UTC is
        // what is left when a machine will not say. Falling through to UTC
        // rather than to "" matters: an empty local zone means no offsets are
        // measured at all, and a world clock that shows nothing is worse than
        // one that admits it is reading UTC.
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

        // timedatectl's list is the curated one, 598 entries here, and it is
        // taken WHOLE. An earlier version of this kept only ids with a region in
        // front of them and dropped forty-four, which sounded like tidying and
        // was not: "Japan", "Poland", "Turkey", "GMT" and "CET" are exactly the
        // things somebody types into a filter field, and the list is filtered by
        // substring, so an alias nobody wants costs nothing and an alias missing
        // costs a search that comes back empty.
        //
        // The find is for a machine with no timedatectl, and IT does the
        // excluding, in the shell, where the things being excluded actually are.
        // /usr/share/zoneinfo holds three kinds of file that are not places: the
        // posix/ and right/ trees, which are second and third copies of the
        // whole database, the .tab/.zi/.list indexes, and Factory, which is a
        // deliberate placeholder. Filtering them here rather than by a pattern in
        // QML keeps the knowledge of that directory's layout in the one command
        // that reads it.
        command: ["sh", "-c", "timedatectl list-timezones 2>/dev/null || (cd /usr/share/zoneinfo 2>/dev/null && find . -type f ! -path './posix/*' ! -path './right/*' ! -name '*.tab' ! -name '*.zi' ! -name '*.list' ! -name 'leapseconds' ! -name 'Factory' ! -name 'localtime' | sed 's|^\\./||' | sort)"]

        stdout: StdioCollector {
            onStreamFinished: {
                // validZone and nothing else. It is the same gate that keeps a
                // zone id off a command line, so the picker cannot offer a name
                // that addZone would then refuse.
                root.allZones = text.split("\n").map(l => l.trim()).filter(id => root.validZone(id));
            }
        }
    }

    Process {
        id: offsetProc

        // Set when a refresh is asked for while one is in flight. A Process is a
        // single slot, so the ask cannot simply be repeated; it is remembered
        // and made again on the way out.
        property bool again: false

        stdout: StdioCollector {
            onStreamFinished: root.applyOffsets(text)
        }

        onExited: {
            if (!offsetProc.again)
                return;
            offsetProc.again = false;
            // A turn later, because `running` is least worth trusting inside the
            // signal that reports the process exiting.
            Qt.callLater(root.refreshOffsets);
        }
    }

    function refreshOffsets(): void {
        // Nothing to measure against yet. The local zone's own process calls
        // back into here when it lands, so this is a wait rather than a loss.
        if (!root.localZone)
            return;
        if (offsetProc.running) {
            offsetProc.again = true;
            return;
        }
        // The local zone first and de-duplicated, so the machine's own offset
        // comes back in the same reading as everything it is compared against;
        // measuring them separately would let a DST boundary land between the
        // two processes and make every delta an hour out for one refresh.
        const ids = [root.localZone, ...root.places].filter((id, i, all) => root.validZone(id) && all.indexOf(id) === i);
        const list = ids.map(id => `'${id}'`).join(" ");
        // Single quotes are safe because validZone has already refused anything
        // that is not letters, digits and the four punctuation marks the tz
        // database uses; there is no quote in the set to close them with.
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
        // A reading that did not include the local zone is a reading nothing can
        // be compared against, so it is dropped whole rather than half-applied.
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
            // A place whose offset has not come back yet is left out rather than
            // drawn at zero: a row that says 14:00 because nothing measured it
            // is a lie, and a row that is not there yet is merely a row that is
            // not there yet.
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

    // The top of every hour, re-armed each time from the wall clock rather than
    // left on a fixed interval. A fixed 3600s timer started at 14:23 next fires
    // at 15:23, which puts a DST change twenty-three minutes into the past
    // before anything notices; and after a suspend it fires late, computes a
    // fresh interval, and refreshes at once, which is the behaviour wanted
    // anyway. A second of slack past the hour so the tz database has definitely
    // rolled over.
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

    // ------------------------------------------------------------------
    // THE DISK.

    function save(): void {
        if (!root.loaded || !root.keep)
            return;
        // Pretty-printed, unlike Usage's log: this is a small document somebody
        // may reasonably open and edit by hand (an alarm's command is the
        // obvious thing to want to fix in an editor), and the indentation costs
        // a few hundred bytes on a file written a handful of times a day.
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

        // NOT WATCHED, which is the one place this file deliberately parts with
        // services/Usage.qml's discipline, and the reason is what the two files
        // hold. A usage log is append-only, so a second shell's records can be
        // absorbed record by record and the union is always right. This is a
        // DOCUMENT: "the user deleted that alarm" is a fact that no merge can
        // represent, so absorbing a reload would resurrect deleted alarms, and
        // there is no field that could tell an arriving deletion apart from an
        // arriving creation. Config.qml, the other document in this shell, is
        // last-writer-wins for the same reason. The running timers settle it
        // besides: a countdown this instance is holding is not the disk's to
        // have an opinion about.
        onLoaded: {
            let disk = null;
            try {
                disk = JSON.parse(text());
            } catch (e) {
                // A FILE THAT PARSES AS NOTHING IS NOT A FILE THAT SAYS NOTHING.
                // Far likelier to be a document caught half-written, or hand
                // edited with a comma in the wrong place, than a document that
                // genuinely holds no alarms, and every one of those files still
                // has the alarms in it. Running with an empty set is right,
                // because the panel has to draw something; SAVING that empty set
                // over the bytes is the "recovery" that destroys what a later
                // hand could still have got back.
                console.warn(`Clock: ${root.path} is not valid JSON; running with no alarms and leaving the file alone.`, e);
                root.keep = false;
            }
            root.adopt(disk);
        }

        onLoadFailed: err => {
            // No file yet is simply a machine this shell has not kept time on
            // before: make the directory and start writing. Anything else is a
            // file we could NOT read, and that file must never be written over.
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

    // Whatever the disk said, taken guardedly. State files get truncated by full
    // disks and edited by hand, so every field is checked rather than trusted: a
    // malformed alarm dropped here is one alarm lost, where a malformed alarm
    // taken on faith is an undefined reaching the deadline arithmetic and a beat
    // that throws once a second forever.
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
                    // The watermark is what makes a deadline missed while the
                    // shell was down fire when it comes back, so a file without
                    // one is read as "nothing has been handled" rather than as
                    // "everything has": a missing watermark should cost a late
                    // alarm at worst, never a silently skipped one.
                    handledUntil: Number.isFinite(a.handledUntil) ? a.handledUntil : 0,
                    snoozedUntil: Number.isFinite(a.snoozedUntil) ? a.snoozedUntil : 0,
                    missed: !!a.missed
                }));

        // A one-shot alarm with no stored instant (hand written, or from an
        // older file) is given the next one now, so it means what its hour and
        // minute say rather than sitting at zero and reading as due since 1970.
        for (const alarm of root.alarms)
            if (alarm.days.length === 0 && !alarm.at)
                alarm.at = root.nextClockTime(alarm.hour, alarm.minute, now);

        // TIMERS DO COME BACK, and the reason they can is that what is stored is
        // the DEADLINE and not the remaining duration. A stored duration would
        // have to either lie about how much is left (it has been draining while
        // the shell was down) or fire the moment the shell returns; an absolute
        // instant simply is what it is, and a countdown that elapsed while the
        // shell was away comes back FINISHED, unacknowledged, showing zero.
        //
        // It does not announce itself on restore. The notification would say
        // "your timer is done" about something that finished twenty minutes ago,
        // which is the same lie in a different place; the row in the panel is
        // the honest report. And one that elapsed longer ago than the alarms'
        // catch-up window is dropped entirely, for the same reason and by the
        // same rule: past that point it is not news.
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

    // Said once, at startup, and only while it is true. A missing schema block
    // is not a crash here (the tokens above fall back to the same numbers the
    // contract asks for), but it does mean none of it can be CHANGED: set()
    // refuses a key that is not in the defaults and merge() drops it on load, so
    // a user editing config.json would find their edits silently vanish. That is
    // worth one line in the log and nothing more.
    Component.onCompleted: {
        if (Config.values.clock === undefined)
            console.warn("Clock: config.json has no `clock` block, so the shipped defaults cannot be changed. Add it to Config.defaults; see the contract in services/Clock.qml.");
    }
}
