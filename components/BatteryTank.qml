import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import qs.config

// The battery as a TANK OF LIQUID, for the one place there is room to draw it.
//
// BatteryMeter is the same fact at 20px: a track, a fill and a nub, because at
// the size of a status glyph nothing else survives. This is what the menu can
// afford instead. It says the level twice over, as a height and as a number, and
// it says the direction by moving: a charging tank runs its surface faster than
// a resting one, so "is it going up" is answered before the percentage is read.
//
// Three things here are not decoration and are worth the code:
//
//   the SURFACE is two sine harmonics rather than one, so it never repeats and
//   reads as liquid rather than as a graph;
//
//   the MENISCUS turns the surface into the tank wall on a superellipse arc,
//   vertical where it meets the wall and flat where it meets the water. A wave
//   cut off square against the wall reads as a stripe, which is the failure the
//   design's note about a "metaball connection" is describing;
//
//   the READING is drawn twice, dark over the liquid and light over the empty
//   well, and the liquid itself is the mask between them. One colour would have
//   been unreadable at one end of the range or the other, and the crossing
//   happens at whatever percentage the number happens to sit at.
//
// Everything geometric is a ratio of the type tier and the rounding base, so the
// tank rescales with the shell rather than being a 140x223 box that stops
// fitting the moment either moves. See ~/.claude/rules/math-over-hardcoding.md.
Item {
    id: root

    // 0..1.
    property real level: 0
    property bool charging: false

    // What the tank SAYS, which is its own percentage unless the caller has
    // something truer: a device still being read, or a machine that has none.
    property string reading: `${Math.round(Math.max(0, Math.min(1, root.level)) * 100)}%`

    // The charge, and the well it sits in. The well is the same colour an unlit
    // signal bar is, so the two drawn meters in this shell are made of one
    // material; the charge is the accent, which is the whole of what the accent
    // is for.
    property color liquid: Appearance.colour.accent
    property color well: Appearance.colour.fillStronger

    // THE DESIGN, AS RATIOS. It was drawn at the 27px tier as a 140 x 223 tank
    // on a 9px corner, with a wave 80 across and 40 from trough to crest. Only
    // the two tokens below are numbers here; the rest are those proportions.
    readonly property real unit: Appearance.font.size.large
    readonly property real radius: Appearance.rounding.small

    implicitWidth: Math.round(unit * 140 / 27)
    implicitHeight: Math.round(implicitWidth * 223 / 140)

    // THE WAVE, CALMER THAN THE SKETCH. The design drew it with 40px circles on
    // a 140px tank, which is a fifth of the tank's height moving: at that size
    // it is not a surface, it is weather, and it fights the number sitting in
    // it. A third of that amplitude still reads as liquid and stops shouting.
    //
    // TWO PERIODS ACROSS, exactly, rather than the sketch's one and three
    // quarters. A whole number means both walls are always at the same point in
    // the cycle, so the surface is symmetric at rest instead of sitting high at
    // one end and low at the other.
    readonly property real wavelength: root.width / 2
    readonly property real swell: root.width * 7 / 140

    // The second harmonic's wavenumber, as a multiple of the first. ABOVE it,
    // not below: a slower second wave beats against the first with a period
    // longer than the tank is wide, which is exactly the lopsidedness the whole
    // number above removes. A faster one rides on top as texture instead, and
    // being fractional it keeps the surface from ever repeating.
    readonly property real detune: 1.7

    // How far the surface climbs the wall, and how far in from the wall it takes
    // to get there. The wave's own amplitude, so the meniscus stays a detail of
    // the surface at any size: pinned to the corner radius instead, it grew into
    // a pair of horns at the walls the moment the wave got quieter.
    readonly property real meniscus: root.swell

    // The meniscus arc's exponent. 2 is a circle, which meets the wall
    // vertically but joins the water with its curvature still at 1/r, so the
    // join is G1 and shows as a hard spot. At 3 the arc leaves the water with
    // both its slope AND its curvature at zero, which is what makes the fillet
    // read as the surface bending rather than as an arc glued on.
    // See ~/.claude/rules/g2-corners.md.
    readonly property real contact: 3

    // Where the water sits, and how fast it walks there. The level TRAVELS
    // rather than cutting, which matters at the two moments a battery actually
    // moves: the jump UPower makes when it first reads the device, and the step
    // at each percent.
    Follow {
        id: charge

        target: Math.max(0, Math.min(1, root.level))
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    readonly property real line: root.height * (1 - charge.value)

    // THE SURFACE IS NEVER STILL, and it is not still because a resting liquid
    // that is perfectly flat reads as a picture of a battery rather than as one.
    // Charging simply runs the same motion three times faster, which is the
    // difference the meter is there to show.
    //
    // Wrapping at a full turn keeps the second harmonic seamless too, which is
    // why its phase term is a whole multiple of this one's.
    property real phase: 0

    readonly property int drift: root.charging ? Appearance.anim.slow * 6 : Appearance.anim.slow * 20

    Timer {
        interval: 16
        repeat: true
        // Nothing to move when the tank is empty, and nothing to move for when
        // the menu holding it is off screen.
        running: root.visible && charge.value > 0

        onTriggered: root.phase = (root.phase + 2 * Math.PI * (interval / root.drift)) % (2 * Math.PI)
    }

    // The water line at x, before the walls get their say.
    function crest(x: real, amp: real): real {
        const k = 2 * Math.PI / root.wavelength;
        return root.line - amp * (0.75 * Math.sin(k * x + root.phase) + 0.25 * Math.sin(k * root.detune * x - 2 * root.phase + 1.1));
    }

    // The liquid's outline: the surface across the top, then straight down to
    // the corners of the bounding box. The BOX, not the tank: the rounded ends
    // are the mask's job below, so this never has to work out where a wave
    // crosses a squircle.
    function surface(): var {
        const w = root.width;
        const h = root.height;
        if (w <= 0 || h <= 0 || charge.value <= 0)
            return [];

        // How much room the surface has before it would break the far end of the
        // tank. A full battery is flat because a full tank cannot slosh, and an
        // empty one is flat because there is nothing in it; both fall out of this
        // rather than being special cases.
        const room = Math.min(root.line, h - root.line);
        const amp = Math.min(root.swell, room);
        const rise = Math.min(root.meniscus, room);
        const reach = Math.min(root.meniscus, w / 2);

        const pts = [];
        const n = root.contact;

        // The meniscus, as the superellipse (1 - x/reach)^n + (1 - lift/rise)^n = 1,
        // walked by ANGLE rather than by x. Stepping x would spend every sample
        // in the flat half and cut the corner off the vertical half, which is the
        // half that does the work.
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

        // The open water between the two walls, at about two pixels a sample:
        // fine enough that a polyline is a curve and coarse enough that a frame
        // costs nothing.
        const span = w - reach * 2;
        const steps = Math.max(2, Math.round(span / 2));
        for (let i = 1; i < steps; i++) {
            const x = reach + span * i / steps;
            pts.push(Qt.point(x, root.crest(x, amp)));
        }

        for (let i = turns; i >= 0; i--)
            walk(i, true);

        pts.push(Qt.point(w, h));
        pts.push(Qt.point(0, h));
        return pts;
    }

    // WHERE THE READING SITS: a box 63 x 61.5 flush into the tank's bottom-right
    // corner, so its centre is half a box in from each edge. Ratios again, and
    // the ink is centred optically rather than by its line box; see StyledText.
    readonly property real markCx: root.width - root.width * (63 / 140) / 2
    readonly property real markCy: root.height - root.height * (61.5 / 223) / 2

    // The empty tank.
    G2Rect {
        anchors.fill: parent
        radius: root.radius
        color: root.well
    }

    // The reading, unlit: what you see through the empty part of the tank.
    StyledText {
        id: mark

        x: root.markCx - width / 2 + inkOffsetX
        y: root.markCy - height / 2 + inkOffsetY
        text: root.reading
        font.pixelSize: Appearance.font.size.large
    }

    // The liquid, rendered to a texture rather than to the scene: it is both the
    // thing that gets drawn and the mask the lit reading is cut with, and one
    // shape can be both without being drawn twice.
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

    // The tank's own outline, as a mask. The liquid is drawn square to the
    // bounding box and trimmed to this, so the rounded ends come from the one
    // corner primitive rather than from a second copy of the geometry.
    G2Rect {
        id: silhouette

        anchors.fill: parent
        radius: root.radius
        // Only the alpha is read; the colour is what makes it opaque.
        color: "white"
        layer.enabled: true
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: wave
        maskEnabled: true
        maskSource: silhouette
    }

    // The reading again, in the colour that goes ON the accent, cut to the
    // liquid. FULL SIZE rather than the size of the text: MultiEffect stretches
    // a mask across the item it is applied to, so the masked thing and the mask
    // have to be the same rectangle or the surface lands somewhere else entirely.
    Item {
        id: lit

        anchors.fill: parent
        layer.enabled: true
        visible: false

        StyledText {
            x: mark.x
            y: mark.y
            text: root.reading
            font: mark.font
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
