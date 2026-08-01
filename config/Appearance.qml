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

    // GREENSTEEL, taken verbatim from ~/.config/hypr/theme/greensteel.conf so the
    // shell and the compositor are the same object. Cool anodised-green metal:
    // one hue family (~158deg, green leaning cyan, never olive) climbing from
    // near-black to silvery white. Metal reads as metal because of the luminance
    // ramp and a rare specular spike, not because of hue.
    //
    // If greensteel.conf changes, change these to match. Same names.
    component Ramp: QtObject {
        readonly property color deepest: "#070c0a"    // $gsVoid (renamed: `void` is reserved)
        readonly property color abyss: "#0d1512"
        readonly property color dark: "#16211c"
        readonly property color body: "#22322b"
        readonly property color brushed: "#33493f"
        readonly property color edge: "#4c6b5c"
        readonly property color lit: "#6e9384"
        readonly property color pale: "#9dbdaf"
        readonly property color silver: "#c9e2d7"
        readonly property color chrome: "#eaf6f0"
        readonly property color white: "#f7fdfa"

        // The lush end, where the green actually saturates. Used sparingly: the
        // borders spend most of their length dark so a bright stop reads as a
        // highlight catching an edge. Same discipline here.
        readonly property color verdigris: "#3fbf8f"
        readonly property color lush: "#5fd99a"
        readonly property color phosphor: "#8cffc0"
    }

    // What the ramp is used FOR. Widgets read these, not the ramp.
    //
    // greensteel.conf's Monocraft note is load-bearing: a pixel font has
    // one-device-pixel stems, so anti-aliasing has nothing to work with and
    // mid-tones turn it to mush. Pixel text goes phosphor or silver on abyss or
    // void. NEVER on body or brushed.
    component Colours: QtObject {
        readonly property Ramp ramp: Ramp {}

        readonly property color surface: "#f20d1512"     // abyss, 95%: dark enough for Monocraft
        readonly property color surfaceAlt: ramp.dark    // hover lift, one step up and no further

        readonly property color text: ramp.silver
        readonly property color textDim: ramp.pale
        readonly property color textFaint: ramp.lit

        readonly property color accent: ramp.phosphor    // the specular spike: one at a time
        // Text sitting on top of `accent`. NOT named onAccent: QML reads a
        // property starting with "on" + capital as a signal handler.
        readonly property color accentText: ramp.abyss
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
        // Matches Hyprland's `rounding = 15` in hyprland/general.conf, so shell
        // corners and window corners are the same size. Hyprland is already
        // drawing superellipse corners there (`rounding_power = 4.0`), which is
        // the same idea as our G2 smoothing.
        readonly property int normal: 15
        readonly property int large: 24
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
