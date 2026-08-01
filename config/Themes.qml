pragma Singleton

import QtQuick
import Quickshell

// Every palette the shell can wear, keyed by name. `Config.theme` picks one.
//
// A theme is a luminance RAMP plus three saturated ACCENTS. It never names a
// widget: "which colour is the panel" is a decision for Appearance.qml, so a new
// theme only has to supply colours, not know what they are used for.
//
// To add a theme: add a Theme block, add it to `all`. Nothing else changes.
Singleton {
    id: root

    readonly property string fallback: "greensteel"

    readonly property var all: ({
            greensteel: greensteel,
            slate: slate
        })

    readonly property var names: Object.keys(all)

    function get(name: string): Theme {
        return all[name] ?? all[fallback];
    }

    // A ramp climbing from near-black to near-white in one hue family, plus the
    // saturated end. Eleven stops so widgets can pick a tier rather than nudging
    // a hex value: `ramp[0]` is the darkest, `ramp[10]` the lightest.
    component Theme: QtObject {
        required property string name
        required property var ramp     // 11 colours, dark -> light
        required property color dim    // saturated, quietest
        required property color mid    // saturated, standard
        required property color bright // saturated, the specular spike
    }

    // Cool anodised-green metal. Kept in step with
    // ~/.config/hypr/theme/greensteel.conf: same names, same values, so the
    // shell and the compositor's window borders are one object.
    readonly property Theme greensteel: Theme {
        name: "greensteel"
        //     void      abyss     dark      plate     body      brushed
        ramp: ["#070c0a", "#0d1512", "#16211c", "#1b2a23", "#22322b", "#33493f",
            //  edge      lit       pale      silver    chrome
            "#4c6b5c", "#6e9384", "#9dbdaf", "#c9e2d7", "#eaf6f0"]
        dim: "#3fbf8f"      // verdigris
        mid: "#5fd99a"      // lush
        bright: "#8cffc0"   // phosphor
    }

    // The same metal with the green taken out, as a second option to prove the
    // theme swap works and nothing hardcodes a hue.
    readonly property Theme slate: Theme {
        name: "slate"
        ramp: ["#08090b", "#0f1114", "#181b1f", "#1d2126", "#262b31", "#3a4149",
            "#545d67", "#78838f", "#a5aeb8", "#d0d7dd", "#eef2f5"]
        dim: "#5b8fb0"
        mid: "#7fb3d4"
        bright: "#b8dcf0"
    }
}
