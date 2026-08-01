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

        // Fills. `fill` is a hover, `fillStrong` is a selection. Neither is a
        // colour: they are the same light, turned up.
        readonly property color fill: root.veil(root.cfg.material.fill[0])
        readonly property color fillStrong: root.veil(root.cfg.material.fill[1])
        readonly property color fillStronger: root.veil(root.cfg.material.fill[2])

        readonly property color separator: root.veil(root.cfg.material.separator)

        // The saturated end of the theme. Reserved for state that is genuinely
        // worth a colour, never for decoration or for filling a shape.
        readonly property color accent: root.theme[root.cfg.colour.accent]

        // The screen-corner frame. Not from the ramp: it is meant to read as the
        // absence of screen, not as part of the palette.
        readonly property color frame: root.cfg.edge.outerColour
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
    }

    readonly property QtObject rounding: QtObject {
        // Hyprland's `rounding`, or config.json's, depending on `follows`.
        readonly property real base: root.follows ? Compositor.rounding : root.cfg.rounding.base

        readonly property real small: at(0)
        readonly property real normal: at(1)
        readonly property real large: at(2)

        // G2 corner smoothing, see ~/.claude/rules/g2-corners.md. Following the
        // compositor converts its superellipse exponent (`rounding_power`) into
        // the same idea: 2 is a circular corner, higher is smoother.
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

        // Exponential-smoothing rate for anything that tracks a target
        // (see ~/.claude/rules/animation-smoothing.md).
        readonly property real trackSpeed: root.cfg.anim.trackSpeed
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
        readonly property int statusSlot: root.cfg.sidebar.status.slot
        readonly property int statusGap: root.cfg.sidebar.status.gap

        readonly property bool roundOuter: root.cfg.edge.roundOuter
        readonly property real outerRadius: root.rounding.at(root.cfg.edge.outerTier)
    }
}
