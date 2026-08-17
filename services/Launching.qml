pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// WHAT HAS BEEN LAUNCHED AND HAS NOT SHOWN UP YET.
//
// Between pressing Return and a window mapping there is nothing on screen at
// all, and for a browser that is several seconds of wondering whether the key
// registered. This is the register of those seconds; modules/LaunchNotice.qml
// draws it.
//
//   start(entry)   a launch happened, start waiting for its window
//   pending        every launch in flight, oldest first
//   shown          the ones worth drawing (past the grace period)
//   progress(rec)  how far along, against what this app took LAST time
//
// A record: { id, name, mark, marks, at, state, done }
// state: "waiting" -> "here" (a window mapped) or "lost" (nothing ever came).
//
// The estimate is the whole reason there is a file here: a spinner says
// "something is happening", a bar filled against firefox's own measured 1.8s
// says "and it is going normally". See startup.json.
Singleton {
    id: root

    readonly property var cfg: Config.values.launcher.opening

    property var pending: []

    // The clock the bars move against. Ticked only while something is in flight,
    // so an idle shell wakes nothing up.
    property real now: 0

    // WORTH DRAWING: the launches that outlived the grace period. Something that
    // was already on screen inside it is never shown at all, which is why a
    // terminal does not flash a pill on its way up.
    //
    // A PLAIN PROPERTY, written by the sweep below and not a filter binding over
    // `pending`. As a binding it would read `now` and hand out a brand new array
    // forty times a second, and the Repeater drawing it would tear down and
    // rebuild every pill on every tick.
    property var shown: []

    function visible(rec: var): bool {
        return (rec.state === "waiting" ? root.now : rec.done) - rec.at > root.cfg.graceMs;
    }

    // ------------------------------------------------------------------
    // STARTING

    function start(entry: var): void {
        if (!entry)
            return;

        const id = entry.id ?? entry.name ?? "";
        const rec = {
            id: id,
            name: entry.name || id,
            mark: root.markFor(entry),
            marks: root.marksFor(entry),
            at: Date.now(),
            state: "waiting",
            done: 0
        };

        // ONE ROW PER APPLICATION. Pressing Return twice on the same thing is
        // one wait restarted, not two notices stacked.
        root.pending = [...root.pending.filter(r => r.id !== id), rec];
        root.now = rec.at;
        tick.start();
    }

    // The icon, as an AppMark spec: the application's own artwork if the theme
    // has it, the category glyph if not.
    function markFor(entry: var): string {
        const art = entry.icon ? Quickshell.iconPath(entry.icon, true) : "";
        return art ? `image:${art}` : `symbol:${Apps.iconFor(entry.id ?? entry.name ?? "")}`;
    }

    // ------------------------------------------------------------------
    // MATCHING A WINDOW TO WHAT WAS ASKED FOR
    //
    // Every name the thing might call itself, normalised. A window's class is
    // only approximately its entry's id (`org.telegram.desktop` vs `telegram`,
    // `zen` vs `zen-browser`), and StartupWMClass is the one field written to
    // answer exactly this question, so it goes first.
    function marksFor(entry: var): var {
        const out = [];
        const add = s => {
            const k = root.key(s);
            if (k && !out.includes(k))
                out.push(k);
        };

        const id = (entry.id ?? "").replace(/\.desktop$/i, "");
        add(entry.startupClass);
        add(id);
        add(entry.name);
        add(((entry.command ?? [])[0] ?? "").split("/").pop());
        for (const v of Apps.nameVariants(id))
            add(v);
        return out;
    }

    function key(s: string): string {
        return (s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    // Three characters minimum either way: without it `qt` inside `qtcreator`
    // hands every Qt program's window to the wrong wait.
    function fits(rec: var, cls: string): bool {
        const k = root.key(cls);
        if (k.length < 3)
            return false;
        return rec.marks.some(m => m.length >= 3 && (m === k || m.includes(k) || k.includes(m)));
    }

    // A WINDOW MAPPED. The class first; the oldest wait as the fallback, because
    // a window appearing while you are waiting for one is nearly always it and
    // electron, wine and java programs report classes no desktop entry has ever
    // mentioned. Calling those "lost" would be the one wrong answer.
    function settle(cls: string): void {
        const waiting = root.pending.filter(r => r.state === "waiting");
        if (!waiting.length)
            return;
        root.land(waiting.find(r => root.fits(r, cls)) ?? waiting[0], cls);
    }

    // A WINDOW TOOK THE KEYBOARD, which is the other way a launch can succeed:
    // single-instance applications raise the window they already have and map
    // nothing at all. Class match only, no fallback: focus moves for a hundred
    // reasons that are not a launch.
    function noticeFocus(cls: string): void {
        const hit = root.pending.find(r => r.state === "waiting" && root.fits(r, cls));
        if (hit)
            root.land(hit, cls);
    }

    function land(rec: var, cls: string): void {
        if (!rec || rec.state !== "waiting")
            return;
        rec.state = "here";
        rec.done = Date.now();
        // Only a CLASS MATCH teaches the clock. The oldest-wait fallback is a
        // guess about which window belongs to which launch, and a guess that is
        // wrong writes somebody else's start-up time into this app's record.
        if (root.fits(rec, cls))
            root.learn(rec.id, rec.done - rec.at);
        root.pending = root.pending.slice();
        // A record is a plain object, so nothing watches its `state`: the pill
        // only hears about landing because the array it was built from is new.
        root.shown = root.pending.filter(r => root.visible(r));
    }

    // ------------------------------------------------------------------
    // THE CLOCK

    function expected(id: string): real {
        return root.times[id]?.ms ?? root.cfg.assumeMs;
    }

    function ceiling(rec: var): real {
        return Math.max(root.cfg.giveUpMs, root.expected(rec.id) * root.cfg.giveUpFactor);
    }

    // Asymptotic, not linear: the estimate is an estimate, so the bar has to be
    // able to be wrong without either stalling at the end or lying that it is
    // done. `curve` is how far along it reads AT the expected time; the rest of
    // the way it keeps creeping and never arrives until the window does.
    readonly property real curve: 1.8   // 1 - e^-1.8 = 83% at the expected time

    function progress(rec: var): real {
        if (rec.state !== "waiting")
            return 1;
        return 1 - Math.exp(-root.curve * (root.now - rec.at) / Math.max(1, root.expected(rec.id)));
    }

    // States move here rather than in bindings, because a state change is a
    // decision that has to happen once, not every time something reads it.
    Timer {
        id: tick

        interval: 40
        repeat: true
        running: false

        onTriggered: {
            const now = Date.now();
            root.now = now;

            const kept = [];
            let changed = false;

            for (const rec of root.pending) {
                if (rec.state === "waiting") {
                    if (now - rec.at > root.ceiling(rec)) {
                        rec.state = "lost";
                        rec.done = now;
                        changed = true;
                    }
                    kept.push(rec);
                    continue;
                }

                if (now - rec.done > (rec.state === "here" ? root.cfg.landedMs : root.cfg.lostMs)) {
                    changed = true;
                    continue;
                }
                kept.push(rec);
            }

            if (changed)
                root.pending = kept;

            // A NEW ARRAY ONLY WHEN SOMETHING ACTUALLY CHANGED. `shown` is what
            // the Repeater is built from: handing it a fresh array every tick
            // would tear down and rebuild every pill forty times a second.
            const live = kept.filter(r => root.visible(r));
            if (changed || live.length !== root.shown.length || live.some((r, i) => r !== root.shown[i]))
                root.shown = live;

            if (!kept.length)
                tick.stop();
        }
    }

    Connections {
        target: Hypr

        function onWindowOpened(addr: string, title: string, cls: string): void {
            root.settle(cls);
        }

        function onFocusedAddressChanged(): void {
            const bare = root.bare(Hypr.focusedAddress);
            if (!bare)
                return;
            const client = Hyprland.toplevels.values.find(t => root.bare(t.address ?? "") === bare);
            if (client)
                root.noticeFocus(Hypr.classOf(client));
        }
    }

    function bare(addr: string): string {
        return (addr.startsWith("0x") ? addr.slice(2) : addr).toLowerCase();
    }

    // ------------------------------------------------------------------
    // HOW LONG EACH APPLICATION TAKES, keyed by desktop entry id.
    //
    // Its own file, beside the launcher's frecency table and the usage diary,
    // for the reason Apps.qml's `path` note spells out at length: two things
    // sharing one file is two things erasing each other. One file per thing
    // remembered.
    readonly property string path: `${Apps.dir}/startup.json`

    property var times: ({})

    function learn(id: string, ms: real): void {
        if (!id || ms <= 0)
            return;

        const old = root.times[id]?.ms;
        const a = root.cfg.learn;
        root.times = Object.assign({}, root.times, {
            [id]: {
                ms: Math.round(old ? old * (1 - a) + ms * a : ms)
            }
        });
        store.setText(JSON.stringify(root.times));
    }

    FileView {
        id: store

        path: root.path
        printErrors: false

        onLoaded: {
            try {
                const data = JSON.parse(text());
                if (data && typeof data === "object" && !Array.isArray(data))
                    root.times = data;
                else
                    console.warn(`Launching: ${root.path} does not hold a table of times, starting them over.`);
            } catch (e) {
                console.warn(`Launching: ${root.path} is not valid JSON, starting the times over.`, e);
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    Process {
        id: mkdir

        command: ["mkdir", "-p", Apps.dir]
    }
}
