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

    function tier(base: real, scale: var, i: int): real {
        return base * scale[Math.max(0, Math.min(i, scale.length - 1))];
    }

    readonly property QtObject colour: QtObject {
        readonly property var ramp: root.theme.ramp

        // Panels are translucent; everything else is opaque.
        readonly property color surfaceBase: ramp[root.cfg.colour.surface]
        readonly property color surface: Qt.rgba(surfaceBase.r, surfaceBase.g, surfaceBase.b, root.cfg.colour.surfaceOpacity)

        readonly property color surfaceAlt: ramp[root.cfg.colour.surfaceAlt]
        readonly property color text: ramp[root.cfg.colour.text]
        readonly property color textDim: ramp[root.cfg.colour.textDim]
        readonly property color textFaint: ramp[root.cfg.colour.textFaint]

        // The saturated end of the theme, spent sparingly so a bright stop reads
        // as a highlight rather than as decoration.
        readonly property color accent: root.theme[root.cfg.colour.accent]
        // NOT named onAccent: QML reads a property starting with "on" + capital
        // as a signal handler.
        readonly property color accentText: ramp[root.cfg.colour.accentText]
    }

    readonly property QtObject font: QtObject {
        readonly property string family: root.cfg.font.family

        // THREE SIZES, shell-wide. Hierarchy is carried by colour, spacing and
        // fills instead (see ~/.claude/rules/type-scale.md).
        readonly property QtObject size: QtObject {
            readonly property int small: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 0))
            readonly property int normal: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 1))
            readonly property int large: Math.round(root.tier(root.cfg.font.base, root.cfg.font.scale, 2))
        }
    }

    readonly property QtObject rounding: QtObject {
        readonly property real small: root.tier(root.cfg.rounding.base, root.cfg.rounding.scale, 0)
        readonly property real normal: root.tier(root.cfg.rounding.base, root.cfg.rounding.scale, 1)
        readonly property real large: root.tier(root.cfg.rounding.base, root.cfg.rounding.scale, 2)

        // G2 corner smoothing, see ~/.claude/rules/g2-corners.md.
        readonly property real smoothing: root.cfg.rounding.smoothing

        // Any tier by index, for things that take the tier as a setting.
        function at(i: int): real {
            return root.tier(root.cfg.rounding.base, root.cfg.rounding.scale, i);
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
        readonly property int border: root.cfg.edge.border
        readonly property int sidebarWidth: root.cfg.sidebar.width
        readonly property real sidebarFlare: root.rounding.at(root.cfg.sidebar.flareTier)
        readonly property int wsSlot: root.cfg.sidebar.workspaces.slot
        readonly property int wsGap: root.cfg.sidebar.workspaces.gap
        readonly property int wsPersistent: root.cfg.sidebar.workspaces.persistent
    }
}
