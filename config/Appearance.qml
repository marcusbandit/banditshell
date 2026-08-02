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

        // What goes ON the accent: a switch's knob, selected text behind it.
        // The accent is a bright saturated green, so this is the dark end of the
        // ramp rather than a label tier, which would be translucent and let the
        // green show through whatever sits on it.
        readonly property color accentText: root.rampAt(1, 1)

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
        readonly property int iconSize: Math.round(size.normal * root.cfg.font.iconScale)
    }

    readonly property QtObject rounding: QtObject {
        // Hyprland's `rounding`, or config.json's, depending on `follows`.
        readonly property real base: root.follows ? Compositor.rounding : root.cfg.rounding.base

        readonly property real small: at(0)
        readonly property real normal: at(1)
        readonly property real large: at(2)

        // The corner exponent for the chassis field. 2 is a circular corner.
        //
        // NOT taken from the compositor, on purpose. Hyprland reports
        // `rounding_power = 4`, but the corner it actually DRAWS measures
        // circular: on rays from the corner centre its edge sits at a constant
        // radius, while a 4-exponent corner would reach 19% further along the
        // diagonal. Following the reported number gave the chassis a squarer
        // corner than the window it was cupping, so the gap opened out at the
        // diagonal exactly as if the radius were wrong.
        //
        // Measure the render, not the setting.
        readonly property real power: root.cfg.rounding.power

        // G2 corner smoothing, for the VECTOR primitive, which cannot draw a
        // superellipse. This is the Figma construction: it eases curvature in
        // and out along the edge rather than changing how boxy the corner is, so
        // it is not the same knob as `power` and does not substitute for it.
        // Menus and rows do not nest with window corners, so it is enough there.
        readonly property real smoothing: root.follows ? Compositor.smoothing : root.cfg.rounding.smoothing

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
        readonly property int wsMaxWindows: root.cfg.sidebar.workspaces.maxWindows
        // The row pitch of stacked window icons. Derived from the icon size
        // rather than set in pixels, so the stack keeps its proportions when
        // the icons change size.
        readonly property int wsWindowPitch: Math.round(root.font.iconSize * root.cfg.sidebar.workspaces.windowPitch)
        // The ruler down the screen's edge. See modules/sidebar/Workspaces.qml.
        readonly property int wsTick: root.cfg.sidebar.workspaces.tick
        readonly property real wsStubReach: root.cfg.sidebar.workspaces.stubReach
        readonly property real wsFullReach: root.cfg.sidebar.workspaces.fullReach
        readonly property int statusSlot: root.cfg.sidebar.status.slot
        readonly property int statusGap: root.cfg.sidebar.status.gap

        readonly property real melt: root.cfg.blob.melt
        readonly property real meltFeather: root.cfg.blob.feather

        readonly property int networkListMax: root.cfg.control.networkListMax
        readonly property int deviceListMax: root.cfg.control.deviceListMax
        readonly property int minTarget: root.cfg.control.minTarget
        readonly property real dragDismissFraction: root.cfg.control.dragDismissFraction
        readonly property real dragResistance: root.cfg.control.dragResistance
        readonly property int dragThreshold: root.cfg.control.dragThreshold
        readonly property int rowHeight: root.cfg.control.rowHeight
        readonly property real wheelRows: root.cfg.control.wheelRows
        readonly property real coastMs: root.cfg.control.coastMs
        readonly property int sliderHeight: root.cfg.control.sliderHeight
        readonly property int toggleWidth: root.cfg.control.toggleWidth
        readonly property int toggleHeight: root.cfg.control.toggleHeight

        readonly property int pickerOutline: root.cfg.picker.outline
        readonly property int launcherWidth: root.cfg.launcher.width
        readonly property int launcherIcon: root.cfg.launcher.iconSize
        readonly property int notificationWidth: root.cfg.notifications.width
        readonly property int notificationBadge: root.cfg.notifications.badge
        readonly property int cornerZone: root.cfg.notifications.cornerZone

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
