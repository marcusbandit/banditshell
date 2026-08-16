import QtQuick
import QtQuick.Shapes
import qs.config

// A battery, drawn rather than named.
//
// The icon font can only say a battery it has a glyph for: six discharging
// steps, and a charging set that skips 40, 70 and 100, so `battery_charging_60`
// has to stand in for anything from the fifties to the seventies and a charge
// cycle spends most of its length showing one unchanging picture. A meter has
// every level, and can show the thing no glyph can: that the level is MOVING.
//
// Charging is a sweep that runs from the real level up to the top and fades,
// over and over. The fill itself stays honest at the percentage. The common
// alternative, looping the fill itself from empty to full, animates away the
// one number you went there to read.
Item {
    id: root

    // 0..1.
    property real level: 0
    property bool charging: false

    // Running out. Decided by services/Battery.qml, not by comparing `level`
    // here, so the meter cannot disagree with the notification that went out.
    property bool low: false

    // The lit colour, handed down by whatever indicator this sits in, so the
    // meter brightens on hover and goes accent on alert without having to know
    // what either of those means.
    property color colour: Appearance.colour.text

    // The same as an unlit signal bar, so the two drawn meters in the bar are
    // made of one material: empty has to lose against full at a glance, at this
    // size. A FILL tier rather than a label one, because the track is the thing
    // the charge sits in, not something being said.
    property color trackColour: Appearance.colour.fillStronger

    // THE WARNING GOES ON THE WELL, NOT THE FILL: at 15% the lit part is three
    // pixels, and three recoloured pixels are only visible to someone already
    // looking. The empty part carries it, so the emptier the cell the louder.
    //
    // Two things here that look simpler than they are:
    //   - a low ALPHA over the panel, not a mix towards trackColour. The track
    //     is a pale veil and mixing into it turned the orange brown.
    //   - the alpha ceiling stays under the fill's own weight, or the breath
    //     swallows the reading at its peak.
    readonly property color well: root.low ? Qt.rgba(root.colour.r, root.colour.g, root.colour.b, 0.18 + 0.34 * root.throb) : root.trackColour

    // THE BOLT IS THE ONE ACCENT IN THE BAR THAT IS NOT AN ALERT.
    //
    // modules/sidebar/StatusIcon.qml keeps accent for `alert` alone, so that a
    // colour in the bar always means the same thing, and this is a deliberate
    // exception to that rather than an oversight: charging is the one state the
    // bar reports that is good news, and it is already saying so with a shape
    // nothing else in the bar has. The rule holds where it matters, which is
    // that accent never appears here on a state you would want to ignore.
    property color boltColour: Appearance.colour.accent

    readonly property real unit: Appearance.font.iconSize

    // Every part is a fraction of the icon size rather than a pixel count, so
    // the meter keeps its proportions if the icon tier moves.
    readonly property real capWidth: Math.max(2, Math.round(unit * 0.09))
    readonly property real inset: Math.max(1, Math.round(unit * 0.08))

    implicitWidth: Math.round(unit)
    implicitHeight: Math.round(unit * 0.55)

    // The fill TRAVELS to the level rather than cutting to it, which matters
    // most at the two moments a battery actually changes: the jump UPower makes
    // when it first reads the device, and the step at each percent.
    Follow {
        id: charge

        target: Math.max(0, Math.min(1, root.level))
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    // A LIGHTNING BOLT, as one closed path in a unit square. Written as points
    // and scaled at draw time rather than as a fixed pixel path, so it follows
    // the icon tier wherever that goes.
    readonly property var boltPoints: [[0.62, 0.00], [0.00, 0.58], [0.38, 0.58], [0.30, 1.00], [1.00, 0.40], [0.55, 0.40]]

    // How much of the bar's height the bolt spans, and how wide it is for that
    // height. A bolt is taller than it is wide; both are proportions so nothing
    // here breaks when the size changes.
    readonly property real boltHeight: 0.86
    readonly property real boltAspect: 0.62

    function bolt(w: real, h: real): string {
        const bh = h * root.boltHeight;
        const bw = bh * root.boltAspect;
        const x = (w - bw) / 2;
        const y = (h - bh) / 2;
        return root.boltPoints.map((p, i) => `${i === 0 ? "M" : "L"} ${x + p[0] * bw} ${y + p[1] * bh}`).join(" ") + " Z";
    }

    // The sweep's clock, 0 to 1 over and over, and only while there is something
    // to say: a battery that is full is not filling.
    property real sweep: 0

    NumberAnimation on sweep {
        running: root.charging && charge.value < 1
        loops: Animation.Infinite
        from: 0
        to: 1
        duration: Appearance.anim.slow * 6
    }

    // The warning's clock, 0 to 1 and back. Colour is what a glance reads;
    // motion is what gets the glance, and peripheral vision sees movement far
    // better than hue.
    //
    // A BREATH, NOT A BLINK: sine-eased, ~2.5s a cycle (slow * 4 each way). A
    // hard flash at this size is a fault light, and you would turn it off before
    // the battery ran out. Fixed-duration like the sweep above, since it is a
    // loop with a shape rather than something tracking a target.
    property real throb: 0

    SequentialAnimation on throb {
        running: root.low
        loops: Animation.Infinite

        NumberAnimation {
            from: 0
            to: 1
            duration: Appearance.anim.slow * 4
            easing.type: Easing.InOutSine
        }

        NumberAnimation {
            from: 1
            to: 0
            duration: Appearance.anim.slow * 4
            easing.type: Easing.InOutSine
        }
    }

    G2Rect {
        id: track

        width: root.width - root.capWidth
        height: root.height
        radius: root.height / 3
        color: root.well

        readonly property real span: width - root.inset * 2

        // The charge.
        G2Rect {
            x: root.inset
            y: root.inset
            width: track.span * charge.value
            height: track.height - root.inset * 2
            radius: height / 3
            color: root.colour
        }

        // What is missing, filling in. It grows from the top of the fill rather
        // than from the empty end, so the eye reads it as the charge advancing
        // rather than as a second bar arriving from the right.
        //
        // It holds its opacity for most of the sweep and drops away at the very
        // end, instead of fading as it grows. The gentler curve was invisible:
        // by the time the band was wide enough to notice at this size it had
        // already faded to nothing, so the meter looked static while charging,
        // which is the exact failure this replaces.
        G2Rect {
            visible: root.charging
            x: root.inset + track.span * charge.value
            y: root.inset
            width: track.span * (1 - charge.value) * root.sweep
            height: track.height - root.inset * 2
            radius: height / 3
            color: root.colour
            opacity: 0.7 * (1 - root.sweep * root.sweep * root.sweep)
        }

        // THE BOLT, which is what actually says "charging" here.
        //
        // The sweep above says it by MOVING, and motion is the better signal
        // for the moment you happen to be looking at the bar. This is for every
        // other moment: a still frame of the old meter could not tell charging
        // from discharging, because the only other difference was one label
        // tier, and hovering produces that same tier for a different reason.
        //
        // Stroked in the track's colour, which is what lets one shape read at
        // any level without knowing where the charge has got to: over the empty
        // end the green body carries it, and over the charge, where green sits
        // on a near-white fill, the dark outline is what separates them.
        //
        // Stroked in the WELL's colour rather than the plain track. They are the
        // same today (`low` is false whenever the charger is in), and this stays
        // right if that ever changes.
        //
        // One stroked shape rather than the two masked copies BatteryTank uses
        // for the same problem, because that costs two layer textures and this
        // is a 20px icon that is always on screen.
        Shape {
            anchors.fill: parent
            visible: root.charging
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                fillColor: root.boltColour
                strokeColor: root.well
                strokeWidth: Math.max(1, Math.round(root.height * 0.1))

                PathSvg {
                    path: root.bolt(track.width, track.height)
                }
            }
        }
    }

    // The nub. At this size it is most of what makes the shape read as a
    // battery rather than as a progress bar. Well colour, warning and all: a
    // grey nub on a lit battery reads as a chip out of the shape.
    G2Rect {
        x: root.width - root.capWidth
        y: (root.height - height) / 2
        width: root.capWidth
        height: Math.round(root.height * 0.45)
        radius: width / 3
        color: root.well
    }
}
