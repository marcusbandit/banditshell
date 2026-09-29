pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// What the compositor says about itself, and the one thing the shell says
// back: the theme, onto the window borders. See the push section at the end.
//
// This lives in config/ rather than services/ because it is a SOURCE OF
// SETTINGS, exactly like config.json: Appearance reads it to answer "how round
// is a corner here". Services are for live state that widgets react to; this is
// read once at startup and on demand.
//
// The point: the shell should not need to be told the rounding twice. If
// Hyprland says `rounding = 15, rounding_power = 4.0, gaps_out = 10`, the shell
// should already agree, and should keep agreeing when those change.
Singleton {
    id: root

    readonly property bool isHyprland: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") !== ""
    readonly property bool isNiri: Quickshell.env("NIRI_SOCKET") !== ""

    readonly property string name: isHyprland ? "hyprland" : isNiri ? "niri" : "unknown"

    // False until we have actually read something, so Appearance can fall back
    // to config.json instead of rendering with zeros for a frame.
    property bool available: false

    property real rounding: 0
    // The superellipse exponent: |x|^p + |y|^p = r^p. p = 2 is a plain circular
    // arc; higher is squarer and smoother.
    property real roundingPower: 2
    property real gapsOut: 0
    property real gapsIn: 0
    property real borderSize: 0

    // NATURAL SCROLLING, per device kind, which is not a look and is here anyway.
    //
    // Content scrolls; a control is pushed. The shell has both, and the second
    // kind has to know which way a finger actually moved, because natural
    // scrolling has already flipped the event before it arrives. The compositor
    // is the only thing that knows the setting, and it is the same argument as
    // the rounding: do not make the user say it twice.
    property bool naturalScrollMouse: false
    property bool naturalScrollTouchpad: false

    function refresh(): void {
        if (isHyprland)
            hyprctl.running = true;
        else if (isNiri)
            niriConfig.reload();
    }

    Component.onCompleted: {
        refresh();
        // For the case where the parser probe had already answered by the time
        // this singleton loaded; when it has not, onParserKnownChanged below is
        // what pushes. The same pair Settings keeps for its window rules.
        pushBorderColours();
        // And the same pair boots bare: if the flag is already on and the
        // parser already known, nothing else would fire.
        if (root.bare)
            root.applyBare();
    }

    // Hyprland ------------------------------------------------------------
    //
    // One call for all five options: spawning five processes to read five
    // integers would be silly, and `getoption` only takes one option at a time,
    // so this is `--batch`. Each answer puts its value under a key named after
    // its type, and gaps are a STRING of up to four numbers, so take the first.
    //
    // Which key that string arrives under is a moving target: Hyprland filed it
    // as `custom` until 0.56 and as `css` after. Reading only the old name did
    // not fail, it fell through to a default of zero, so the chassis band became
    // no band at all and the shell looked like it had simply stopped drawing one.
    // An answer this file cannot read is dropped now instead of defaulted, which
    // trips the count below, logs, and hands the numbers back to config.json.
    Process {
        id: hyprctl

        command: ["hyprctl", "-j", "--batch", "getoption decoration:rounding ; getoption decoration:rounding_power ; getoption general:gaps_out ; getoption general:gaps_in ; getoption general:border_size ; getoption input:natural_scroll ; getoption input:touchpad:natural_scroll"]

        stdout: StdioCollector {
            onStreamFinished: {
                const nums = text.split("\n").filter(l => l.trim().startsWith("{")).map(line => {
                    try {
                        const o = JSON.parse(line);
                        const many = o.custom ?? o.css;
                        if (many !== undefined)
                            return parseFloat(String(many).trim().split(/\s+/)[0]);
                        // As a NUMBER, including the flags: everything below
                        // reads this array positionally and compares against 0,
                        // so a bool has to arrive as one or the other rather
                        // than as a third kind of thing.
                        if (o.bool !== undefined)
                            return o.bool ? 1 : 0;
                        return o.float ?? o.int ?? null;
                    } catch (e) {
                        return null;
                    }
                }).filter(v => v !== null);

                if (nums.length < 5)
                    return console.warn("Compositor: could not read Hyprland options, keeping config.json values.");

                root.rounding = nums[0];
                root.roundingPower = nums[1];
                root.gapsOut = nums[2];
                root.gapsIn = nums[3];
                root.borderSize = nums[4];
                root.available = true;

                // Appended after the geometry, so a Hyprland too old to know
                // these options still hands over the five that gate `available`
                // and only the scroll flags fall back to false.
                if (nums.length > 5)
                    root.naturalScrollMouse = nums[5] !== 0;
                if (nums.length > 6)
                    root.naturalScrollTouchpad = nums[6] !== 0;
            }
        }
    }

    // niri ----------------------------------------------------------------
    //
    // niri has no IPC call for layout settings, so the config file is the only
    // source. Scraped rather than parsed: KDL is a real grammar and this only
    // needs two numbers. If the scrape misses, `available` stays false and
    // config.json wins, which is the correct failure.
    FileView {
        id: niriConfig

        path: `${Quickshell.env("HOME")}/.config/niri/config.kdl`
        printErrors: false

        onLoaded: {
            const src = text();
            const gaps = src.match(/^\s*gaps\s+(\d+(?:\.\d+)?)/m);
            const radius = src.match(/geometry-corner-radius\s+(\d+(?:\.\d+)?)/);

            if (!gaps && !radius)
                return;

            root.gapsOut = gaps ? parseFloat(gaps[1]) : root.gapsOut;
            root.gapsIn = root.gapsOut;
            root.rounding = radius ? parseFloat(radius[1]) : root.rounding;
            // niri draws plain circular corners, so no smoothing to inherit.
            root.roundingPower = 2;
            root.available = true;
        }
    }

    // The theme, pushed back ----------------------------------------------
    //
    // Everything above is the compositor telling the shell what it looks like.
    // This is the one thing that flows the OTHER way: when the theme changes,
    // the window border colours go to Hyprland, so choosing "slate" recolours
    // the desktop itself and not just the panels drawn over it.
    //
    // It is also the one place config/ reaches into services/ (the qs.services
    // import above). The push has to speak whichever dialect the compositor
    // answers to, and Hypr owns the probe that learned it; duplicating that
    // probe here so the layering stayed pretty would be two processes asking
    // the compositor the same question at every startup.
    //
    // Deliberately NOT gated on `compositor.follow`. Follow governs geometry
    // the compositor owns: rounding and gaps are the compositor's decision and
    // the shell agrees with it. A border's COLOUR is the theme's, and the theme
    // is the shell's to declare, so this direction gets its own switch rather
    // than borrowing one that answers the opposite question.
    //
    // The switch exists for the user whose hyprland.conf paints borders
    // deliberately: the machine's theme conf draws a five-stop specular
    // sweep, and a flat accent is a downgrade to whoever made that. `?? true`
    // because the push is the behaviour that was asked for
    // by name; a config.json from before the key existed should mean yes, not
    // a silent no. Turning it OFF does not repaint the file's own colours back,
    // because the shell never knew them; the compositor's next config reload
    // restores them, and always was the only thing that did.
    readonly property bool pushBorders: Appearance.cfg.compositor.pushBorders ?? true

    // The focused window wears the accent. "Which window has the keyboard" is
    // exactly the kind of state the accent is reserved for, and it is the same
    // colour the sidebar already spends on "which workspace you are on".
    readonly property color activeBorder: Appearance.colour.accent

    // Unfocused windows wear the shell's faint outline: the separator,
    // FLATTENED over the solid surface colour. Two rejected spellings, one per
    // half. Pushing the separator with its own alpha would hand a 0.1-alpha
    // veil to a compositor that composites borders over the WALLPAPER, not
    // over the shell's material, so the line would all but vanish on a bright
    // picture and take its colour from whatever it crossed. And naming a raw
    // ramp stop would be a magic index pretending to be a decision, when the
    // separator token already says "faint outline" and moves with the theme's
    // material settings. Flattening one over the other reproduces what a faint
    // line on a panel actually looks like, as one opaque colour the compositor
    // cannot composite wrong. (Next to a hand-picked inactive stop in the
    // user's own hyprland theme conf this lands a step away, which is the
    // derivation agreeing with taste.)
    readonly property color inactiveBorder: {
        const line = Appearance.colour.separator;
        const ground = Appearance.colour.surfaceSolid;
        const over = (a, b, t) => a + (b - a) * t;
        return Qt.rgba(over(ground.r, line.r, line.a), over(ground.g, line.g, line.a), over(ground.b, line.b, line.a), 1);
    }

    // The RESOLVED colours are watched, never the theme's name: a palette
    // edited live in Themes.qml, a different accent tier, a moved surface stop
    // all change these two properties, and a rename that changes no colour
    // says nothing. Qt.callLater because a theme swap changes both in the same
    // tick, and two hyprctl processes saying the same sentence is one too
    // many; callLater coalesces the pair into one push.
    onActiveBorderChanged: Qt.callLater(root.pushBorderColours)
    onInactiveBorderChanged: Qt.callLater(root.pushBorderColours)
    // Flipping the switch on pushes immediately rather than waiting for the
    // next theme change, so the setting answers the moment it is touched.
    onPushBordersChanged: Qt.callLater(root.pushBorderColours)

    // One colour channel as two hex digits. Both dialect spellings below are
    // assembled from CHANNELS, never sliced out of Qt's own string: Qt spells
    // a colour "#AARRGGBB" with the alpha pair FIRST, and drops that pair
    // entirely when the alpha is ff, so any slice offset depends on the value
    // it was meant to be reading. Channels read as numbers cannot be surprised.
    function channelHex(v: real): string {
        const n = Math.round(v * 255);
        return (n < 16 ? "0" : "") + n.toString(16);
    }

    // Both parser dialects, exactly as Settings.installRules: which one is
    // right is a fact about the Hyprland that happens to be running rather
    // than a decision this shell gets to make.
    //
    // The legacy parser takes `keyword general:col.active_border` with the
    // colour spelled rgba(RRGGBBAA), alpha LAST. The Lua parser refuses
    // `keyword` outright ("keyword can't work with non-legacy parsers"), and
    // its `hl.config` takes one nested table in which a border colour is a
    // GRADIENT, `{ colors = {...}, angle }`, each stop spelled "0xAARRGGBB",
    // alpha FIRST. Handing it the legacy string instead is not accepted:
    // `rgba(...) rgba(...) 45deg` comes back as `invalid color`, which was
    // found by trying it against a live 0.56, not by reading anything. A flat
    // colour is a one-stop gradient with no angle worth naming.
    function pushBorderColours(): void {
        // parserKnown, not just isHyprland: `lua` reads false while the probe
        // is still in flight, and false is also a real answer. See Hypr.
        if (!root.isHyprland || !root.pushBorders || !Hypr.parserKnown)
            return;

        const active = root.activeBorder;
        const inactive = root.inactiveBorder;

        if (Hypr.lua) {
            const stop = c => `"0x${root.channelHex(c.a)}${root.channelHex(c.r)}${root.channelHex(c.g)}${root.channelHex(c.b)}"`;
            pusher.exec(["hyprctl", "eval", `hl.config({ general = { col = { active_border = { colors = { ${stop(active)} } }, inactive_border = { colors = { ${stop(inactive)} } } } } })`]);
            return;
        }

        const stop = c => `rgba(${root.channelHex(c.r)}${root.channelHex(c.g)}${root.channelHex(c.b)}${root.channelHex(c.a)})`;
        pusher.exec(["hyprctl", "--batch", `keyword general:col.active_border ${stop(active)} ; keyword general:col.inactive_border ${stop(inactive)}`]);
    }

    Connections {
        target: Hypr

        // A config reload re-applies the user's own file over anything set by
        // keyword or hl.config, the borders included, so the theme has to say
        // itself again. Same contract as Settings' window rules. And while
        // bare the reload also brought the gaps and the rounding back, so the
        // zeros go straight back out with the borders.
        //
        // AND REFRESH, which is the half this connection was missing: the
        // cache in here is read ONCE at boot and followed by every radius in
        // the shell, so a reload that changed the compositor's numbers - the
        // un-bare one, or the user's own hand in look.lua - left this file
        // agreeing with a world that no longer existed. Measured as every
        // tier in the shell stuck at zero after the first bare cycle: bare
        // wrote zeros, a hot reload read them, and nothing ever read again.
        // refresh() on reload is what makes following a living thing instead
        // of a boot-time photograph.
        function onConfigReloaded(): void {
            root.refresh();
            root.pushBorderColours();
            if (root.bare)
                root.applyBare();
        }

        // The compositor has just said which language it speaks. The colours
        // were known long before it did; this is the last thing the push was
        // waiting on. The same moment is the boot path for bare: the flag
        // landed with the shell's config before the parser had a name, and
        // this is where a machine booted bare finally gets squared and
        // flushed.
        function onParserKnownChanged(): void {
            root.pushBorderColours();
            if (root.bare)
                root.applyBare();
        }
    }

    // BARE, the compositor's half of the shell's master switch.
    //
    // `edge.bare` takes the chrome down, and the windows have to go with it:
    // flush to the screen edge (gaps_out 0) and square (rounding 0, which
    // empirically squares the windowrule-rounded ones too - the rule caps
    // against the global, so zeroing the global takes every window with it).
    // One eval, the same hl.config dialect the border colours speak, because
    // this machine's Lua parser refuses `keyword` outright; the legacy
    // spelling is kept for a machine that still speaks it.
    //
    // The way BACK is a reload, and deliberately not an eval of remembered
    // numbers: the user's lua owns gaps and rounding (look.lua's gap,
    // theme's bezel, the global-rounding window rule on top of that), and a
    // reload is the one operation that returns ALL of it to the file's truth
    // at once and re-triangulates every open window with it. Values stashed
    // at bare time go stale the day the file moves, and a shell that STARTED
    // bare never saw them at all - which is the reboot case, and the reason
    // this is applied here rather than in the bind: the flag lives in
    // config.json, the shell re-applies it on every boot and after every
    // reload, and bare survives a reboot half-applied no more.
    //
    // HELD, NOT SET AND FORGOTTEN: a reload at any moment - the user's hand,
    // HyprConfig's write chain - re-applies the file's values, so while bare
    // every reload is answered with the zeros again, the same contract
    // pushBorders runs on. The eval answers nothing back, so the hook fires
    // once per reload and there is no loop.
    readonly property bool bare: Appearance.bare

    function applyBare(): void {
        if (!root.isHyprland || !Hypr.parserKnown)
            return;
        if (Hypr.lua)
            pusher.exec(["hyprctl", "eval", "hl.config({ general = { gaps_out = 0 }, decoration = { rounding = 0 } })"]);
        else
            pusher.exec(["hyprctl", "--batch", "keyword general:gaps_out 0 ; keyword decoration:rounding 0"]);
    }

    // NOT on `bare` changing. A toggle writes the flag, the write hot-reloads
    // this tree, and the teardown eats this generation's in-flight eval -
    // measured as chrome down with the windows still rounded. The toggle's
    // compositor half therefore runs in the CLI wrapper, a plain process no
    // reload can kill; the call sites left here are the stable ones: boot,
    // parser known, and the reload-reassert below.

    Process {
        id: pusher

        // hyprctl exits 0 whether or not it liked the request, so the exit
        // code says nothing; a refusal is a line on stdout that is not `ok`.
        // The same collector Settings' ruler keeps, for the same reason.
        stdout: StdioCollector {
            onStreamFinished: {
                const complaints = text.split("\n").map(l => l.trim()).filter(l => l && l !== "ok");
                if (complaints.length > 0)
                    console.warn(`Compositor: the compositor refused a border colour: ${complaints.join("; ")}`);
            }
        }
    }
}
