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

    readonly property QtObject colour: QtObject {
        readonly property real surfaceStep: root.cfg.colour.surface
        readonly property real opacity: root.cfg.colour.surfaceOpacity

        // A panel face, lit from above: `surface` is the bottom of the gradient,
        // `surfaceTop` the top. Flat only if depth.lift is 0.
        readonly property color surface: root.rampAt(surfaceStep, opacity)
        readonly property color surfaceTop: root.rampAt(surfaceStep + root.cfg.depth.lift, opacity)

        // A channel machined into that face: the lighting inverts, dark at the
        // top, which is the whole reason a recess reads as a recess.
        readonly property color inset: root.rampAt(surfaceStep - root.cfg.depth.inset, opacity)
        readonly property color insetBottom: root.rampAt(surfaceStep, opacity)

        readonly property color surfaceAlt: root.rampAt(root.cfg.colour.surfaceAlt, 1)

        // Specular hairline where a surface presents a free edge to the light.
        readonly property color bevel: root.rampAt(surfaceStep + root.cfg.depth.bevelStep, root.cfg.depth.bevelAlpha)

        // An engraved line: a dark score with a lit lower lip.
        readonly property color engraveDark: root.rampAt(surfaceStep - root.cfg.depth.engraveStep, 1)
        readonly property color engraveLight: root.rampAt(surfaceStep + root.cfg.depth.engraveStep, 1)

        readonly property color text: root.rampAt(root.cfg.colour.text, 1)
        readonly property color textDim: root.rampAt(root.cfg.colour.textDim, 1)
        readonly property color textFaint: root.rampAt(root.cfg.colour.textFaint, 1)

        // The saturated end of the theme, spent sparingly so a bright stop reads
        // as a highlight rather than as decoration.
        readonly property color accent: root.theme[root.cfg.colour.accent]
        readonly property color accentDim: root.theme.mid
        // NOT named onAccent: QML reads a property starting with "on" + capital
        // as a signal handler.
        readonly property color accentText: root.rampAt(root.cfg.colour.accentText, 1)

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

    readonly property QtObject depth: QtObject {
        readonly property real bevelWidth: root.cfg.depth.bevelWidth
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
