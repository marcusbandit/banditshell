pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, backed by ~/.config/banditshell/config.json.
//
// Edit that file and the shell follows live, no restart. Delete it and it is
// written back from the defaults below. The settings panel's pages just call
// `Config.set("theme", "slate")`; nothing else had to change for them to exist,
// which was the promise this file made back when they were hypothetical.
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

            // DRESS THE SHELL IN THE WALLPAPER'S OWN COLOURS instead of the
            // named palette above.
            //
            // THIS SWITCH DOES NOTHING YET, and it is here anyway rather than
            // being added on the day it works, because the half of it that IS
            // done is the half worth being able to look at: the wallpaper's
            // dominant colours are measured on every change and published on
            // the Wallpaper service (`banditshell wallpaper palette`, and the
            // swatches on the appearance page). What is missing is the whole
            // design question after the measurement, which is which of six
            // colours is a surface, which is an accent, and what happens when a
            // photograph offers nothing that clears 4.5:1 against anything else
            // in it. Turning this on today changes the value and not the shell.
            themeFromWallpaper: false,

            // Every scale is a BASE and a list of multipliers. The list length is
            // the number of tiers, so the shell never hardcodes a size: it asks
            // for tier 0/1/2 and the maths does the rest.
            font: {
                family: "Monocraft",
                // Icons. Separate from the text face on purpose: swap this for a
                // pixel icon font when one exists and nothing else changes.
                icon: "Material Symbols Rounded",
                // Per-application marks: the Nerd Fonts symbol face, which is
                // several thousand line glyphs drawn as one set, monochrome by
                // construction. `ttf-nerd-fonts-symbols`. Material Symbols has
                // no idea what Telegram is; this does, and still takes the
                // shell's own colour.
                brand: "Symbols Nerd Font",
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
                // So the scale is integer multiples and cannot be a ratio of
                // anyone's choosing. What it CAN be is which multiples, and 1x
                // was the mistake. At 9px the em is one device pixel per design
                // pixel, which sounds correct and lands a 5px x-height on a
                // 1920x1200 panel at scale 1. Every eyebrow in the shell was set
                // in it, and none of them could be read.
                //
                // There is nothing between 9 and 18 to retreat to: the grid has
                // no half-steps. So the small tier IS 18, and the hierarchy that
                // used to come from being smaller is carried by colour, case and
                // tracking instead, which carry it better anyway (see
                // ~/.claude/rules/type-scale.md).
                //
                // 2x/3x/4x. 18 and 36 are fully crisp; 27 leaves f, i, k, l and
                // t on a half-pixel, which is the whole cost.
                base: 9,
                scale: [2, 3, 4]
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
                follow: true,

                // And the one thing that flows the OTHER way: the theme's
                // border colours pushed OUT to Hyprland, so picking a theme
                // recolours the desktop and not only the panels drawn over it.
                // Its own switch rather than a second reading of `follow`,
                // because it answers the opposite question; config/Compositor.qml
                // owns that argument and the reason to turn it off (a
                // hyprland.conf that paints its borders deliberately).
                //
                // DECLARED HERE OR IT CANNOT BE SET AT ALL, which is why this
                // line exists at all: the switch was written and read and never
                // given a home. `set()` refuses a key that is not already in the
                // defaults, and `merge()` walks the DEFAULTS' keys, so a key
                // added to config.json by hand is dropped silently on load. A
                // documented escape hatch nobody can take is worse than none,
                // because the documentation says it is there.
                //
                // True, matching the `?? true` on the reading side: the push is
                // the behaviour asked for by name, so a config.json written
                // before this key existed means yes rather than a silent no.
                pushBorders: true
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
                // 6 / 12 / 24 / 36. The inner two are deliberately unchanged:
                // they set the space INSIDE a row, and a row's text did not get
                // bigger. The outer two did change, because the labels BETWEEN
                // sections doubled and the gaps that used to separate them
                // stopped being able to.
                //
                // 24 and 36 are the 18px tier's line box and half again, so a
                // section break is now an empty line rather than a number that
                // happens to look right.
                base: 6,
                scale: [1, 2, 4, 6]
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
                scrollSpeed: 15,
                // How long a hover-opened thing survives the cursor leaving.
                // Hover is a sloppy input; without this, crossing a boundary
                // dismisses what you were reaching for.
                grace: 180,
                // How long the cursor has to STAY on something before it gets
                // told what the something is. Long enough that crossing a column
                // of icons says nothing, short enough that stopping on one feels
                // answered rather than waited for.
                tooltip: 450,
                // How long two surfaces both draw the settings page while it
                // changes hands between the shell and a window. See
                // modules/settings/. Two frames at 60Hz.
                //
                // A gap here is a black flash; an overlap is nothing at all,
                // because both are drawing the same card in the same place. So
                // it errs long.
                handover: 32
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
                    // WHICH INDICATOR. Whole alternatives, not combinable
                    // settings; see modules/sidebar/Workspaces.qml.
                    //
                    //   plates   index tabs on the screen's edge, length as
                    //            state, a mark per window
                    //   map      no glyphs: each window is a bar as long as the
                    //            window is wide, so the column shows the shape
                    //            of the layout instead of its contents
                    //   blocks   one square per window, one row per workspace,
                    //            on the pixel grid
                    style: "plates",

                    // WHAT A WINDOW IS DRAWN AS.
                    //
                    //   brand    the Nerd Fonts mark for the application
                    //            itself: a line glyph from one set, in the
                    //            shell's colour, so Telegram looks like
                    //            Telegram and like it belongs here
                    //   colour   the application's own icon exactly as the icon
                    //            theme ships it, brand palette and all
                    //   glyph    what KIND of thing it is, and nothing about
                    //            which one: the Material Symbol for its
                    //            freedesktop category
                    //
                    // An override in `apps.icons` beats all three, and the
                    // category glyph is what any of them falls back to.
                    iconMode: "glyph",
                    // How much bigger a window's mark is here than an icon
                    // anywhere else in the shell. The sidebar is scanned at a
                    // glance and from the corner of the eye, which is not what
                    // an icon beside a menu label has to survive.
                    iconScale: 1.25,

                    // THE SCRATCHPAD RACK, in the order you want to read it.
                    //
                    // Special workspaces are named, not numbered, and Hyprland
                    // lists them in the order they were created: close Spotify,
                    // open it again, and it has moved past Discord. Name them
                    // here and each one is pinned to its place in the rack for
                    // good, and keeps that place while it is empty, so the rack
                    // is in the same order tomorrow as it is now and a scratchpad
                    // arriving does not shove the others along.
                    //
                    // Names WITHOUT the `special:` prefix, exactly as your
                    // `togglespecialworkspace` bind spells them. Anything not
                    // listed still appears, after these, in name order. Empty
                    // means all of them in name order and nothing reserved.
                    specials: [],

                    // Slots always shown, even when empty.
                    persistent: 5,
                    slot: 32,
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
                    // How far a plate reaches, as a fraction of the room it
                    // has: one with nothing on it, and one with windows. The
                    // active plate is always the whole span, which is what
                    // "pulled all the way out" means, so it has no setting.
                    //
                    // Fractions rather than pixels, so the lengths keep their
                    // proportions if the bar changes width.
                    emptyReach: 0.28,
                    busyReach: 0.62,
                    // How much more of everything a workspace gets while the
                    // cursor is on it: longer and taller by the same fraction,
                    // so the plate answers the cursor by moving rather than by
                    // changing colour at it.
                    hover: 0.09,

                    // `map`: how thick one window's bar is, and the gap under
                    // it. Thin, because the column is meant to be read as a
                    // shape rather than as a list of things.
                    mapBar: 5,
                    mapGap: 3,

                    // `blocks`: the grid. One square per window, and the gap
                    // that separates them from each other and from the next
                    // workspace's row.
                    block: 9,
                    blockGap: 3
                },
                status: {
                    slot: 29,
                    gap: 4
                },

                // THE TRAY: what is running without a window. Built to the
                // gauges' measurements, because the two groups are the same kind
                // of thing in the bar and a second set of numbers is how they
                // stop looking like it.
                tray: {
                    slot: 29,
                    gap: 4,
                    // How big the application's mark is inside that slot. Below
                    // the slot, so a busy icon has margin around it rather than
                    // touching its own hover fill.
                    iconScale: 1.0,
                    // A CAP, not a limit on what you may run. A tray is somebody
                    // else's list and has no upper bound; without this a session
                    // with fifteen background applications draws a column longer
                    // than the workspaces underneath it.
                    max: 8
                }
            },

            wallpaper: {
                // Whether the picture is drawn at all.
                //
                // Off is not "no wallpaper set": `current` keeps its path, the
                // file stays decoded, and the surface keeps standing there
                // painting the black it already paints behind the picture. So
                // turning it back on is a fade rather than a load, and the
                // desktop goes bare without the shell forgetting anything.
                //
                // The lock screen follows it, because a wallpaper turned off is
                // a wallpaper you do not want to see, and the lock's ground is
                // made of this same picture.
                enabled: true,
                dir: "~/Pictures/Wallpapers",
                current: "~/Pictures/Wallpapers/shaded_landscape.png",

                // A WALLPAPER THAT MOVES, and the one rule that makes one
                // affordable.
                //
                // GIFs and video play only while the workspace on that monitor
                // is EMPTY. A moving wallpaper behind a full screen of windows
                // is a decoder running for pixels nobody can see, which is the
                // whole of what makes animated wallpapers a bad idea on a
                // laptop; gated on an empty workspace it costs something only
                // in the moments you are actually looking at the desktop.
                //
                // Off, motion never runs and an animated wallpaper is its first
                // frame, which is a perfectly good still.
                animate: true,

                // HOW LONG A NEW WALLPAPER TAKES TO ARRIVE, in ms.
                //
                // Its own number rather than one of the shell's animation
                // tiers, and deliberately far longer than any of them: those
                // are tuned for a panel you asked for and are already looking
                // at, where anything you can watch is something in your way.
                // This is the whole screen changing underneath everything, and
                // it is the one motion in this shell that is meant to be
                // watched rather than merely be over. swww's own default is
                // about this.
                reveal: 900,

                // WHETHER A WALLPAPER MAY MAKE A NOISE. A video file carries an
                // audio track and an audio file is nothing but one, and this is
                // the switch that lets either out. Off, and off is the right
                // default by a wide margin: a desktop that makes noise at you
                // is a desktop you turn off within the hour. It exists because
                // the format list already had to decide what to do with a file
                // that has no picture in it, and "play it over black" was one
                // line more than refusing.
                audio: false
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

            // PER-APPLICATION ICON OVERRIDES, for when neither the icon theme
            // nor the app's freedesktop categories give the right mark.
            //
            // Keyed by a REGEX tested against the window class, case
            // insensitively; the value is a Material Symbols name, the same
            // names components/Icon.qml verifies exist. First match wins, in the
            // order written. An override beats everything, including the
            // application's own artwork.
            //
            //   "apps": { "icons": { "^zen$": "web", "kitty": "terminal" } }
            //
            // A map rather than a list because a list cannot be set from the
            // CLI: Quickshell's IPC reads a bracketed argument as an argument
            // LIST and splats it, so `banditshell set apps.icons '[...]'` never
            // arrives as an array. An object survives intact.
            apps: {
                icons: ({}),

                // How to ask Claude Code for an icon the machine does not have.
                // The prompt is appended as the last argument. Headless, and
                // allowed to write only because it has to save the file it
                // fetches; everything else about how it finds one is its
                // problem, which is the point of asking it rather than writing
                // a downloader in here.
                claude: ["claude", "-p", "--permission-mode", "acceptEdits"]
            },

            launcher: {
                width: 840,
                // How present an app's icon is. Bigger than a menu's glyph on
                // purpose: a launcher is a list you scan by icon, and the row
                // grows to suit.
                iconSize: 36,
                // How fast a launch stops counting. Each one is worth 1 when it
                // happens and half that after this many days, so the order
                // follows what you use NOW rather than what you used once.
                halfLifeDays: 14,

                // Which launcher is live: "list" or "niagara". Both are in the
                // tree; this decides which one the shell builds.
                concept: "list",

                // Applications PUT AWAY, keyed by desktop entry id.
                //
                // `NoDisplay` already removes the entries that admit they are
                // not applications, and it is not enough: every toolkit ships a
                // settings panel, every runtime an inspector, every font package
                // a viewer, and they all declare themselves perfectly launchable.
                // This is where you say otherwise. Nothing is lost, only filed:
                // the rail's last mark is everything in here, and putting one
                // back is the same gesture that put it away.
                //
                // A map rather than a list for the same reason `apps.icons` is
                // one: Quickshell's IPC reads a bracketed argument as an argument
                // LIST and splats it, so a list can never be set from the CLI.
                hidden: ({}),

                niagara: {
                    width: 760,
                    // How big an application's mark is in the column.
                    icon: 48,
                    // How wide the alphabet rail is. Narrow on purpose: it is a
                    // ruler, not a column of buttons.
                    rail: 44,
                    // How many of your most-used applications are on screen when
                    // nothing has been typed or scrubbed.
                    favourites: 7,
                    // How far the rail can be pulled toward the middle, and how
                    // many marks either side come with it. A CEILING, not a
                    // fixed depth: how far you actually pull is the gesture.
                    //
                    // The spread is the Gaussian's sigma IN MARKS, so it means
                    // the same thing whatever the alphabet turns out to contain.
                    // Narrow, the rail bent at one point and the letters two
                    // above and below it barely moved, which reads as a kink
                    // rather than as a line being drawn aside. Wide, most of the
                    // rail comes with the hand and the taper has nowhere it can
                    // be seen to start.
                    bow: 340,
                    bowSpread: 9,
                    // The disc that shows the mark you are on.
                    badge: 72,

                    // How long a row waits before it travels, in ms.
                    //
                    // The results themselves are never delayed: they follow the
                    // keyboard exactly, because a launcher that waits to tell you
                    // what it found is a launcher that feels slow. What waits is
                    // the MOTION. Every keystroke restarts this, so while your
                    // hands are moving nothing ever gets past the pause and the
                    // column simply holds still; stop for longer than this and it
                    // glides into place. Fades are not delayed at all, so the
                    // list is always saying the truth about what matches, even
                    // mid-burst.
                    //
                    // Long enough to sit inside the gap between two keystrokes of
                    // ordinary typing, short enough that a deliberate pause reads
                    // as immediate.
                    moveDelay: 80
                },

                // How long to keep watching for the window a launch opens, so
                // it can be given the pointer as well as the keyboard.
                claimMs: 15000
            },

            // The calendar's month gesture. See
            // modules/menu/content/CalendarMenu.qml.
            calendar: {
                // WHICH MONTH A RIGHTWARD SWIPE ASKS FOR, and the one setting
                // in this file that exists because two entirely reasonable
                // people read the same gesture in opposite directions. You are
                // expected to have an opinion about it; neither answer is a
                // bug, and nothing in here can settle it for you.
                //
                // FALSE is DIRECT MANIPULATION, and it is what almost every
                // other piece of software ships. The strip of months is a sheet
                // of paper under your fingers: push the paper to the right and
                // what was off its left edge, the EARLIER month, walks into
                // view, exactly as it would on a desk. Nothing about it is
                // arbitrary, the content simply goes where the hand puts it, and
                // it is the reading iOS, Android, every photo viewer and every
                // page of every book already agree on. It is a genuinely strong
                // default and it is the one being turned off here.
                //
                // TRUE is SWIPE FORWARD TO GO FORWARD, and it is the default
                // because it is the reading that was asked for by name: a swipe
                // to the right means LATER, the way a fast-forward arrow points
                // right and the way time runs left to right on every calendar
                // ever printed. The hand is not pushing the paper here, it is
                // pointing at where it wants to be, which is the same thing a
                // "next" button does with none of the paper's geometry in the
                // way.
                //
                // The two readings are each coherent all the way through: the
                // month sliding in under your fingers is always the month the
                // release lands on, whichever way round it is, because the
                // preview and the commit are the same number and not two
                // opinions (see CalendarMenu's advance()). So try it, and if
                // your hand disagrees with your sentence, which happens often
                // enough to be why the industry settled where it did, set this
                // false and the strip goes back to being paper.
                //
                // The ABSOLUTE routes never ask either way: the "Today" pill and
                // a tap on a dim neighbouring day both name the month they want
                // rather than a direction, so this cannot reach them.
                rightGoesForward: true
            },

            // The calendar's usage strip: how the shell remembers being used.
            usage: {
                // The day a bar fills at, in hours of the machine being awake.
                // The calendar draws duration as a bar with no numbers on it, so
                // something has to say what "full" means; ten hours is a long
                // day at a desk, and a cap rather than a scale because a bar
                // that kept growing would make every ordinary day look small.
                capHours: 10
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

                // Set from the TEXT COLUMN, not picked. Monocraft's advance is
                // two thirds of its size, so at the 18px body tier a character
                // is 12px and a column is worth exactly width/12 characters. The
                // card spends two padding tiers a side and the badge plus a
                // gutter, which is 100px, so 400 leaves 300: twenty-five
                // characters, where 340 left eighteen and turned every summary
                // in the shell into an ellipsis.
                //
                // 480 was the other way past it. There is no smaller text size
                // on this font's grid, so a pixel font can only be given width,
                // and past about 400 the tray stops being a corner and starts
                // being a column down the side of the screen.
                width: 400,
                // The app's own mark, at about a tenth of the card, which is
                // where Apple puts it. The glyph inside is half the plate.
                badge: 40,
                // How far the summon zone runs along each edge from the
                // top-right corner. Only as thick as the band, because a screen
                // corner cannot be overshot.
                cornerZone: 120
            },

            // The notch: the time, and under it whatever is playing.
            notch: {
                // How wide the track's line may get before it elides.
                //
                // Monocraft's advance is two thirds of its size, so at the 18px
                // body tier a character is 12px and this is twenty-four of them,
                // the same column a menu row gets and enough for every real
                // track name that is not a remix credit. Past about here the
                // notch stops being a notch and becomes a bar across the top of
                // the screen, which is the one thing this shell does not have.
                trackWidth: 288
            },

            // The right edge, as a volume rail.
            volume: {
                // What one notch of the wheel is worth. The same five points the
                // sound menu's slider moves by, because they are the same
                // gesture on the same value and a wheel that meant one thing on
                // the edge and another inside a menu would be two controls.
                step: 0.05,

                // HOW THICK THE METER IS, and now the only part of its size that
                // is a setting at all.
                //
                // Its LENGTH used to sit here as `railLength: 180`, and that
                // number was measured against a rail which ran nearly the whole
                // screen edge. The readout is a pill beside the band now, a
                // count of its own glyphs tall, derived from the icon it stands under
                // (modules/VolumeRail.qml): the meter follows the type scale
                // instead of having to be re-chosen every time the font base
                // moves. Left here it would have been a second and disagreeing
                // opinion about one shape, which is exactly how a stale magic
                // number goes on looking like a setting.
                //
                // SIXTEEN, and it went up from ten when the meter stopped being
                // a meter and became a control you put a finger on.
                //
                // Ten was chosen to read "as a stick rather than as a bar", and
                // that was the right thickness for a thing you only look at. A
                // stick is the wrong thickness for a thing you grab: it says
                // "reading" rather than "handle", and a track a finger cannot
                // see either side of gives the eye nothing to aim the finger at.
                // Sixteen is Material's own track, and it is what makes the gap
                // either side of the handle legible; below about twelve the gap
                // closes up and the handle stops reading as a separate object.
                //
                // Everything else in the readout is derived from this in
                // modules/VolumeRail.qml (the handle's span and thickness, the
                // gap, the stop dot, the inner corner radius), so this is still
                // the one number that sizes the control: raise it and the whole
                // slider grows in proportion rather than losing its shape.
                railWidth: 16,

                // HOW LONG THE METER IS, in glyphs of the icon standing under it.
                //
                // The comment above says the meter is a count "of its own glyphs
                // tall, derived from the icon it stands under", and that is the
                // right shape for the setting, but the number itself was left in
                // modules/VolumeRail.qml with nothing declaring it. A key that is
                // not in these defaults DOES NOT EXIST: `set()` refuses it, and
                // `merge()` walks the defaults' keys so a hand-edited config.json
                // drops it silently. Read through Appearance it came back
                // undefined, and undefined times a height is NaN, which travels
                // straight through the content height into the panel height and
                // out into the blob's own rectangle. A NaN-sized blob is not a
                // small blob, it is an absent one: the readout drew its glyph and
                // its meter over the wallpaper with no body behind them at all.
                //
                // FIVE, and it went up from three for the same reason the width
                // did: three was the length of a reading, and this is now the
                // length of a TRAVEL. What a track has to be long enough for
                // stopped being "read as a length rather than as a mark" and
                // became "put the handle where you meant to", and that is a
                // question about the hand rather than about the eye. At three
                // glyphs the whole 0-to-150 range was seventy-odd pixels, so one
                // pixel of finger was worth two points of volume and the handle
                // could not be placed to better than about five; at five it is a
                // point and a bit, which is finer than the wheel's own step.
                //
                // It is expressed in glyphs rather than pixels so it follows the
                // type scale: change the font base and the track keeps its
                // proportion to the icon it belongs with, which is what the old
                // pixel `railLength` could not do.
                meterGlyphs: 5,

                // How long the readout stays after the last change. Long enough
                // to see where a keypress landed, short enough that it is gone
                // before you wonder how to dismiss it. It never outlives the
                // cursor: hovering holds it open regardless.
                linger: 1200,

                // HOW MUCH OF THE EDGE THE RAIL IS, as a fraction of the edge's
                // height, centred. It was the whole edge less the two corner
                // zones, and a control that owns an entire screen edge is a
                // control that intercepts everything else that happens there: a
                // scrollbar lives on the right edge of every window, and a rail
                // the full height of the screen sat over all of them. A third
                // of the edge is still an enormous target by this shell's
                // standards, about three hundred and sixty pixels on the
                // 1200px panel this was tuned on, and it leaves the rest of
                // the edge to the windows.
                grabFraction: 0.3
            },

            // Wi-Fi, and the one question NetworkManager will not answer
            // unasked.
            network: {
                // Whether NetworkManager actually FETCHES something to find out
                // if the connection works, rather than inferring it from having
                // a default route.
                //
                // On, and it costs one small HTTP request a minute and can tell
                // a captive portal from the real internet. Off, and it guesses,
                // and its guess is "fine" for every hotel network, every AP with
                // a dead uplink, and every landing page you have not signed in
                // to yet. The shell has the words for all of those and cannot
                // say any of them without this.
                checkForInternet: true,

                // Which URL "open the login page" opens. Empty means ask
                // NetworkManager for the URL it probes with, which is the right
                // answer: that request is the one the portal intercepted, so it
                // is the one that lands on the login page.
                portalUri: ""
            },

            // The power panel, on the right edge.
            session: {
                // The square you press. Bigger than the 52 of the sidebar slab
                // on purpose: everything in that slab is an indicator you glance
                // at, and this is the one surface in the shell where a misplaced
                // click ends the session. A target you have to arrive at
                // deliberately is part of the safety, not decoration.
                button: 59,

                // The mark inside it, relative to the shell's icon size. The bar
                // draws icons at 20 because they sit in a 52px band; in a 56px
                // button that reads as a small glyph adrift in a large square.
                iconScale: 1.4
            },

            // The settings page. See modules/settings/.
            //
            // ONE size for both halves of its life. The page is drawn by the
            // shell or by a window depending on which you last asked for, and
            // the whole point of the handover is that it is the same object
            // either way: two sizes would make it a different object the moment
            // it changed hands.
            settings: {
                width: 560,
                height: 560
            },

            // The bottom-right corner, as a way in. See
            // modules/SettingsCorner.qml.
            //
            // The one corner of the screen nothing else claims: the top-right is
            // the notification tray's, the two on the left are the sidebar's, and
            // the volume rail deliberately stops short of both ends of its edge so
            // that no corner on this shell does two things.
            corner: {
                // WHAT THE CORNER BECOMES, relative to the shell's icon size, and
                // the only number the corner has. How far it swells is the glyph
                // plus its padding plus the band, computed from this: the swell
                // is there to hold the mark, so a size of its own would be a
                // second opinion about the same thing.
                //
                // Bigger than the 1.4 the power panel's buttons use. Those are
                // marks inside a button and read against its edge; this one has
                // no plate around it and is the entire thing you are looking at.
                iconScale: 1.6
            },

            // The hotkey sheet: every bind the compositor knows about, read off
            // hyprctl and drawn on demand. See modules/cheatsheet/.
            //
            // TWO PREFERENCES AND NOT ONE SIZE. Everything the sheet draws is
            // derived from the type scale and the padding tiers, so there is
            // nothing here to make it bigger with; what is here is the two
            // choices the sheet itself offers, so that the answer you gave it
            // last week is still the answer when the shell comes back up. They
            // are preferences rather than design tokens, which is why they are
            // read straight off Config (the way `theme` is) and get no entry in
            // Appearance.
            cheatsheet: {
                // WHICH VIEW: the list of every bind grouped by chord, or the
                // drawn keyboard with the bound keys lit.
                //
                // The list, because it is the view that can show EVERYTHING. The
                // board can only mark a bind that lands on a key it draws, so a
                // mouse bind, a `code:` bind and a chord on a key this layout
                // does not have are all invisible on it, and a sheet that quietly
                // omits binds is worse than a plain list at the job the sheet
                // exists to do. The board is the better answer to "where is that
                // key", which is the question you ask second.
                board: false,

                // HOW A CHORD IS SPELLED: the modifier's word (SUPER, SHIFT) or
                // its mark (a penguin, an arrow, a caret).
                //
                // Words, because words are what the config file you would go and
                // edit says. The marks are shorter and they are also a convention
                // you have to already know: no penguin is printed on the key, and
                // somebody opening this sheet to find out what a bind IS should
                // not have to decode the answer. They are there for when you do
                // know them and would rather the chord fitted on one line.
                symbols: false
            },

            // The lock screen. See modules/lock/.
            lock: {
                // How wide the field you type into is. Wide enough that a long
                // password does not scroll inside it, narrow enough that it
                // reads as one control rather than as a bar across the screen.
                fieldWidth: 360,

                // How far back the wallpaper goes while the screen is locked.
                //
                // The compositor cannot help here. Its blur rule matches
                // `namespace banditshell`, and a session lock surface is not a
                // layer surface, so it has no namespace to match: this is the
                // one surface in the shell that blurs its own ground. See
                // modules/lock/LockSurface.qml.
                blur: 0.8,

                // Exposure, not a black sheet. A scrim at this strength flattens
                // the picture toward grey; pulling the brightness down keeps the
                // wallpaper's own contrast underneath the blur.
                //
                // THIS FAR DOWN because of the font. Monocraft's stems are one
                // device pixel, so there is nothing for anti-aliasing to work
                // with and mid-tones turn the text to mush; DESIGN.md section 6
                // is blunt about it - pixel text goes on abyss or void, never on
                // a mid-tone. A wallpaper is a picture with a bright part
                // somewhere, and the clock has to be legible over whichever part
                // it lands on, so the ground goes back until it is a ground.
                dim: 0.8,

                // Pulled toward grey as well as down. The shell is one cool
                // green hue family and a wallpaper is not: left saturated, the
                // ground argues with the chassis sitting on it instead of
                // receding behind it. Enough that the picture reads as material,
                // not so much that it stops being the wallpaper.
                desaturate: 0.45,

                // The marks that stand in for what you typed.
                //
                // Material Symbols' `circle` is a solid disc filling most of its
                // em box, so it is drawn at half the shell's icon size: a
                // password mark is punctuation rather than an icon, and at full
                // size a dozen of them do not fit the field.
                dotScale: 0.5,

                // How fast the screen arrives. SLOWER than the shell's own
                // reveal, which is tuned for a panel you asked for and were
                // already looking at. This is a change of context rather than a
                // panel opening, and something that takes the whole screen
                // should be seen to arrive rather than simply be there.
                revealSpeed: 9
            },

            // Controls inside menus.
            control: {
                // WCAG 2.2 SC 2.5.8 Target Size (Minimum), AA.
                minTarget: 24,

                // How far one notch of the wheel throws a list, in rows. Five,
                // not three: a list of everything installed is thousands of
                // pixels long, and a notch that moves three rows of it makes the
                // wheel feel geared down.
                wheelRows: 5,
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
                // THE FEEL TOKENS. A gesture is a feel, not a rule, and these
                // four numbers are the rules that create it. Recognition early
                // (slack), rejection rare (the angles), commitment generous
                // (commit and reversal), so a sloppy half-swipe in roughly the
                // right direction does the thing, and only a deliberate motion
                // the other way undoes it.
                //
                // How far a press travels before it is a pull at all. This was
                // a full padding tier, twenty-four pixels, and that is where
                // half of the dead feel lived: a short flick never reached
                // recognition, so it did nothing, and a long one spent its
                // first inch unacknowledged, so the panel arrived late to its
                // own gesture. Recognition is what makes the surface start
                // tracking the hand, and tracking is the entire signal that the
                // gesture is working; it should begin as early as telling a
                // pull from a wobble allows.
                pullSlack: 12,
                // Once a pull is this far along, letting go keeps it even if
                // the hand recoiled a little at the lift. Momentum alone
                // decided before, and the lift is the noisiest moment of the
                // whole gesture: a finger peeling off a screen drags the point
                // backward, so the flick that obviously happened was answered
                // with the panel bouncing home. A fraction of the full travel,
                // like the travel itself.
                pullCommit: 0.25,
                // How fast the hand must actually be moving BACKWARD at the
                // lift for that to count as a change of mind rather than as
                // lift-off noise, in smoothed pixels per event. Below this,
                // past the commit point, the pull stands.
                pullReversal: 3,
                // How fast a smoothed motion has to be, in pixels per event,
                // to read as a throw regardless of how far it got. A flick is
                // an intention expressed as speed, and asking it to also cover
                // distance is asking it twice.
                flickVelocity: 4,
                // How far either side of a corner's own 45 degree diagonal
                // still counts as "away from the corner", in degrees. The
                // corner offers ninety degrees of directions into the screen;
                // forty either side spends eighty of them on this gesture,
                // because the corner gestures are the ones a whole hand aims
                // and a hand aims loosely. What little is left at the ends
                // still matters less than it did: nothing runs ALONG an edge
                // right up to a corner any more, the volume rail having become
                // a segment in the middle of its edge.
                pullAngleCorner: 40,
                // The same tolerance for a pull that starts on an EDGE rather
                // than in a corner, which has twice the room to spend: an edge
                // offers a hundred and eighty degrees of "away from it" where a
                // corner offers ninety, so the corner's forty would be a
                // needlessly narrow slot on the more generous gesture. Sixty
                // either side spends a hundred and twenty of them and still
                // leaves thirty at each end for gestures that run ALONG the
                // edge.
                pullAngleEdge: 60,
                // A full pull, as a fraction of the surface it is dragged
                // across. A diagonal gesture is measured against a diagonal and
                // a straight one against the distance it covers, and a fraction
                // rather than a pixel count because a distance that is a
                // comfortable swipe on one display is either trivial or
                // impossible on another.
                pullTravel: 0.12,
                // WHETHER THE SCREEN EDGES ARE SIZED FOR A FINGER, and the one
                // setting in here that is a real trade rather than a taste.
                //
                // The band is ten pixels and the gestures that live on it (the
                // volume rail's segment in the middle of the right edge, the
                // notch across the top) are ten pixels of target. A cursor can
                // be thrown at an edge and the edge stops it, so ten is plenty;
                // a fingertip is nearer eight millimetres and has nothing to
                // stop it, so ten is a miss. On they widen to `minTarget`, and
                // the shell has to claim those pixels from the windows
                // underneath to be able to answer in them at all.
                //
                // WHAT IT COSTS: fourteen more pixels of the middle third of
                // every window's right edge, and of its top-centre, belong to
                // the shell, and the right edge is where scrollbars live. Less
                // than it cost when the rail ran the whole edge (see
                // volume.grabFraction; the claim shrank with the rail), but
                // still a bad trade for a mouse and the only workable one for
                // a hand, which is why it is a switch and not a decision made
                // here. Off, the edges collapse back to the band exactly as
                // they were.
                touchEdges: true,
                // How many rows a list menu shows before it says "+N more". A
                // street is eighty wifi networks and a menu that scrolls forever
                // is worse than one that admits what it left out.
                networkListMax: 7,
                // App rows the mixer shows before it stops counting. The panel
                // clips where it runs out of screen rather than scrolling, so
                // this is the difference between a long list and a list with its
                // last row cut in half.
                streamListMax: 5,
                deviceListMax: 7,
                // 40 was Sequoia's measured Control Center row pitch (at 34 a
                // two-line row's 36px of line boxes overflowed its own height
                // and the list read as cramped), then lifted five percent for
                // fingertips: a row is the thing a finger actually lands on,
                // and the bar's slots moved by the same fraction so the whole
                // bar keeps one density.
                rowHeight: 42,
                sliderHeight: 6,
                toggleWidth: 34,
                toggleHeight: 18
            },

            menu: {
                // Sized from what a row has to hold, not picked. A row spends
                // 12 of padding, 20 of icon, 12, then the label, then 12, the
                // trailing control, and 12 again: 108px before a single
                // character. At 300 that left 192px, which was 32 characters of
                // 6px type and only 16 of 12px, so every SSID and every
                // Bluetooth device name in the shell elided at the same moment
                // the type got legible.
                //
                // 400 leaves 292, which is 24 characters. "internet79vietnamnet"
                // and "OpenRun Pro 2 Bluetooth" are the longest real names here
                // and both fit.
                width: 400,
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
                // Raised with the type, and again when device rows grew a second
                // line. The sound menu is the tall one and keeps getting taller
                // for good reasons: two sliders, an app per stream, and five
                // devices that now say what they are and where they plug in.
                //
                // Not a licence to grow forever. MenuPanel takes the min of this
                // and the space actually below the icon, so the screen still
                // decides; this only stops the cap deciding first. What it
                // cannot do is make a menu SCROLL, so anything past here is
                // still cut off rather than reachable.
                maxHeight: 1000
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
        // An EMPTY default array is a list, not a tuple: there is no shape to
        // have changed, so whatever the user put there is data and survives. A
        // non-empty one is a fixed set of slots (a scale, a ladder) and a
        // different length means the shape moved under it.
        if (Array.isArray(base))
            return Array.isArray(over) && (base.length === 0 || over.length === base.length) ? over : base;

        // Same idea for an empty default OBJECT: the defaults name no keys, so
        // the keys are the user's data rather than a schema to merge into, and
        // walking `base` would drop every one of them.
        if (base && typeof base === "object" && !Object.keys(base).length)
            return over && typeof over === "object" ? over : base;
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
