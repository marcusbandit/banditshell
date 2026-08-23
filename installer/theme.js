.pragma library

// The installer's palette and scales, copied rather than imported.
//
// Every other file in this repo reaches these through qs.config, and this one
// deliberately cannot: the whole premise of the installer is that banditshell is
// not installed yet, so a surface that needed the shell's own singletons to draw
// could not run until the thing it is installing already worked. So the numbers
// live here, verbatim, and the only maintenance rule is that they must keep
// matching their sources.
//
// Sources, if any of this ever drifts:
//   palette  config/Themes.qml, the `slate` Theme
//   type     config/Config.qml font block: base 9, scale [2, 3, 4]
//   rounding config/Config.qml rounding block: base 15, scale [0.6, 1, 1.6]
//   padding  config/Config.qml padding block: base 6, scale [1, 2, 4, 6]

// -- slate, verbatim from config/Themes.qml --------------------------------
// A luminance ramp from near-black to near-white, plus three saturated accents
// and the one colour outside the hue family.
var ramp = ["#08090b", "#0f1114", "#181b1f", "#1d2126", "#262b31", "#3a4149",
    "#545d67", "#78838f", "#a5aeb8", "#d0d7dd", "#eef2f5"];
var dim = "#5b8fb0";
var mid = "#7fb3d4";
var bright = "#b8dcf0";
var alarm = "#ff7a4d";

// Roles, so nothing below names a ramp index by hand.
var void_ = ramp[0];      // the ground
var body = ramp[2];       // a panel
var plate = ramp[3];      // a panel on a panel
var fill = ramp[4];       // a track, a field
var edge = ramp[5];       // a hairline
var textFaint = ramp[6];
var textDim = ramp[8];
var text = ramp[10];

// -- THREE sizes, and there is no fourth ------------------------------------
// Monocraft's em is exactly 9 design pixels, so every size is a multiple of 9
// or the whole font lands between pixels. base 9, multipliers 2, 3, 4.
var fontFamily = "Monocraft";
var small = 18;
var normal = 27;
var large = 36;

// Hierarchy that is NOT size: weight, colour, opacity, spacing. See
// ~/.claude/rules/type-scale.md.

// -- rounding ---------------------------------------------------------------
var rSmall = 9;
var rNormal = 15;
var rLarge = 24;
// The superellipse exponent. |x|^n + |y|^n = r^n. Never a circular arc.
var power = 5.0;

// -- padding ----------------------------------------------------------------
var padSmall = 6;
var padNormal = 12;
var padLarge = 24;
var padHuge = 36;
