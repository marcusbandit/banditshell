pragma Singleton

import QtQuick
import Quickshell

// The resolved design tokens. Widgets read ONLY this.
//
// There is not a single literal value in here. Everything is Config (the
// user's JSON) applied to Themes (the named palettes), so every number and
// colour in the shell is reachable from one file the user owns. Change
// config.json and this re-resolves live; widgets just re-bind.
//
// Tiers are computed, never listed: a scale is a base times a list of
// multipliers, so "small / normal / large" are indices 0/1/2 into data rather
// than three hardcoded numbers.
Singleton {
    id: root

    readonly property var cfg: Config.values
    readonly property var theme: Themes.get(cfg.theme)

    // When asked to follow the compositor, geometry that the compositor also has
    // an opinion about comes from it rather than from config.json, so the shell
    // and the windows can never disagree. Falls back the moment it can't be read.
    readonly property bool follows: cfg.compositor.follow && Compositor.available

    function tier(base: real, scale: var, i: int): real {
        return base * scale[Math.max(0, Math.min(i, scale.length - 1))];
    }

    // A point anywhere ALONG the theme's ramp, including between stops.
    //
    // This is what makes depth portable. "Raised" is not a hex value, it is
    // "0.45 of a step further up the ramp than the surface it sits on", so a
    // lighting effect survives a palette swap intact.
    function rampAt(i: real, alpha: real): color {
        const r = root.theme.ramp;
        const c = Math.max(0, Math.min(i, r.length - 1));
        const lo = Math.floor(c);
        const hi = Math.min(lo + 1, r.length - 1);
        return mix(r[lo], r[hi], c - lo, alpha);
    }

    // TWO COLOURS, MIXED. `mix` below takes the ramp's hex STRINGS, which is
    // what a theme's ramp is made of; this takes colours, which is what
    // everything downstream of `colour` holds. Same operation, different end of
    // the pipe, and neither can be written in terms of the other without one of
    // them lying about its argument type.
    function blend(a: color, b: color, t: real): color {
        const k = Math.max(0, Math.min(1, t));
        return Qt.rgba(a.r + (b.r - a.r) * k, a.g + (b.g - a.g) * k, a.b + (b.b - a.b) * k, a.a + (b.a - a.a) * k);
    }

    // ANY COLOUR AT A LABEL TIER'S WEIGHT.
    //
    // The tiers in `colour` are the shell's own light veiled over a panel, which
    // is right for everything drawn ON the material and useless for anything
    // that is its own object with its own ink. A card's second line still has to
    // be quieter than its first by the same amount the shell's is, so it takes
    // the same weights applied to a different colour.
    function shade(c: color, tier: int): color {
        const w = root.cfg.material.label;
        return Qt.rgba(c.r, c.g, c.b, w[Math.max(0, Math.min(tier, w.length - 1))]);
    }

    function mix(a: string, b: string, t: real, alpha: real): color {
        const pa = parseInt(a.slice(1), 16);
        const pb = parseInt(b.slice(1), 16);
        const lerp = (shift) => {
            const x = (pa >> shift) & 255;
            const y = (pb >> shift) & 255;
            return (x + (y - x) * t) / 255;
        };
        return Qt.rgba(lerp(16), lerp(8), lerp(0), alpha);
    }

    // Everything drawn ON a panel is one colour, the light end of the ramp, at
    // different opacities. That is the whole hierarchy. It is why a translucent
    // interface stays coherent over any wallpaper: the tiers keep their relative
    // weight no matter what shows through.
    readonly property color tint: theme.ramp[theme.ramp.length - 1]

    function veil(alpha: real): color {
        return root.mix(root.tint, root.tint, 0, alpha);
    }

    readonly property QtObject colour: QtObject {
        // A translucent material. What you mostly see through it is the
        // compositor's blur of whatever is behind, which is where the depth
        // actually comes from.
        readonly property color surface: root.rampAt(root.cfg.colour.surface, root.cfg.material.surfaceAlpha)

        // THE SAME MATERIAL WITH NOTHING BEHIND IT.
        //
        // Same point on the ramp, no alpha. For the one thing in this shell that
        // is not a shell surface: a real window, which the compositor frames and
        // does not blur the way it blurs a layer. Translucency there is not depth,
        // it is the wallpaper coming through the page.
        readonly property color surfaceSolid: root.rampAt(root.cfg.colour.surface, 1)

        // Label tiers.
        readonly property color text: root.veil(root.cfg.material.label[0])
        readonly property color textDim: root.veil(root.cfg.material.label[1])
        readonly property color textFaint: root.veil(root.cfg.material.label[2])
        // Watermarks, placeholders, genuinely inactive text. Without it,
        // textFaint was doing two jobs at one weight.
        readonly property color textGhost: root.veil(root.cfg.material.label[3])

        // Fills. `fill` is a hover, `fillStrong` is a selection. Neither is a
        // colour: they are the same light, turned up.
        readonly property color fill: root.veil(root.cfg.material.fill[0])
        readonly property color fillStrong: root.veil(root.cfg.material.fill[1])
        readonly property color fillStronger: root.veil(root.cfg.material.fill[2])

        readonly property color separator: root.veil(root.cfg.material.separator)

        // The saturated end of the theme. Reserved for state that is genuinely
        // worth a colour, never for decoration or for filling a shape.
        readonly property color accent: root.theme[root.cfg.colour.accent]

        // The same colour at a fill's job: tinting a surface rather than marking
        // a glyph. "Which workspace you are on" is the one piece of state in the
        // sidebar worth a hue, and a tint is how you say it without painting a
        // saturated block.
        readonly property color accentFill: Qt.rgba(accent.r, accent.g, accent.b, root.cfg.material.accentFill)

        // One step above the accent. Accent means "attention", this means "you
        // are about to lose something", and only a battery running out wears it
        // today. No `alarmFill` beside `accentFill` on purpose: the one thing
        // tinting a surface with it (BatteryMeter's well) breathes the alpha.
        readonly property color alarm: root.theme.alarm

        // What goes ON the accent: a switch's knob, selected text behind it.
        // The accent is a bright saturated green, so this is the dark end of the
        // ramp rather than a label tier, which would be translucent and let the
        // green show through whatever sits on it.
        readonly property color accentText: root.rampAt(1, 1)

        // THE TWO ENDS OF THE RAMP, opaque, which is the most contrast this
        // theme owns. Everything else here is one light at different strengths
        // and is meant to sit ON the material; this pair is for the rare object
        // that has to be read by something other than a person looking at it.
        //
        // A QR code is the case that made them exist. A camera has none of the
        // context a reader has: it thresholds a picture, and a translucent label
        // tier over a blurred wallpaper has no threshold. So the code is drawn
        // as ink on paper, and "black on white" is spelled in the theme's own
        // darkest and lightest rather than in #000 and #fff, which belong to no
        // palette and would read as a hole cut in the shell.
        //
        // Indexed off the ramp's LENGTH rather than off 10, so a theme with a
        // different number of stops still lands on its own extremes.
        readonly property color ink: root.rampAt(0, 1)
        readonly property color paper: root.rampAt(root.theme.ramp.length - 1, 1)

        // THE SATURATED END, all three of it, quietest to brightest.
        //
        // `accent` above is whichever ONE of these config picked, and it is
        // rationed: state worth a colour, never decoration. This is the ramp
        // itself, and it exists for the one object in the shell that spends
        // colour AS colour rather than as a mark. Read it as a ramp, by
        // position, so a theme is free to have more or fewer stops.
        readonly property var spectrum: [root.theme.dim, root.theme.mid, root.theme.bright]

        // The screen-corner frame. Not from the ramp: it is meant to read as the
        // absence of screen, not as part of the palette.
        readonly property color frame: root.cfg.edge.outerColour

        // What dims everything outside a selection. Dark rather than tinted: it
        // sits over arbitrary content that has to stay recognisable through it.
        readonly property color scrim: Qt.rgba(0, 0, 0, 0.45)
    }

    readonly property QtObject font: QtObject {
        readonly property string family: root.cfg.font.family
        readonly property string icon: root.cfg.font.icon
        readonly property string brand: root.cfg.font.brand

        // THREE SIZES, shell-wide. Hierarchy is carried by colour, spacing and
        // fills instead (see ~/.claude/rules/type-scale.md).
        readonly property QtObject size: QtObject {
            readonly property int small: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 0))
            readonly property int normal: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 1))
            readonly property int large: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 2))
        }

        // Icons are glyphs, not type: they carry no hierarchy, so they sit
        // outside the three tiers rather than eating one.
        //
        // Sized from the tier they sit BESIDE, not from the raw base. Deriving
        // from the base coupled them to the pixel grid, and when that moved to
        // 9 every icon in the shell shrank to 10px along with it. An icon next
        // to body text should match body text whatever the grid says.
        //
        // That tier is `small`. Body text is `small` now: the grid has no step
        // between 9 and 18, so the bottom of the ladder had to become the
        // workhorse rather than the quiet one. Reading `normal` here would size
        // every icon from a tier nothing is set in, and 30px icons do not fit
        // the 28px status slot they sit in.
        readonly property int iconSize: Math.round(size.small * root.cfg.font.iconScale)

        // THE PIXEL FONT'S OWN DEVICE PIXEL, and therefore what a line drawn
        // beside it should weigh.
        //
        // Monocraft's design pixel is the base (see Config's font block), so a
        // tier is that many device pixels per design pixel: at base 9 with the
        // body tier at 2x, a stem is 2px wide. A rule, a ring or an outline at
        // any other width reads as a different material sitting next to type
        // made of stems that thick, which is the same reason the sizes have to
        // be whole multiples in the first place.
        readonly property int stem: Math.max(1, Math.round(size.small / root.cfg.font.base))
    }

    readonly property QtObject rounding: QtObject {
        // Hyprland's `rounding`, or config.json's, depending on `follows`.
        readonly property real base: root.follows ? Compositor.rounding : root.cfg.rounding.base

        readonly property real small: at(0)
        readonly property real normal: at(1)
        readonly property real large: at(2)

        // THE CORNER, for the whole shell: |x|^n + |y|^n = r^n. 2 is a plain
        // circular arc, and every step up hugs the vertex more closely while
        // ramping the curvature into the straight edge instead of jumping.
        //
        // ONE NUMBER, and it used to be two. The chassis field took this and the
        // vector primitive took a separate Figma "smoothing", which is a
        // different construction that cannot draw this curve at all, so a panel
        // and the melt around it were never the same shape. components/squircle.js
        // draws the superellipse now, so both ends read the same setting.
        //
        // FOLLOWED, where it used to be pinned to 2 with a comment saying
        // Hyprland renders circular whatever it reports. It does not: measured
        // off the render, on rays from the corner centre, this window's edge sits
        // 17.9% further out along the diagonal than along the axes, which is
        // n = 3.8 against a reported `rounding_power` of 4. The earlier
        // measurement had found the SHADOW, which is blurred and does measure
        // round. Pinning it at 2 gave every panel a squarer corner than the
        // window beside it.
        readonly property real power: root.follows ? Compositor.roundingPower : root.cfg.rounding.power

        // Any tier by index, for things that take the tier as a setting.
        function at(i: int): real {
            return root.tier(base, root.cfg.rounding.scale, i);
        }
    }

    readonly property QtObject padding: QtObject {
        readonly property int small: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 0))
        readonly property int normal: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 1))
        readonly property int large: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 2))
        readonly property int huge: Math.round(root.tier(root.cfg.padding.base, root.cfg.padding.scale, 3))
    }

    readonly property QtObject anim: QtObject {
        readonly property int fast: Math.round(root.tier(root.cfg.anim.base, root.cfg.anim.scale, 0))
        readonly property int normal: Math.round(root.tier(root.cfg.anim.base, root.cfg.anim.scale, 1))
        readonly property int slow: Math.round(root.tier(root.cfg.anim.base, root.cfg.anim.scale, 2))

        // Exponential-smoothing rates (see ~/.claude/rules/animation-smoothing.md).
        readonly property real trackSpeed: root.cfg.anim.trackSpeed
        readonly property real revealSpeed: root.cfg.anim.revealSpeed
        readonly property real resizeSpeed: root.cfg.anim.resizeSpeed
        readonly property real scrollSpeed: root.cfg.anim.scrollSpeed

        readonly property int grace: root.cfg.anim.grace
        readonly property int tooltip: root.cfg.anim.tooltip
        // How long a menu has to be on screen before what is inside it is
        // believed to be worth doing; see MenuPanel's page delegate.
        readonly property int settle: root.cfg.anim.settle
        readonly property int handover: root.cfg.anim.handover
    }

    readonly property QtObject sizes: QtObject {
        // The invisible ring is exactly the compositor's outer gap, so it sits in
        // the dead space between windows and the screen edge rather than over
        // anything.
        readonly property int border: root.follows ? Compositor.gapsOut : root.cfg.edge.border
        readonly property int sidebarWidth: root.cfg.sidebar.width
        readonly property real sidebarFlare: root.rounding.at(root.cfg.sidebar.flareTier)
        readonly property int wsSlot: root.cfg.sidebar.workspaces.slot
        readonly property int wsGap: root.cfg.sidebar.workspaces.gap
        readonly property int wsPersistent: root.cfg.sidebar.workspaces.persistent
        // The scratchpad rack's pinned order, by name. A list, not a size, but
        // it belongs with the rest of what the workspace column is told.
        readonly property var wsSpecials: root.cfg.sidebar.workspaces.specials
        readonly property int wsMaxWindows: root.cfg.sidebar.workspaces.maxWindows
        // The row pitch of stacked window icons. Derived from the icon size
        // rather than set in pixels, so the stack keeps its proportions when
        // the icons change size.
        // A window's mark here, and the row it sits in. Both derive from the
        // shell's icon size, so the sidebar keeps its proportions when that moves.
        readonly property int wsIcon: Math.round(root.font.iconSize * root.cfg.sidebar.workspaces.iconScale)
        readonly property int wsWindowPitch: Math.round(wsIcon * root.cfg.sidebar.workspaces.windowPitch)
        readonly property string wsIconMode: root.cfg.sidebar.workspaces.iconMode
        // The ruler down the screen's edge. See modules/sidebar/Workspaces.qml.
        readonly property string wsStyle: root.cfg.sidebar.workspaces.style
        readonly property int wsTick: root.cfg.sidebar.workspaces.tick
        readonly property int wsMapBar: root.cfg.sidebar.workspaces.mapBar
        readonly property int wsMapGap: root.cfg.sidebar.workspaces.mapGap
        readonly property int wsBlock: root.cfg.sidebar.workspaces.block
        readonly property int wsBlockGap: root.cfg.sidebar.workspaces.blockGap
        readonly property real wsEmptyReach: root.cfg.sidebar.workspaces.emptyReach
        readonly property real wsBusyReach: root.cfg.sidebar.workspaces.busyReach
        readonly property real wsHover: root.cfg.sidebar.workspaces.hover
        readonly property int statusSlot: root.cfg.sidebar.status.slot
        readonly property int statusGap: root.cfg.sidebar.status.gap

        // The tray, at the top of the bar. See modules/sidebar/TrayIcons.qml.
        // Its mark derives from the shell's icon size like every other mark, so
        // the whole bar rescales from one number.
        readonly property int traySlot: root.cfg.sidebar.tray.slot
        readonly property int trayGap: root.cfg.sidebar.tray.gap
        readonly property int trayIcon: Math.round(root.font.iconSize * root.cfg.sidebar.tray.iconScale)
        readonly property int trayMax: root.cfg.sidebar.tray.max

        readonly property real melt: root.cfg.blob.melt
        readonly property real meltFeather: root.cfg.blob.feather

        readonly property int networkListMax: root.cfg.control.networkListMax
        // The signal meter's steps, read by the meter that draws them and by
        // the service that sorts on them; see Config's note on why it is one
        // number rather than two that agree until they don't.
        readonly property int signalBands: root.cfg.control.signalBands
        readonly property int streamListMax: root.cfg.control.streamListMax
        readonly property int deviceListMax: root.cfg.control.deviceListMax
        readonly property int minTarget: root.cfg.control.minTarget
        readonly property real dragDismissFraction: root.cfg.control.dragDismissFraction
        readonly property real dragResistance: root.cfg.control.dragResistance
        readonly property int dragThreshold: root.cfg.control.dragThreshold
        // The pull gesture's direction gate, one tolerance for a corner and one
        // for an edge, and its full-pull distance; see components/Pull.qml.
        // The feel tokens: recognition, commitment, reversal and the throw.
        // See Config's note; a gesture is a feel, and these are the rules that
        // create it.
        readonly property int pullSlack: root.cfg.control.pullSlack
        readonly property real pullCommit: root.cfg.control.pullCommit
        readonly property real pullReversal: root.cfg.control.pullReversal
        readonly property real flickVelocity: root.cfg.control.flickVelocity
        readonly property int pullAngleCorner: root.cfg.control.pullAngleCorner
        readonly property int pullAngleEdge: root.cfg.control.pullAngleEdge
        readonly property real pullTravel: root.cfg.control.pullTravel
        // Whether the screen-edge gestures are sized for a finger or for a
        // cursor; see the note in Config.qml, it is a trade rather than a taste.
        readonly property bool touchEdges: root.cfg.control.touchEdges
        // The bottom edge as a handle on the window above it: what a finger has
        // to do to lift one, to throw it away, and to put it somewhere else.
        // See modules/windows/.
        readonly property bool windowEdge: root.cfg.windows.edge
        readonly property int windowGrab: root.cfg.windows.grab
        readonly property int windowSettle: root.cfg.windows.settle
        readonly property int windowHold: root.cfg.windows.hold
        readonly property int windowHoldSlop: root.cfg.windows.holdSlop
        readonly property real windowTravel: root.cfg.windows.travel
        readonly property real windowFling: root.cfg.windows.fling
        readonly property real windowScale: root.cfg.windows.scale
        readonly property real windowPlate: root.cfg.windows.plate
        readonly property string windowMode: root.cfg.windows.mode
        readonly property bool windowFollow: root.cfg.windows.follow
        readonly property int rowHeight: root.cfg.control.rowHeight
        readonly property real wheelRows: root.cfg.control.wheelRows
        readonly property real coastMs: root.cfg.control.coastMs
        readonly property int sliderHeight: root.cfg.control.sliderHeight
        readonly property int toggleWidth: root.cfg.control.toggleWidth
        readonly property int toggleHeight: root.cfg.control.toggleHeight

        readonly property int pickerOutline: root.cfg.picker.outline
        readonly property int launcherWidth: root.cfg.launcher.width
        readonly property int launcherIcon: root.cfg.launcher.iconSize

        // What was copied. See modules/clipboard/.
        readonly property int clipboardWidth: root.cfg.clipboard.width
        readonly property int clipboardPreview: root.cfg.clipboard.preview
        readonly property int clipboardLines: root.cfg.clipboard.previewLines
        // A row's mark, sized like every other mark in the shell rather than in
        // pixels of its own, so the whole thing rescales from the one number.
        readonly property int clipboardIcon: Math.round(root.font.iconSize * root.cfg.clipboard.iconScale)
        // How long a new wallpaper takes to open over the old one. A duration
        // among the sizes because that is where every other configured number
        // the shell reads lands; see Config's note on why it is not one of the
        // animation tiers.
        readonly property int wallpaperReveal: root.cfg.wallpaper.reveal
        readonly property int notchTrack: root.cfg.notch.trackWidth
        readonly property int notificationWidth: root.cfg.notifications.width
        readonly property int notificationBadge: root.cfg.notifications.badge
        readonly property int cornerZone: root.cfg.notifications.cornerZone

        // The right edge, as a volume rail. See modules/VolumeRail.qml.
        readonly property real volumeStep: root.cfg.volume.step
        // The meter's THICKNESS, and no length beside it: the readout is three
        // of its own glyphs tall and derives that from the icon it stands under,
        // so the length is arithmetic in the rail rather than a token here. See
        // the note over `railWidth` in Config for what used to be here.
        readonly property int volumeRailWidth: root.cfg.volume.railWidth
        // The meter's length, in glyphs of the icon under it. Read by
        // modules/VolumeRail.qml, and it was read there before it was declared
        // anywhere: see the note in Config, and the NaN that reached the blob.
        readonly property int volumeMeterGlyphs: root.cfg.volume.meterGlyphs
        readonly property int volumeLinger: root.cfg.volume.linger
        readonly property real volumeGrabFraction: root.cfg.volume.grabFraction
        // What a full day-bar means on the calendar; see services/Usage.qml.
        readonly property int usageCapHours: root.cfg.usage.capHours

        // WHICH MONTH A RIGHTWARD SWIPE ASKS THE CALENDAR FOR. True is the
        // gesture going forward in time with the hand, false is the strip of
        // months behaving like paper under it; Config carries the whole
        // argument, which is a real one in both directions.
        //
        // A token here rather than a read straight off Config the way the
        // cheatsheet's two preferences are, because it is not an answer the UI
        // stored for itself: it decides what a gesture MEANS, which is the job
        // `touchEdges`, `dragThreshold` and the pull tolerances above already
        // have, and it belongs with them.
        readonly property bool calendarRightGoesForward: root.cfg.calendar.rightGoesForward

        // The power panel, on the right edge. See modules/session/SessionMenu.qml.
        readonly property int sessionButton: root.cfg.session.button
        readonly property int sessionIcon: Math.round(root.font.iconSize * root.cfg.session.iconScale)

        // The settings page, at rest. See modules/settings/.
        //
        // ONE size for both halves of its life: the page is drawn by the shell
        // or by a window depending on which you last asked for, and the point of
        // the handover is that it is the same object either way.
        readonly property int settingsWidth: root.cfg.settings.width
        readonly property int settingsHeight: root.cfg.settings.height

        // The bottom-right corner, as a way in. The corner's SIZE is not here:
        // it is derived from this mark in modules/SettingsCorner.qml, because
        // the swell exists to hold the glyph.
        readonly property int cornerIcon: Math.round(root.font.iconSize * root.cfg.corner.iconScale)

        // The lock screen. See modules/lock/LockSurface.qml.
        //
        // The field's height is DERIVED, not configured: it is one line of the
        // body size in its own box, and the one number that decides how tall a
        // line is here is StyledText's fixed 4/3 line box. Configuring it
        // separately would let the two disagree the first time the type scale
        // moved.
        readonly property int lockField: root.cfg.lock.fieldWidth
        readonly property real lockFieldHeight: Math.round(root.font.size.small * 4 / 3) + root.padding.normal * 2
        readonly property real lockBlur: root.cfg.lock.blur
        readonly property real lockDim: root.cfg.lock.dim
        readonly property real lockDesaturate: root.cfg.lock.desaturate
        readonly property int lockDot: Math.round(root.font.iconSize * root.cfg.lock.dotScale)
        readonly property real lockReveal: root.cfg.lock.revealSpeed

        readonly property int menuWidth: root.cfg.menu.width
        readonly property int menuMinHeight: root.cfg.menu.minHeight
        readonly property int menuMaxHeight: root.cfg.menu.maxHeight

        readonly property bool roundOuter: root.cfg.edge.roundOuter

        // THE ROUNDING VOCABULARY. There is ONE radius in this shell and two
        // distances; everything else is a name for an offset of the same curve.
        //
        //   windowRadius   the compositor's `rounding` plus its `border_size`:
        //                  the outer edge of a window, and the only radius here
        //   gap            the compositor's `gaps_out`
        //   band           how thick the chassis band is, which is the gap
        //
        // and then, all offsets of the window's curve, never radii of their own:
        //
        //   the content area   windowRadius offset out by `gap`
        //   the screen's edge  offset again by `band`
        //
        // Saying "the content radius is windowRadius + gap" is the trap. It is
        // true for circles and false for every other superellipse: at the
        // compositor's exponent of 4 it opens a 19% wider gap along the diagonal
        // than along the edges, which is a visible wedge at each corner. The
        // shader offsets the distance field instead, so the chassis cups a
        // window corner at a constant distance whatever the exponent is.
        readonly property real windowRadius: root.rounding.base + (root.follows ? Compositor.borderSize : 0) + root.cfg.edge.outerExtra
        readonly property real gap: border
        readonly property real band: border
    }
}
