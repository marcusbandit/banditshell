pragma Singleton

import QtQuick
import Quickshell

// Design tokens. Every colour, size, radius and duration in the shell comes from
// here, so the whole look can be changed in one file. Nothing else hardcodes a
// hex value or a magic number.
Singleton {
    id: root

    readonly property Colours colour: Colours {}
    readonly property Font font: Font {}
    readonly property Padding padding: Padding {}
    readonly property Rounding rounding: Rounding {}
    readonly property Anim anim: Anim {}
    readonly property Sizes sizes: Sizes {}

    // Lush pixel vibes in a premium chassis: a deep moss chassis, everything on
    // it green-tinted, and one bright living green for state. Hierarchy comes
    // from opacity tiers, never from more hues.
    component Colours: QtObject {
        readonly property color surface: "#e61b3a2b"     // deep moss panel, 90% opaque
        readonly property color surfaceAlt: "#26d9ffe8"  // faint mint wash, for hover
        readonly property color text: "#f2fff8"
        readonly property color textDim: "#a6cfe8d8"
        readonly property color textFaint: "#73a8c6b4"
        readonly property color accent: "#7fe6a5"        // the "you are here" fill
        // Text sitting on top of `accent`. NOT named onAccent: QML reads a
        // property starting with "on" + capital as a signal handler.
        readonly property color accentText: "#0f2419"
    }

    component Font: QtObject {
        readonly property string family: "Monocraft"
        readonly property FontSizes size: FontSizes {}
    }

    // THREE SIZES. That is the whole scale, for the whole shell.
    // Hierarchy is carried by colour, spacing and fills instead of by more sizes
    // (see ~/.claude/rules/type-scale.md). Never write a pixel size inline.
    component FontSizes: QtObject {
        readonly property int base: 16
        readonly property int small: Math.round(base * 0.75)   // 12 - labels, metadata
        readonly property int normal: base                     // 16 - the default
        readonly property int large: Math.round(base * 1.75)   // 28 - the point of a view
    }

    component Padding: QtObject {
        readonly property int base: 8
        readonly property int small: Math.round(base / 2)
        readonly property int normal: base
        readonly property int large: Math.round(base * 1.5)
        readonly property int huge: Math.round(base * 2.5)
    }

    component Rounding: QtObject {
        readonly property int small: 8
        readonly property int normal: 14
        readonly property int large: 22
        // G2 corner smoothing, see ~/.claude/rules/g2-corners.md.
        // 0 = plain circular arc (banned), 0.6 = iOS squircle.
        readonly property real smoothing: 0.6
    }

    component Anim: QtObject {
        readonly property int fast: 150
        readonly property int normal: 220
        readonly property int slow: 320
        // Exponential-smoothing rate for anything that *tracks* a target
        // (see ~/.claude/rules/animation-smoothing.md). Higher = snappier.
        readonly property real trackSpeed: 14
    }

    component Sizes: QtObject {
        // Width of the invisible interaction ring around the screen.
        // Matches Hyprland's gaps_out = 10.
        readonly property int border: 10
        readonly property int sidebarWidth: 76
        readonly property int wsSlot: 30       // one workspace indicator
        readonly property int wsGap: 6         // gap between them
    }
}
