import QtQuick
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

    // The lit colour, handed down by whatever indicator this sits in, so the
    // meter brightens on hover and goes accent on alert without having to know
    // what either of those means.
    property color colour: Appearance.colour.text

    // The same as an unlit signal bar, so the two drawn meters in the bar are
    // made of one material: empty has to lose against full at a glance, at this
    // size. A FILL tier rather than a label one, because the track is the thing
    // the charge sits in, not something being said.
    property color trackColour: Appearance.colour.fillStronger

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

    G2Rect {
        id: track

        width: root.width - root.capWidth
        height: root.height
        radius: root.height / 3
        color: root.trackColour

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
    }

    // The nub. At this size it is most of what makes the shape read as a
    // battery rather than as a progress bar.
    G2Rect {
        x: root.width - root.capWidth
        y: (root.height - height) / 2
        width: root.capWidth
        height: Math.round(root.height * 0.45)
        radius: width / 3
        color: root.trackColour
    }
}
