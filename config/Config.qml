pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, backed by ~/.config/banditshell/config.json.
//
// Edit that file and the shell follows live, no restart. Delete it and it is
// written back from the defaults below. A settings menu will just call
// `Config.set("sidebar.width", 90)`; nothing else has to change for it to exist.
//
// `defaults` IS the schema. A key that is not in it is not a setting, and a key
// that is in it always resolves, so a half-written config.json still boots.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/.config/banditshell`
    readonly property string path: `${dir}/config.json`

    readonly property var defaults: ({
            // Name from Themes.qml. Try "slate".
            theme: "greensteel",

            // Every scale is a BASE and a list of multipliers. The list length is
            // the number of tiers, so the shell never hardcodes a size: it asks
            // for tier 0/1/2 and the maths does the rest.
            font: {
                family: "Monocraft",
                // Icons. Separate from the text face on purpose: swap this for a
                // pixel icon font when one exists and nothing else changes.
                icon: "Material Symbols Rounded",
                // Icons are not part of the text hierarchy, so they get their
                // own multiplier on the base rather than a fourth text tier.
                // The icon font's optical-size axis starts at 20, so the result
                // is clamped there rather than being allowed below it.
                iconScale: 1.1,

                // NINE. Not a taste decision: it is the font's own pixel.
                //
                // Monocraft has unitsPerEm 1080 and every metric on a 120-unit
                // grid, so one design pixel is 120 units and the em is exactly 9
                // of them. Cap height 840, x-height 600, advance 720: all whole
                // pixels. 1440 of its 1468 glyphs sit entirely on that grid.
                //
                // Rendering it at any size that is not a multiple of 9 puts the
                // whole font between pixels, which is precisely what a pixel
                // font must not be, and NativeRendering cannot save an off-grid
                // size. The previous 16 was the worst of the three: even the
                // character advance came out fractional at 10.67px, so glyphs
                // did not start on pixel boundaries either.
                //
                // So the scale is integer multiples, 1x/2x/3x, and cannot be a
                // ratio of anyone's choosing. 18 is fully crisp; 9 and 27 leave
                // f, i, k, l and t on a half-pixel, which is the whole cost.
                base: 9,
                scale: [1, 2, 3]
            },

            // Material.
            //
            // Panels are a translucent material that the compositor blurs, not a
            // painted colour, and everything ON them is the palette's light end
            // at an opacity tier. That is the whole system: depth comes from
            // transparency and layering, never from bevels, gradients or
            // engraved lines, which read as cheap.
            material: {
                // Opacity of a panel.
                //
                // 0.72 looked fine and failed over a LIGHT wallpaper: secondary
                // label came out at 3.14:1 against white where WCAG wants 4.5,
                // and the accent at 2.59:1 where SC 1.4.11 wants 3. Over a dark
                // wallpaper the same tokens pass comfortably, which is exactly
                // why it went unnoticed. Apple's rule for text-heavy surfaces is
                // a thicker material, and this is that.
                surfaceAlpha: 0.88,

                // Label tiers: primary, secondary, tertiary, quaternary.
                // Modelled on macOS dark mode's NSColor label ladder
                // (0.847 / 0.549 / 0.247 / 0.098), run a little hotter because
                // this surface is translucent.
                label: [0.92, 0.58, 0.32, 0.16],

                // Fills: container, hover, selected.
                //
                // Apple's whole fill range is 0.070 to 0.145 and Material's
                // state layers are additive: a 0.07 container plus an 0.08 hover
                // is 0.145, which is exactly Apple's systemFill. Hover at 0.12
                // was only a 1.18:1 step above the container and barely read.
                fill: [0.07, 0.145, 0.18],

                // macOS separatorColor in dark mode is white at 0.098.
                separator: 0.1,

                // The accent, used as a FILL rather than as a label: for tinting
                // a surface the way the fills above do, but with the theme's
                // colour in it. Kept near a fill's weight on purpose. It goes
                // over one of them, not instead of it, so the surface reads as
                // thicker glass with colour in it rather than as a stain.
                accentFill: 0.2
            },
            // Take rounding, corner smoothing and the edge gap from the running
            // compositor instead of the values below, so the shell agrees with
            // the windows without being told twice. Hyprland and niri.
            // Falls back to the manual values if the compositor can't be read.
            compositor: {
                follow: true
            },

            rounding: {
                // Ignored while compositor.follow finds a compositor.
                base: 15,
                // 9 / 15 / 24, all on the 3px lattice. 0.55 gave 8.
                scale: [0.6, 1.0, 1.6],
                // Corner smoothing for VECTOR shapes: 0 = plain circular arc,
                // 0.6 = iOS squircle, 1 = maximum. Anything above 0 is G2.
                smoothing: 0.6,
                // Corner exponent for the chassis field. 2 = circular, which is
                // what Hyprland actually renders here regardless of what its
                // `rounding_power` says. Raise it only if the windows visibly
                // become squarer.
                power: 2.0
            },
            padding: {
                // 6 / 12 / 18 / 30, sharing the factor 6 with the 9px type grid
                // and its 12/24/36 line boxes. The previous 6/10/18/30 had only
                // one value on the lattice, which is a coincidence rather than a
                // grid.
                base: 6,
                scale: [1, 2, 3, 5]
            },
            anim: {
                base: 220,
                scale: [0.68, 1.0, 1.45],
                // Exponential-smoothing rate for things that track a target.
                // Higher is snappier.
                trackSpeed: 14,
                // Same, for a panel opening or closing.
                revealSpeed: 18,
                // Same, for a panel taking the size of content that changed
                // under it. Deliberately the same rate as trackSpeed by
                // default: a menu that slides and resizes at once is one
                // object changing shape, and its edges only read that way
                // while both motions decay together. Separate so the shape
                // change can be tuned without touching how things follow.
                resizeSpeed: 14,
                // Same, for a list gliding to where the wheel threw it. Lower
                // than the others on purpose: this is the one place the motion
                // is meant to be FELT rather than merely be over.
                scrollSpeed: 11,
                // How long a hover-opened thing survives the cursor leaving.
                // Hover is a sloppy input; without this, crossing a boundary
                // dismisses what you were reaching for.
                grace: 180
            },

            // Which stop of the theme's ramp each role uses. The ramp runs 0
            // (darkest) to 10 (lightest), so these are portable across themes:
            // a new palette supplies colours, not decisions.
            colour: {
                // Which stop the panel material is tinted with. High enough that
                // the theme still reads through the translucency: too low and a
                // frosted panel is just grey, which is nobody's palette.
                surface: 3,
                // Which saturated colour is "the accent": dim, mid or bright.
                accent: "mid"
            },

            edge: {
                // Width of the invisible interaction ring. Ignored while
                // compositor.follow is finding gaps_out.
                border: 10,

                // Draw the frame: a band around the whole screen as thick as the
                // compositor's outer gap, plus black pieces rounding off the
                // physical screen corners.
                //
                // The outer radius is not a setting: it is the window radius
                // plus the band thickness, because concentric is the only value
                // that looks right. `outerExtra` nudges it if that is ever wrong.
                roundOuter: true,
                outerExtra: 0,
                // Colour outside the frame. Black is the point, but it is a setting.
                outerColour: "#000000"
            },

            sidebar: {
                // Roughly caelestia's bar width. A vertical bar wants to be
                // narrow: it is peripheral, and width is the main thing that
                // makes one feel heavy.
                width: 52,
                // Rounding tier used for the concave corners that meet the
                // frame's inner edge.
                flareTier: 2,
                workspaces: {
                    // Slots always shown, even when empty.
                    persistent: 5,
                    slot: 28,
                    // Wider than the gap INSIDE a slot, which is what makes a
                    // workspace holding three windows read as one group rather
                    // than as three workspaces. Grouping is carried entirely by
                    // this ratio, so it is the one number to change if the
                    // column ever reads as a flat list.
                    gap: 12,
                    // Rows of window icons a slot draws before the rest
                    // collapse into one "and more" mark. A cap, not a limit on
                    // what you can open: without it a workspace with twenty
                    // windows would push the column off the screen.
                    maxWindows: 4,
                    // Pitch of those rows, as a multiple of the icon size, so
                    // the stack stays proportional if the icons are resized.
                    // At 1 the glyphs stack with only their own built-in
                    // margin between them, which is the point: inside a slot
                    // should be visibly tighter than between slots.
                    windowPitch: 1.0,

                    // THE RULER. Every workspace keeps a tick hard against the
                    // screen's edge, as long as the workspace is tall, and the
                    // one you are on grows a tab out of that edge.
                    //
                    // Width of the bright mark on the edge of the active plate.
                    tick: 3,
                    // How far a plate reaches in, as a fraction of the bar's
                    // width. The active one is always the whole width, so these
                    // are the other two states: a workspace with nothing on it,
                    // and one with windows. Fractions rather than pixels, so the
                    // three lengths keep their proportions if the bar changes.
                    stubReach: 0.28,
                    fullReach: 0.78
                },
                status: {
                    slot: 28,
                    gap: 4
                }
            },

            wallpaper: {
                dir: "~/Pictures/Wallpapers",
                current: "~/Pictures/Wallpapers/shaded_landscape.png"
            },

            // How the shell's body melts together. See components/blob/blob.frag.
            blob: {
                // Width of the blend where a panel meets the body, in pixels.
                // 0 gives a hard crease; too high and everything looks inflated.
                melt: 34,
                // Multiplier on the antialiased edge width.
                feather: 1.0
            },

            picker: {
                dir: "~/Pictures/Screenshots",
                // What opens a non-clipboard capture.
                editor: "swappy -f",
                outline: 2
            },

            launcher: {
                width: 920,
                // How present an app's icon is. Bigger than a menu's glyph on
                // purpose: a launcher is a list you scan by icon, and the row
                // grows to suit.
                iconSize: 44,
                // How fast a launch stops counting. Each one is worth 1 when it
                // happens and half that after this many days, so the order
                // follows what you use NOW rather than what you used once.
                halfLifeDays: 14,
                // How long to keep watching for the window a launch opens, so
                // it can be given the pointer as well as the keyboard.
                claimMs: 15000
            },

            notifications: {
                // How long a popup stays when the sender does not say. Critical
                // ones ignore this and stay until acted on.
                timeout: 5000,
                // On screen at once. Beyond this the oldest popup goes; they are
                // all still in the hub.
                maxPopups: 4,
                // Kept in the hub. A hub showing three hundred is a log.
                maxHistory: 50,
                width: 340,
                badge: 36,
                // How far the summon zone runs along each edge from the
                // top-right corner. Only as thick as the band, because a screen
                // corner cannot be overshot.
                cornerZone: 120
            },

            // Controls inside menus.
            control: {
                // WCAG 2.2 SC 2.5.8 Target Size (Minimum), AA.
                minTarget: 24,

                // How far one notch of the wheel throws a list, in rows.
                wheelRows: 3,
                // How long a touchpad flick keeps going after the fingers
                // leave, in ms of the velocity it ended at. This is the coast:
                // 0 stops dead the instant you let go.
                coastMs: 190,

                // DRAG BEFORE CLICK. How far a thing has to be thrown, as a
                // fraction of its own width, before letting go dismisses it.
                // Short enough that a touchpad flick counts, long enough that a
                // stray nudge does not.
                dragDismissFraction: 0.2,
                // How much of your movement the card gives you BEFORE the commit
                // point. Below 1 the card resists, so the first fifth of the
                // throw feels like it is holding on; at the commit point it
                // breaks free and tracks you 1:1. That change of slope is the
                // whole signal: you can feel that letting go will now dismiss.
                dragResistance: 0.5,
                // Movement before a press becomes a drag. Qt's default is 10,
                // which is tuned for a mouse; a touchpad flick and a finger both
                // want to commit sooner.
                dragThreshold: 6,
                // How many rows a list menu shows before it says "+N more". A
                // street is eighty wifi networks and a menu that scrolls forever
                // is worse than one that admits what it left out.
                networkListMax: 7,
                deviceListMax: 7,
                // 40 is Sequoia's measured Control Center row pitch. At 34 a
                // two-line row (18px label + 9px detail, so 36px of line boxes)
                // was taller than its own row height and the list read as
                // cramped.
                rowHeight: 40,
                sliderHeight: 6,
                toggleWidth: 34,
                toggleHeight: 18
            },

            menu: {
                width: 300,
                // A menu is at least this tall and grows to fit its contents, up
                // to `maxHeight`. Fixed heights make a two-row menu look
                // abandoned and a ten-row one look cramped.
                //
                // Named minHeight, not height, because it used to BE a fixed
                // height. Reusing the name would have let every existing
                // config.json carry its old value into a key that now means
                // something else, which migration cannot detect: it compares
                // shape, and the shape would not have changed.
                minHeight: 200,
                maxHeight: 560
            }
        })

    property var values: defaults

    // Read one setting by dotted path, e.g. get("sidebar.width").
    function get(key: string): var {
        return key.split(".").reduce((node, k) => node?.[k], root.values);
    }

    // Write one setting by dotted path and persist it. This is the whole API a
    // settings menu needs.
    function set(key: string, value: var): void {
        const keys = key.split(".");
        const next = JSON.parse(JSON.stringify(root.values));

        let node = next;
        for (let i = 0; i < keys.length - 1; i++) {
            node = node[keys[i]];
            if (typeof node !== "object" || node === null)
                return console.warn(`Config: no such setting "${key}"`);
        }
        if (!(keys[keys.length - 1] in node))
            return console.warn(`Config: no such setting "${key}"`);

        node[keys[keys.length - 1]] = value;
        root.values = next;
        root.save();
    }

    function save(): void {
        file.setText(JSON.stringify(root.values, null, 4) + "\n");
    }

    // Overlay the user's file on the defaults, key by key, so a partial or
    // outdated config.json still yields a complete settings object.
    //
    // An array is one value, not a set to merge into: a scale of three
    // multipliers edited by the user must survive whole. But an array whose
    // LENGTH has changed in the defaults is a shape change, not a preference,
    // and keeping the old one silently leaves the new entries undefined. The
    // label ladder growing from three tiers to four did exactly that, and
    // undefined fed straight into a colour.
    function merge(base: var, over: var): var {
        if (Array.isArray(base))
            return Array.isArray(over) && over.length === base.length ? over : base;
        if (over === undefined || base === null || typeof base !== "object")
            return over === undefined ? base : over;

        const out = {};
        for (const k in base)
            out[k] = merge(base[k], over[k]);
        return out;
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            let parsed;
            try {
                parsed = JSON.parse(text());
            } catch (e) {
                return console.warn(`Config: ${root.path} is not valid JSON, keeping previous values.`, e);
            }

            root.values = root.merge(root.defaults, parsed);

            // If the SHAPE changed, write the file back.
            //
            // merge() already makes an outdated file work, and that is exactly
            // the trap: a setting added or removed in the defaults leaves the
            // file on disk stale, still readable, and quietly authoritative for
            // everything it does mention. Editing it then has no effect on the
            // new settings and the file disagrees with the shell about what
            // settings even exist. Values the user changed survive, because
            // merge keeps them; only the structure is brought up to date.
            if (JSON.stringify(root.values) !== JSON.stringify(parsed)) {
                console.log("Config: schema changed, updating config.json (your values are kept).");
                // Deferred: writing from inside the read's own completion
                // handler makes FileView drop the operation it is still
                // finishing.
                Qt.callLater(root.save);
            }
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                mkdir.running = true;
        }
    }

    // First run: make the directory, then write the defaults out so there is
    // something to edit.
    Process {
        id: mkdir
        command: ["mkdir", "-p", root.dir]
        onExited: root.save()
    }
}
