pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.config

// The big battery: a tank of liquid with the percentage written inside it.
// The 20px version for the status bar is components/BatteryMeter.qml.
//
// What is in this file, top to bottom:
//   1. inputs and colours
//   2. size, corners, margin
//   3. the wave knobs (amplitude, wavelength, speed) <- the fun ones
//   4. crest() and surface(), which build the water outline
//   5. where the percentage sits
//   6. Silhouette: the battery shape, used twice, once painted and once as a mask
//   7. the layer stack that puts it all together
//
// The level is said three ways at once: as a height, as a number, and by how
// fast the surface moves (charging runs it faster than resting).
Item {
    id: root

    // 0..1, and whether it is charging.
    property real level: 0
    property bool charging: false

    // The text inside the tank. Its own percentage unless the caller knows
    // better, like a device still being read or a machine with no battery.
    //
    // FLOORED, not rounded, and that is the whole trick that lets the water
    // move smoothly while the number stays still. `level` is continuous now
    // (the service divides watt-hours rather than taking UPower's whole-percent
    // figure), so the fill slides; the text only steps when the battery
    // genuinely loses a point. Rounding would put "100%" on a cell at 99.5,
    // which is the one reading anybody checks.
    property string reading: `${Math.floor(Math.max(0, Math.min(1, root.level)) * 100)}%`

    // Colours. The well is the same grey an unlit signal bar uses, so the two
    // drawn meters in this shell are made of the same material.
    property color liquid: Appearance.colour.accent
    property color well: Appearance.colour.fillStronger

    // Corner rounding, G2 (see G2Rect), not plain circular. The full tier, not
    // the small one: a small corner spends its whole budget turning and has no
    // room left to ramp the curvature, so the G2 shape collapses back into the
    // ordinary arc it exists to replace. This is the biggest shape in any menu
    // and the one place the ramp has room to be seen.
    readonly property real radius: Appearance.rounding.normal

    // How far the percentage sits in from the corner it is docked into.
    readonly property real margin: Appearance.padding.large

    // The widest thing this will ever have to hold. Sizing to the CURRENT
    // reading instead would make the tank flinch every time the percentage
    // gains or loses a digit.
    TextMetrics {
        id: widest

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.normal
        text: "100%"
    }

    // The reading actually on screen, so it can be placed by its ink. Its line
    // box carries the font's descent, and a number placed by the box sits
    // visibly higher off the bottom edge than off the right one.
    TextMetrics {
        id: glyphs

        font: widest.font
        text: root.reading
    }

    // Size comes from the text: wide enough for "100%" plus a margin each side,
    // then the height follows from a fixed 140:223 proportion.
    readonly property real leastWidth: Math.ceil(widest.tightBoundingRect.width + root.margin * 2)

    implicitWidth: leastWidth
    implicitHeight: Math.round(leastWidth * 223 / 140)

    // The water level eases towards the real one instead of cutting to it.
    // Matters at the two moments a battery actually moves: the jump when UPower
    // first reads the device, and each single percent step.
    Follow {
        id: charge

        target: Math.max(0, Math.min(1, root.level))
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    // WAVE KNOBS.
    //
    // wavelength: width / 2 puts exactly two waves across the tank. Keep it a
    //             whole division of the width, otherwise the two walls sit at
    //             different points in the cycle and the surface rests lopsided.
    // swell:      wave height. 0.05 of the width. The original sketch used
    //             about three times this and it read as weather, not water,
    //             and fought the number sitting in it.
    readonly property real wavelength: root.width / 2
    readonly property real swell: root.width * 0.05

    // Second wave's frequency, as a multiple of the first. Must be ABOVE 1: a
    // slower second wave beats against the first over a period longer than the
    // tank is wide, which brings the lopsidedness back. Fractional so the
    // surface never repeats itself.
    readonly property real detune: 1.7

    // How far the water climbs the walls at each end. Tied to the wave height,
    // so it stays a detail of the surface at any size. Pinned to the corner
    // radius instead, it grew a pair of horns as soon as the wave got quieter.
    readonly property real meniscus: swell

    // Shape of that climb, as a superellipse exponent. 2 is a circle, which
    // meets the wall vertically but joins the water with a visible hard spot.
    // 3 leaves the water with both slope and curvature at zero, so the curl
    // reads as the surface bending rather than an arc glued on.
    readonly property real contact: 3

    // The water line, in pixels down from the top.
    readonly property real line: root.height * (1 - charge.value)

    // Animation. phase walks the wave sideways forever; drift is how long one
    // full cycle takes. Charging runs it about three times faster, which is how
    // you can tell it is charging before reading any text. The surface is never
    // still, because a perfectly flat one reads as a picture of a battery.
    property real phase: 0

    readonly property int drift: root.charging ? Appearance.anim.slow * 6 : Appearance.anim.slow * 20

    Timer {
        interval: 16
        repeat: true
        // Nothing to move in an empty tank, and nothing to move for when the
        // menu holding it is off screen.
        running: root.visible && charge.value > 0

        onTriggered: root.phase = (root.phase + 2 * Math.PI * (interval / root.drift)) % (2 * Math.PI)
    }

    // Height of the water at x, before the walls get involved. Two sine waves
    // added together, 75% the main one and 25% the detuned one.
    function crest(x: real, amp: real): real {
        const k = 2 * Math.PI / root.wavelength;
        return root.line - amp * (0.75 * Math.sin(k * x + root.phase) + 0.25 * Math.sin(k * root.detune * x - 2 * root.phase + 1.1));
    }

    // Builds the liquid as a list of points: the surface across the top, then
    // straight down to the bottom corners. Corners of the BOUNDING BOX, not the
    // tank: the rounded corners are the mask's job below,
    // so this never has to work out where a wave crosses a squircle.
    function surface(): var {
        const w = root.width;
        const h = root.height;
        if (w <= 0 || h <= 0 || charge.value <= 0)
            return [];

        // Room left before the wave would break out of either end. A full tank
        // goes flat because it cannot slosh and an empty one because there is
        // nothing in it; both fall out of this clamp rather than being special
        // cases.
        const room = Math.min(root.line, h - root.line);
        const amp = Math.min(root.swell, room);
        const rise = Math.min(root.meniscus, room);
        const reach = Math.min(root.meniscus, w / 2);

        const pts = [];
        const n = root.contact;

        // The curl at each wall, as the superellipse
        // (1 - x/reach)^n + (1 - lift/rise)^n = 1, walked by ANGLE rather than
        // by x. Stepping x would spend every sample in the flat half and cut
        // the corner off the vertical half, which is the half doing the work.
        const turns = 10;
        const walk = (i, mirror) => {
            const t = i / turns * Math.PI / 2;
            const along = reach * (1 - Math.pow(Math.cos(t), 2 / n));
            const lift = rise * (1 - Math.pow(Math.sin(t), 2 / n));
            const x = mirror ? w - along : along;
            pts.push(Qt.point(x, root.crest(x, amp) - lift));
        };

        for (let i = 0; i <= turns; i++)
            walk(i, false);

        // The open water between the two curls, about one point every 2px:
        // fine enough that a polyline reads as a curve, coarse enough to be
        // free per frame.
        const span = w - reach * 2;
        const steps = Math.max(2, Math.round(span / 2));
        for (let i = 1; i < steps; i++) {
            const x = reach + span * i / steps;
            pts.push(Qt.point(x, root.crest(x, amp)));
        }

        for (let i = turns; i >= 0; i--)
            walk(i, true);

        // Down to the bottom corners, closing the shape.
        pts.push(Qt.point(w, h));
        pts.push(Qt.point(0, h));
        return pts;
    }

    // Where the percentage sits: bottom-right, a margin in from each edge,
    // measured from the INK of the glyphs rather than their box. Pinning it to
    // a box only looks like padding if the glyphs are narrower than the box,
    // and Monocraft's are not, so it came out jammed into the curve.
    readonly property real markX: width - root.margin - (glyphs.tightBoundingRect.x + glyphs.tightBoundingRect.width)
    readonly property real markY: height - root.margin - mark.baselineOffset - glyphs.tightBoundingRect.y - glyphs.tightBoundingRect.height

    // THE TANK'S SHAPE: one rounded rect, the whole of the item.
    //
    // It is a component because the thing that gets PAINTED and the thing that
    // MASKS are the same geometry, and this way it is written once.
    component Silhouette: Item {
        property color shade: root.well

        anchors.fill: parent

        G2Rect {
            anchors.fill: parent
            radius: root.radius
            color: parent.shade
        }
    }

    // --- the stack, back to front ---

    // 1. The empty tank.
    Silhouette {}

    // 2. The percentage in normal text colour. This is the half you see against
    //    the empty part of the tank.
    StyledText {
        id: mark

        x: root.markX
        y: root.markY
        text: root.reading
        font: widest.font
    }

    // 3. The liquid, drawn off screen (visible: false + layer) because it is
    //    needed twice: painted below, and again as the mask for the lit text.
    Shape {
        id: wave

        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        visible: false

        ShapePath {
            fillColor: root.liquid
            strokeWidth: 0
            strokeColor: "transparent"

            PathPolyline {
                path: root.surface()
            }
        }
    }

    // The battery shape again, white, purely as a mask. Only its alpha is read;
    // the colour is just what makes it opaque.
    Silhouette {
        id: silhouette

        shade: "white"
        layer.enabled: true
        visible: false
    }

    // The liquid clipped to the battery shape. This is the water you see.
    MultiEffect {
        anchors.fill: parent
        source: wave
        maskEnabled: true
        maskSource: silhouette
    }

    // 4. The percentage again, in the on-accent colour, clipped to the liquid.
    //    Two copies with the water as the boundary means the number stays
    //    readable at every level and flips colour exactly where the water line
    //    crosses it.
    //
    //    Full size rather than text size: MultiEffect stretches the mask across
    //    the whole item, so the masked thing and the mask must be the same
    //    rectangle or the water lands somewhere else entirely.
    Item {
        id: lit

        anchors.fill: parent
        layer.enabled: true
        visible: false

        StyledText {
            x: root.markX
            y: root.markY
            text: root.reading
            font: widest.font
            color: Appearance.colour.accentText
        }
    }

    MultiEffect {
        anchors.fill: parent
        source: lit
        maskEnabled: true
        maskSource: wave
    }
}
