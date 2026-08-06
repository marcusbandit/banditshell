pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// WHEN THIS MACHINE WAS AWAKE, kept as a log the shell writes for itself.
//
// The calendar wants to show the feeling of the machine being used: how many
// times a day it was woken and roughly how long it ran, with no numbers on
// any of it. Nothing on the system records that in a form a shell can read
// without root: logind journals boots but not wakes, parsing journalctl per
// glance would be a subprocess per day cell, and a D-Bus listener on
// PrepareForSleep is a daemon's worth of plumbing for what is really one
// observation, THE SHELL IS RUNNING RIGHT NOW. So the log is kept from the
// inside. The shell starting is a boot or a login, which is the granularity
// asked for; the wall clock jumping past where the next beat should have been
// is a sleep ending. Both of the interesting events fall out of one Timer and
// a comparison, no daemons, no privileges.
//
// The record is an array of spans [{s, e}] in epoch milliseconds, oldest
// first, the last one being the running session. Epoch rather than any local
// form on disk, because a span is a fact about the machine and the timezone
// is a fact about the viewer; days are cut into it locally at read time, in
// forDay below.
Singleton {
    id: root

    // The same directory AppIcons already writes, so the shell's memory lives
    // in one place. Quickshell has its own per-instance state path, rejected
    // here for the same reason nothing else uses it: it is derived from the
    // config's location, so launching the shell from a moved or symlinked
    // checkout would silently fork the diary, and a diary that forks when a
    // folder is renamed is not a diary.
    readonly property string dir: `${Quickshell.env("HOME")}/.local/state/banditshell`
    readonly property string path: `${root.dir}/usage.json`

    // WHETHER THE FILE HAS BEEN READ YET, for AppIcons' reason: every write is
    // a write of the whole log, and the log starts empty. A beat that landed
    // before the first read finished would replace a year of history with one
    // minute of it. Nothing writes, and the ticker does not run, until the
    // disk has had its say.
    property bool loaded: false

    // WHETHER THE FILE MAY BE WRITTEN AT ALL. False when a file exists but
    // could not be read OR could not be UNDERSTOOD: the one way to destroy the
    // history is to "recover" from a transient read error by saving an empty
    // table over it. Both halves of that matter, and the second half is the
    // one that nearly got away: a truncated log reads back perfectly and then
    // fails to parse, so the case most likely to produce a broken file is
    // exactly the case that arrives down the SUCCESSFUL load path. See the
    // FileView below, where both paths put this down for the one reason. The
    // session is still tracked in memory so the open calendar stays honest;
    // it just is not persisted, and the log says why.
    property bool keep: true

    // The spans themselves. MUTATED IN PLACE, deliberately, against the usual
    // var-property rule (see AppIcons.save): nothing binds to this property
    // raw, every consumer asks forDay() and re-asks on the `changed` signal,
    // so reallocating a four-hundred-day array every minute to trigger a
    // property notification nobody listens to would be work for no reader.
    property var spans: []

    // THE SPAN THIS INSTANCE IS WRITING, held by REFERENCE rather than found by
    // position. `spans[spans.length - 1]` was the running one for exactly as
    // long as this instance was the only thing that ever appended to the array.
    // absorb() below can now splice ANOTHER shell's span into it, and that
    // shell may have started after this one, so the last element is no longer
    // reliably ours: the beat would stretch somebody else's session every
    // minute and leave its own frozen at the moment the other one started. The
    // object survives prune() (a filter reuses the same records) and is the
    // same record the array holds, so mutating through it is mutating the log.
    property var current: null

    // The wall-clock time of the last beat, which is what sleep is measured
    // against. Milliseconds since the epoch do not fit an int; double holds
    // them exactly (they are far below 2^53).
    property double lastBeat: 0

    // Beats since the log last touched the disk; see the cadence note below.
    property int sinceSave: 0

    // Something about the log changed: a beat extended the running span, a
    // wake opened a new one. The signal is for imperative listeners; the
    // counter is the same fact as a PROPERTY, and it exists because forDay
    // reads it (see there): a QML binding captures every property touched
    // while it evaluates, including inside functions it calls, so any binding
    // that calls forDay re-evaluates when this bumps. Without it, a binding
    // on an in-place-mutated table (the note above) would never re-run, and
    // every consumer would need a Connections of its own.
    signal changed

    property int revision: 0

    // A beat a minute. The calendar reads at minute grain (its own clock is
    // SystemClock.Minutes), so a finer tick would be precision nothing
    // displays, and a coarser one would blur the sleep detection below by its
    // own width.
    readonly property int tickMs: 60 * 1000

    // HOW LATE A BEAT HAS TO BE TO MEAN SLEEP: several ticks' worth, derived
    // from the tick rather than a constant of its own so retuning the tick
    // retunes this with it. One beat late is timer coalescing on a busy
    // machine; even a compositor stall rarely swallows two whole beats; three
    // in a row means the clock that schedules them was itself stopped, and
    // the only thing that stops it is the machine sleeping. The cost of the
    // slack is that a nap shorter than three minutes reads as the session
    // continuing, which at this log's grain it may as well be.
    readonly property real napMs: root.tickMs * 3

    // HOW OFTEN THE LOG TOUCHES THE DISK: every fifth beat, not every beat.
    // A write here rewrites the whole file, and doing that 1440 times a day
    // is needless wear for a tail that is reconstructible to the minute
    // anyway. Five minutes bounds what a power cut can eat to a coffee's
    // worth of session, which is the trade. A span ROLLOVER saves at once,
    // because a wake is the event the whole log exists to remember.
    readonly property int saveEvery: 5

    // THE ROLLING WINDOW: a year of days plus a moon of slack, so "this week
    // last year" still has an answer when the year is a leap year or the
    // glance comes a month late. At a handful of spans a day that is a few
    // thousand records, tens of kilobytes; without a cap the file would grow
    // for as long as the machine lives, which is exactly what a state file
    // must not do.
    readonly property int keepDays: 400

    // A day's length FOR THE PRUNE ONLY. The prune is a horizon, where an
    // hour of DST error is nothing; forDay never uses this, it asks Date for
    // real local midnights, because there a fixed 24 hours would misfile the
    // evening of every daylight-saving day.
    readonly property double dayMs: 24 * 60 * 60 * 1000

    // WHAT ONE LOCAL DAY HOLDS: how many sessions touched it, and how many
    // minutes of them fell inside it. The day's edges are asked of Date as
    // real midnights (day + 1 rolls over months and years, and a DST day is
    // 23 or 25 hours long, both of which Date knows and arithmetic on 24h
    // does not). A span crossing midnight is clipped to the day, so its
    // minutes land on both days proportionally, and it counts as a session
    // on both, which is honest: the machine was up on both.
    function forDay(day: date): var {
        // Not decoration: reading `revision` inside the call is what hands a
        // calling BINDING its dependency on the log, per the note on the
        // property itself.
        const live = root.revision;
        const from = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime();
        const to = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1).getTime();
        let sessions = 0;
        let ms = 0;
        for (const sp of root.spans) {
            // Strict on the left so a just-woken span (s === e === now) still
            // counts for today: the wake IS the event, before it has minutes.
            if (sp.e < from || sp.s >= to)
                continue;
            sessions += 1;
            ms += Math.min(sp.e, to) - Math.max(sp.s, from);
        }
        return {
            sessions,
            minutes: Math.round(ms / 60000)
        };
    }

    // Drop everything that ended before the horizon. Called when a span is
    // OPENED (startup and wakes) rather than on the minute path: the window
    // only needs to slide when the log grows a record, and a filter over a
    // few thousand entries is not a per-minute cost worth paying anyway.
    function prune(now: double): void {
        const horizon = now - root.keepDays * root.dayMs;
        if (root.spans.length > 0 && root.spans[0].e < horizon)
            root.spans = root.spans.filter(sp => sp.e >= horizon);
    }

    // Whatever the FILE says, folded into what this instance remembers, record
    // by record. THE LOG HAS MORE THAN ONE WRITER.
    //
    // Every save is a rewrite of the whole file from this instance's array, and
    // that array was a snapshot of the disk taken once at startup. A second
    // shell on the session is a real situation (services/Notifs.qml says so
    // from the other side, where it costs the notification server), and with a
    // snapshot each and no re-read, the two of them erase each other: B loads
    // A's log, both push their own span, and A's next save five beats later
    // writes an array that has never heard of B. B's session is gone from the
    // file; B's next save puts it back and truncates A's. The log ends up
    // holding whichever shell wrote last, which for a DIARY is the one thing it
    // must not do.
    //
    // So a reload is not a replacement, it is an ARRIVAL of records this
    // instance did not know about. Keyed on `s`, the only stable identity a
    // span has: the start is written once and never moves, while `e` is the
    // thing both sides are still extending. Same key, longer `e` wins, because
    // a span only ever grows and the longer of two readings is simply the later
    // one; our own running span is always at least as long on this side as on
    // disk, so this can never shorten it. (Two shells starting inside the same
    // millisecond would share a key and fuse into one span. That is a coin
    // landing on its edge, and the union of two simultaneous sessions is not a
    // wrong answer about whether the machine was awake.)
    //
    // Nothing is written back from here. A record this instance just learned is
    // already on the disk it came from; the next ordinary save carries the
    // union along, and the two shells converge without either answering the
    // other.
    //
    // What it does NOT close is the last few milliseconds: if this instance
    // saves between another's write and the watcher delivering it, the other's
    // newest span is briefly overwritten. It comes straight back on that
    // shell's next save, so the only way to lose it is for that shell to write
    // once and then never again, and the tail at risk is bounded by the same
    // saveEvery the single-writer case already spends.
    function absorb(disk: var): void {
        const known = new Map();
        for (const sp of root.spans)
            known.set(sp.s, sp);

        let news = false;
        for (const sp of disk) {
            const mine = known.get(sp.s);
            if (!mine) {
                root.spans.push(sp);
                known.set(sp.s, sp);
                news = true;
            } else if (sp.e > mine.e) {
                mine.e = sp.e;
                news = true;
            }
        }

        if (!news)
            return;

        // Ordered again, because forDay does not care but the file's own
        // invariant does: spans are kept oldest first (the loader sorts for the
        // same reason), and a foreign span spliced onto the end is as likely to
        // predate ours as to follow it. prune's early-out reads that order as
        // fact, which is also why nothing prunes from here: a record older than
        // the horizon can arrive this way (a shell that has been up longer than
        // this one saving its own older window), and the next span opened
        // sweeps it with everything else rather than this function growing a
        // second copy of the horizon rule.
        root.spans.sort((a, b) => a.s - b.s);
        root.revision += 1;
        root.changed();
    }

    // The whole file, rewritten, and what it writes is the UNION: absorb has
    // already folded every other writer's records into this array, so a
    // whole-file write is no longer a whole-file claim. Compact rather than
    // AppIcons' pretty print: that file is a table of choices somebody may
    // reasonably open and read, this is a log of thousands of timestamps where
    // the indentation would triple the bytes rewritten every few minutes for no
    // reader.
    function save(): void {
        if (!root.loaded || !root.keep)
            return;
        store.setText(JSON.stringify(root.spans) + "\n");
    }

    // THE SESSION OPENS, once the disk has answered either way. Whatever span
    // was running when the previous shell died stays exactly as it was last
    // persisted (its tail, at most saveEvery minutes, is the price of the
    // write cadence); this start is a new fact and gets a new span. No
    // attempt to merge a quick `banditshell restart` into the old span: a
    // restart is a logon at the granularity the log was asked for, and
    // guessing at which gaps "count" would put policy where a record belongs.
    function begin(): void {
        const now = Date.now();
        root.prune(now);
        root.openSpan(now);
        root.lastBeat = now;
        root.loaded = true;
        root.save();
        root.revision += 1;
        root.changed();
    }

    // Start a span and remember which one it is. Two callers (a session
    // opening, a wake) do the same two things, and doing them in one place is
    // what keeps `current` from drifting out of step with the array: an append
    // that forgot to move the reference would leave the beat extending the
    // span before it, forever.
    function openSpan(now: double): void {
        const span = {
            s: now,
            e: now
        };
        root.spans.push(span);
        root.current = span;
    }

    // ONE BEAT. Either the minute passed like a minute, and the running span
    // stretches to now, or far more wall clock went by than ticker, which
    // means the machine slept: the old span is closed AT THE LAST BEAT (the
    // last moment the machine was provably awake; stretching it to now would
    // count the sleep as use) and the new span starting at now IS the woke-up
    // event the calendar's dots are counting.
    function beat(): void {
        const now = Date.now();
        // OURS by reference, not the array's tail: see `current`.
        const current = root.current;
        if (now - root.lastBeat > root.napMs) {
            current.e = root.lastBeat;
            root.prune(now);
            root.openSpan(now);
            root.sinceSave = 0;
            root.save();
        } else {
            current.e = now;
            root.sinceSave += 1;
            if (root.sinceSave >= root.saveEvery) {
                root.sinceSave = 0;
                root.save();
            }
        }
        root.lastBeat = now;
        root.revision += 1;
        root.changed();
    }

    Timer {
        interval: root.tickMs
        // Not before the file has been read: a beat that ran first would be
        // extending a span that does not exist yet.
        running: root.loaded
        repeat: true
        onTriggered: root.beat()
    }

    FileView {
        id: store

        path: root.path
        // WATCHED, because this instance is not the only thing that writes it.
        // Without this the file was read exactly once, at startup, and every
        // save afterwards rewrote the whole log from that one snapshot: put a
        // second shell on the session and the two of them delete each other's
        // history. See absorb, which is what the reload is for. Config.qml
        // watches its own file for the neighbouring reason, an outside edit;
        // here the outside editor is another copy of us.
        watchChanges: true
        printErrors: false

        // A change means somebody wrote. Reading it back costs a few kilobytes
        // at whatever rate the other shell saves, which is once every few
        // minutes; our OWN writes come back through here too and land in absorb
        // as a no-op, which is cheaper and steadier than keeping a
        // just-wrote-it flag in step with an asynchronous write.
        onFileChanged: reload()

        onLoaded: {
            let disk = [];
            try {
                const data = JSON.parse(text());
                // Taken guardedly rather than on faith: the file is state,
                // and state files get truncated by full disks and edited by
                // hand. A malformed entry is dropped instead of poisoning
                // every forDay that walks past it, and the sort restores the
                // oldest-first order the whole file assumes, which prune's
                // early-out on spans[0] reads as an invariant even when a hand
                // edit disordered them.
                disk = (Array.isArray(data) ? data : []).filter(sp => sp && typeof sp.s === "number" && typeof sp.e === "number" && sp.e >= sp.s).sort((a, b) => a.s - b.s);
            } catch (e) {
                // ON A RELOAD, SAY NOTHING AND CHANGE NOTHING. Every reload is
                // somebody else's write arriving, and the likeliest unparseable
                // thing here is that write caught halfway rather than a file
                // gone bad: answering it by emptying the table and refusing to
                // persist would be this instance inventing the very loss the
                // watch exists to prevent, over a condition that fixes itself
                // when the write finishes and fires this again.
                if (root.loaded)
                    return;

                // A FILE THAT PARSES AS NOTHING IS NOT A FILE THAT SAYS
                // NOTHING, which is the whole of why `keep` goes down here and
                // not only on the read error below. A log this shell cannot
                // make sense of is far likelier to be a log it caught
                // half-written (a full disk, a kill mid-setText, a hand edit
                // with a comma in the wrong place) than a log that genuinely
                // holds no days, and every one of those files still has the
                // history in it. Starting the table over in memory is right,
                // because the calendar has to draw something and the only
                // honest something is this session; SAVING that empty table
                // over the bytes it failed to read is the exact "recovery"
                // that destroys what a later hand, or a later parser, could
                // still have got back. So the session is tracked and not
                // persisted, the same bargain the unreadable-file path makes,
                // and for the same reason.
                console.warn(`Usage: ${root.path} is not valid JSON; tracking this session in memory only and leaving the file alone.`, e);
                root.keep = false;
            }

            // A RELOAD IS NEWS, NOT A BEGINNING. Only the first read gets to
            // say the shell started; anything after it is records arriving, and
            // begin() would log a session the machine never had.
            //
            // AND IT DOES NOT MERELY MISCOUNT, IT RUNS AWAY, which is worth
            // spelling out because the loop is not obvious from either half.
            // begin() ends in save(), save() writes the file, the write is a
            // change, the change reloads, and the reload was about to call
            // begin(). Written without this guard it did exactly that: nineteen
            // hundred zero-length spans in a hundred and fifty seconds, the file
            // growing by one record per pass, and the day's real history gone
            // under them. Watching a file this thing also writes means every
            // path out of a load has to be honest about which of the two it is
            // answering.
            if (root.loaded)
                return root.absorb(disk);

            root.spans = disk;

            // DEFERRED, because begin() ends in a WRITE and this is the READ's
            // own completion handler. A FileView finishing a load and being
            // handed setText from inside the signal it is still emitting drops
            // the operation it is in the middle of, and then logs
            // "quickshell.io.fileview: got operation finished from dropped
            // operation" when that operation reports back to a view that has
            // already moved on. The bytes still land, which is why this went
            // unnoticed: the file was correct and the shell simply warned once
            // every startup and once every config reload, in a log where the
            // whole value of a line is that somebody can act on it.
            //
            // config/Config.qml wraps its own schema rewrite for exactly this,
            // and this is the same shape one layer along. Deferring inside
            // save() instead was rejected: the beat's saves are already outside
            // any handler and do not need it, and pushing every write a turn
            // into the future to fix the one that is nested would hide the
            // rule rather than state it. Dropping the save from begin() and
            // letting the first beat persist the new span was rejected harder:
            // a shell that died inside its first minute would leave no record
            // it ever ran, which is the one thing this log is for.
            Qt.callLater(root.begin);
        }

        onLoadFailed: err => {
            // ONLY THE FIRST READ, now that the file is watched. A reload can
            // fail as well (the state directory wiped under a running shell),
            // and every branch below opens a session: unguarded, that recovery
            // would push a second span for a shell that never restarted, and on
            // the FileNotFound path run mkdir again for good measure.
            if (root.loaded)
                return;

            // No file yet is simply a machine this shell has not lived on
            // before: make the directory and start writing. Anything else
            // means a file we could NOT read, and that file must never be
            // written over; see `keep`.
            if (err === FileViewError.FileNotFound) {
                mkdir.running = true;
            } else {
                console.warn(`Usage: could not read ${root.path} (${err}); tracking this session in memory only.`);
                root.keep = false;
                root.begin();
            }
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", root.dir]
        onExited: root.begin()
    }
}
