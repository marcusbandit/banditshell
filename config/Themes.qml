pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every palette the shell can wear. It does not own one any more.
//
// ~/.config/theme is this machine's colour authority: `theme-set` renders one
// theme into `current/` for every app on the box at once, and palette.json is
// this shell's share of that render. So this file READS a palette rather than
// declaring one, and hands it on through the same Theme block Appearance.qml
// has always taken. That is why nothing downstream of here had to change: the
// derivation layer never knew where the colours came from, only what shape they
// arrive in.
//
// The two literal themes at the bottom are the FLOOR, not the menu. They are
// what the shell wears while palette.json is missing, unreadable or not a
// palette, so a renderer that is not there yet costs a wrong colour rather than
// a black desktop. The moment the file parses, it wins.
//
// A theme is a luminance RAMP plus three saturated ACCENTS and one ALARM. It
// never names a widget: "which colour is the panel" is a decision for
// Appearance.qml, so a palette only has to supply colours, not know what they
// are used for.
Singleton {
    id: root

    readonly property string palettePath: `${Quickshell.env("HOME")}/.config/theme/current/palette.json`
    readonly property string cataloguePath: `${Quickshell.env("HOME")}/.config/theme/current/themes.json`

    // The renderer's palette once it has parsed, null before the first read and
    // again if the file ever stops being a palette. This is the whole of "who
    // owns the colours right now", asked in one place.
    property var parsed: null
    readonly property bool live: root.parsed !== null

    // Failed reads since the last good one, and how many of those are chased at
    // speed before the retry backs off. See onLoadFailed.
    property int retries: 0
    readonly property int rapidRetries: 5

    readonly property string fallback: "greensteel"

    // The literal palettes, reachable by name only while the renderer is not
    // answering, which is the entire job they have left.
    readonly property var literals: ({
            greensteel: greensteel,
            slate: slate
        })

    // WHAT THE SHELL CAN BE ASKED TO WEAR BY NAME. Exactly one entry while the
    // renderer is live, because the shell is holding exactly one palette: the
    // rendered one. A name lookup cannot conjure the others, since their
    // colours are on disk as toml the shell does not read.
    //
    // This is NOT the picker's list, and the difference is the whole of the
    // section below `get()`. What may be OFFERED is every theme on the machine
    // and what may be WORN is what has been rendered, and conflating the two is
    // how the shell ends up either in a different theme from the windows around
    // it or unable to change theme at all.
    readonly property var all: {
        if (!root.live)
            return root.literals;
        const only = {};
        only[root.rendered.name] = root.rendered;
        return only;
    }

    readonly property var names: Object.keys(root.all)

    // The renderer wins whenever it has something to say, whatever name is
    // asked for: a config.json still naming a palette this machine no longer
    // renders must not put the shell in a different theme from the windows
    // around it. Without a render, the old behaviour exactly: name lookup, and
    // the fallback theme for a name nothing knows.
    function get(name: string): Theme {
        return root.all[name] ?? (root.live ? root.rendered : root.literals[root.fallback]);
    }

    // ---------------------------------------------------------- what a picker
    //
    // A DIFFERENT QUESTION FROM `names`, with a different answer.
    //
    // `names` is what the shell can be asked to WEAR by a name lookup, and
    // while a render is live that is one theme, because the render is the only
    // palette the shell is holding. A picker is not asking that. It is asking
    // what `theme-set` could be told next, and the renderer publishes exactly
    // that on every render: themes.json, one entry per theme on disk, written
    // beside the palette by the same build.
    //
    // So the picker lists the catalogue and a press runs `theme-set`. That is
    // the whole point of it: the shell stops being a second menu that can
    // disagree with the desktop it is drawn on, and becomes the thing that
    // WRITES the theme every other app on the machine then reads.

    // The renderer's index once it has parsed, null before the first read and
    // again if the file ever stops being an index.
    property var indexed: null

    // The literals are the floor here too. A machine whose renderer has not
    // written an index yet, or wrote one this file cannot read, still gets a
    // picker with the built-in names in it rather than an empty card.
    readonly property var catalogue: root.indexed ?? Object.keys(root.literals).map(n => ({
                name: n,
                dim: root.literals[n].dim,
                mid: root.literals[n].mid,
                bright: root.literals[n].bright,
                alarm: root.literals[n].alarm
            }))

    readonly property var availableNames: root.catalogue.map(t => t.name)

    // WHICH ROW IS LIT. The render's own name, because the render is what the
    // machine is wearing. config.json's `theme` key is not asked and is not
    // written any more: `theme-set` is the single writer now, and a second
    // record of the same fact is a second thing to be wrong.
    readonly property string activeName: root.live ? root.rendered.name : root.fallback

    // THE SATURATED END OF A THEME THAT IS NOT ON, so a row can preview itself
    // in its OWN colours rather than in the ones it would replace, which is the
    // one thing a picker drawn from `get()` could never do.
    //
    // For the theme that IS on, the render wins: the catalogue carries what the
    // source toml asked for and the render carries what came out of the
    // pipeline, and only the second is the colour actually on screen.
    function accentsFor(name: string): var {
        if (root.live && name === root.rendered.name)
            return {
                dim: root.rendered.dim,
                mid: root.rendered.mid,
                bright: root.rendered.bright,
                alarm: root.rendered.alarm
            };

        // A name in neither place falls through to `get()`, which is the
        // fallback theme on a machine with no render and the worn one
        // otherwise. Both are wrong for a row that should not exist, and both
        // are a colour rather than four black chips.
        const t = root.catalogue.find(e => e.name === name) ?? root.get(name);
        return {
            dim: t.dim,
            mid: t.mid,
            bright: t.bright,
            alarm: t.alarm
        };
    }

    // Whether a switch is in flight. `theme-set` renders every template on the
    // machine and then fans a reload out to every app, so it takes long enough
    // to press twice, and two renders racing means the build that finishes
    // second wins whatever was asked for first.
    property bool switching: false

    // SWITCH THE MACHINE, not the shell.
    //
    // Nothing here writes config.json. The old picker put a name in it and the
    // shell re-dressed alone, which is exactly the disagreement this file
    // exists to end. `theme-set` re-renders every app's colours in one go and
    // the palette watch below brings the result back in, so the shell changes
    // colour as a CONSEQUENCE of the machine changing colour, in the same
    // breath as the terminal and the window borders.
    function apply(name: string): void {
        if (root.switching || name === root.activeName)
            return;

        if (!root.availableNames.includes(name)) {
            console.warn(`Themes: nothing on this machine renders a theme called ${name}.`);
            return;
        }

        root.switching = true;
        switcher.exec(["theme-set", name]);
    }

    // WHAT COUNTS AS A PALETTE.
    //
    // The renderer is a separate program on its own schedule, so its file is
    // input rather than truth. A ramp that is not eleven `#rrggbb` strings, or
    // an accent that is missing, means the file is from a template that has
    // moved on, and the literals are a better answer than a half-applied theme:
    // Appearance indexes the ramp by tier and interpolates BETWEEN stops, so a
    // short ramp is not a darker shell, it is the wrong colour everywhere.
    //
    // Returns the palette in the shape `rendered` binds to, or null.
    function normalise(raw: string): var {
        let p;
        try {
            p = JSON.parse(raw);
        } catch (e) {
            return null;
        }

        if (!p || typeof p !== "object")
            return null;

        const hex = /^#[0-9a-fA-F]{6}$/;
        const colour = v => typeof v === "string" && hex.test(v);

        if (!Array.isArray(p.ramp) || p.ramp.length !== root.slate.ramp.length || !p.ramp.every(colour))
            return null;
        if (!["dim", "mid", "bright", "alarm"].every(k => colour(p[k])))
            return null;

        return {
            name: typeof p.name === "string" && p.name.length > 0 ? p.name : "rendered",
            ramp: p.ramp.slice(),
            dim: p.dim,
            mid: p.mid,
            bright: p.bright,
            alarm: p.alarm
        };
    }

    // TAKE A READ, if it is a palette and if it says anything new.
    //
    // The equality check is not tidiness: `theme-reload` re-renders on demand
    // and a re-render that changed no colour would otherwise push a new object
    // through every colour binding in the shell for nothing.
    function adopt(raw: string): void {
        const next = root.normalise(raw);

        if (!next) {
            if (raw.length > 0)
                console.warn(`Themes: ${root.palettePath} is not a palette, wearing the literals instead.`);
            root.parsed = null;
            return;
        }

        if (JSON.stringify(next) !== JSON.stringify(root.parsed))
            root.parsed = next;
    }

    // WHAT COUNTS AS AN INDEX.
    //
    // The same discipline `normalise` applies to the palette, for the same
    // reason: another program's output on another program's schedule is input,
    // not truth. An entry without a name and four `#rrggbb` accents is dropped
    // rather than drawn, because a swatch is a claim about what a theme looks
    // like and a black chip is a false one. An index with nothing left in it is
    // not an index, which puts the picker back on the literals instead of
    // leaving it with a card and no rows.
    //
    // Returns the list `catalogue` binds to, or null.
    function normaliseCatalogue(raw: string): var {
        let list;
        try {
            list = JSON.parse(raw);
        } catch (e) {
            return null;
        }

        if (!Array.isArray(list))
            return null;

        const hex = /^#[0-9a-fA-F]{6}$/;
        const colour = v => typeof v === "string" && hex.test(v);
        const named = t => t && typeof t === "object" && typeof t.name === "string" && t.name.length > 0;

        const kept = list.filter(t => named(t) && ["dim", "mid", "bright", "alarm"].every(k => colour(t[k]))).map(t => ({
                    name: t.name,
                    dim: t.dim,
                    mid: t.mid,
                    bright: t.bright,
                    alarm: t.alarm
                }));

        return kept.length > 0 ? kept : null;
    }

    // Take a read of the index, if it is one and if it says anything new. The
    // equality check is the same bargain adopt() makes: a re-render that added
    // no theme must not hand the picker a fresh array and make it rebuild every
    // row it already has.
    function adoptCatalogue(raw: string): void {
        const next = root.normaliseCatalogue(raw);

        if (!next) {
            if (raw.length > 0)
                console.warn(`Themes: ${root.cataloguePath} is not a theme index, the picker is listing the literals instead.`);
            root.indexed = null;
            return;
        }

        if (JSON.stringify(next) !== JSON.stringify(root.indexed))
            root.indexed = next;
    }

    // The first read decides what the first frame looks like, and the automatic
    // one is async: the shell would paint itself in the fallback and repaint a
    // frame later. `blockLoading` plus this line make it a blocking read of 800
    // bytes off local disk before anything is drawn.
    Component.onCompleted: root.adopt(file.text())

    // THE RENDERER'S PALETTE, WEARING THE THEME INTERFACE.
    //
    // ONE object, whose properties are bindings, rather than a fresh Theme per
    // reload. Appearance holds whatever `get()` handed it and keeps holding it,
    // so replacing the object would leave every consumer pointing at the
    // palette that was just superseded. Rebinding this one's properties is what
    // makes a theme switch arrive downstream at all.
    readonly property Theme rendered: Theme {
        readonly property var p: root.parsed

        name: p ? p.name : root.slate.name
        ramp: p ? p.ramp : root.slate.ramp
        dim: p ? p.dim : root.slate.dim
        mid: p ? p.mid : root.slate.mid
        bright: p ? p.bright : root.slate.bright
        alarm: p ? p.alarm : root.slate.alarm
    }

    // THE PALETTE FILE, WATCHED, so a theme switch lands live and no restart is
    // part of changing colour.
    //
    // `watchChanges` catches an edit in place and an atomic rename onto the
    // path. What theme-set does is neither: it renders into a NEW build
    // directory and points the `current` symlink at it, and the watch resolved
    // that symlink when it was armed, so it is left on a file nobody will ever
    // write again. What rescues it is the line after the swap, where theme-set
    // deletes the build it replaced: the watched file DISAPPEARING is an event
    // too, and the reload it triggers re-resolves `current` and finds the new
    // palette. Verified against three consecutive switches rather than assumed,
    // because the alternative was a shell that took the first theme change of a
    // session and ignored every one after it.
    FileView {
        id: file

        path: root.palettePath
        watchChanges: true
        printErrors: false
        blockLoading: true

        onFileChanged: {
            root.retries = 0;
            file.reload();
        }

        onLoaded: {
            root.retries = 0;
            root.adopt(file.text());
            // A palette that just read cleanly is the proof that the new build
            // directory is there, and the index lives in it, written by the
            // same render. That is the index's entire recovery from a swap it
            // lost: see its own FileView below.
            index.reload();
        }

        onLoadFailed: err => {
            // Nearly always the swap itself: the old build is gone, the symlink
            // has moved, and this read landed between the two, so the answer is
            // to ask again rather than to believe it. `settle` slows itself
            // down once the fast attempts are spent, which is the difference
            // between chasing a race and waiting out a machine that has no
            // renderer on it yet.
            root.retries++;
            settle.restart();

            if (root.retries === root.rapidRetries)
                console.warn(`Themes: cannot read ${root.palettePath}, wearing the literals and watching for it.`);
        }
    }

    // THE RETRY, at two speeds and never off.
    //
    // Fast while a swap could still be in flight, because that outage is
    // measured in milliseconds and the shell is wearing the wrong palette for
    // every one of them. Slow afterwards, because the same failure also means
    // "this machine has no rendered theme", which can last the whole session
    // and must cost nothing. It is one open of one small file a minute, and it
    // is what lets a shell that started before the renderer did pick the
    // palette up by itself instead of waiting for a restart nobody knows to do.
    Timer {
        id: settle

        interval: root.retries < root.rapidRetries ? 250 : 30000
        onTriggered: file.reload()
    }

    // THE INDEX, WATCHED, so a theme added to ~/.config/theme/themes shows up
    // in the picker without a restart.
    //
    // The same symlink caveat the palette has, rescued the same way: this watch
    // is armed on the file `current` resolved to when it was set up, a switch
    // points that symlink at a new build, and what re-arms the watch is
    // theme-set DELETING the build it replaced. The disappearance is an event
    // too, and the reload it triggers re-resolves `current`.
    //
    // `preload` is not optional here and is the difference between this working
    // and this silently doing nothing. A FileView reads when something asks it
    // to, and the palette's asking is the blocking `text()` in
    // Component.onCompleted; nothing asks for the index, because the picker
    // reads a property rather than a file. Without preload the read never
    // happens, so the watch is never armed either, and the whole card quietly
    // falls back to the literals.
    //
    // Preloaded but NOT blocking, unlike the palette, and with no retry ladder
    // of its own. Nothing in the first frame is drawn from this list, so a read
    // that cost the shell its first paint would buy nothing. A failed read
    // keeps the last good list rather than emptying the card, and the palette's
    // recovery above is what asks again, so a machine whose renderer is too old
    // to publish an index costs one failed open per theme switch rather than a
    // timer that never stops.
    FileView {
        id: index

        path: root.cataloguePath
        preload: true
        watchChanges: true
        printErrors: false

        onFileChanged: index.reload()
        onLoaded: root.adoptCatalogue(index.text())
    }

    // THE SWITCH ITSELF, as Process plus exec: the one-shot idiom the rest of
    // the shell already uses for a command it asks once and waits on
    // (SettingsCorner's hyprctl probe, Compositor's border push). theme-set
    // exits when the machine has been re-dressed, so its exit is the moment
    // another switch may be offered.
    //
    // By the name on PATH rather than the script behind it: `theme-set` is this
    // machine's interface to its own colours, and reaching past it to wherever
    // the file happens to live would tie the shell to a path it does not own.
    Process {
        id: switcher

        onExited: (code, status) => {
            root.switching = false;
            if (code !== 0)
                console.warn(`Themes: theme-set exited ${code}, so the machine kept the theme it had.`);
        }

        // theme-set names the theme it rendered on stdout, which every window
        // on the screen has already said by the time it is read. The complaint
        // on stderr is the half worth a line in the log.
        stderr: StdioCollector {
            onStreamFinished: {
                const said = text.trim();
                if (said.length > 0)
                    console.warn(`Themes: theme-set said: ${said}`);
            }
        }
    }

    // A ramp climbing from near-black to near-white in one hue family, plus the
    // saturated end. Eleven stops so widgets can pick a tier rather than nudging
    // a hex value: `ramp[0]` is the darkest, `ramp[10]` the lightest.
    component Theme: QtObject {
        required property string name
        required property var ramp     // 11 colours, dark -> light
        required property color dim    // saturated, quietest
        required property color mid    // saturated, standard
        required property color bright // saturated, the specular spike

        // The one colour OUTSIDE the theme's hue family, for something about to
        // be taken away. A second green cannot say that; the accent is already
        // spent on ordinary attention.
        required property color alarm
    }

    // ---------------------------------------------------------------- fallback
    //
    // FROM HERE DOWN IS THE COLD START, and nothing else. These two are what
    // the shell wears before palette.json has been read and if it never can be.
    // They are kept literal on purpose: a fallback that had to read a file
    // would have the same failure as the thing it is covering for.

    // Cool anodised-green metal. Kept in step with
    // ~/.config/hypr/theme/greensteel.conf: same names, same values, so the
    // shell and the compositor's window borders are one object.
    readonly property Theme greensteel: Theme {
        name: "greensteel"
        //     void      abyss     dark      plate     body      brushed
        ramp: ["#070c0a", "#0d1512", "#16211c", "#1b2a23", "#22322b", "#33493f",
            //  edge      lit       pale      silver    chrome
            "#4c6b5c", "#6e9384", "#9dbdaf", "#c9e2d7", "#eaf6f0"]
        dim: "#3fbf8f"      // verdigris
        mid: "#5fd99a"      // lush
        bright: "#8cffc0"   // phosphor
        // Orange, not red: red and green are the pair a colour blindness
        // flattens, and this must never read as the accent.
        alarm: "#ff6b3d"    // flare
    }

    // The same metal with the green taken out. Also the shape every rendered
    // palette is measured against: `normalise` takes its ramp length as the
    // number of stops a palette owes the shell.
    readonly property Theme slate: Theme {
        name: "slate"
        ramp: ["#08090b", "#0f1114", "#181b1f", "#1d2126", "#262b31", "#3a4149",
            "#545d67", "#78838f", "#a5aeb8", "#d0d7dd", "#eef2f5"]
        dim: "#5b8fb0"
        mid: "#7fb3d4"
        bright: "#b8dcf0"
        alarm: "#ff7a4d"    // ember
    }
}
