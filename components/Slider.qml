import QtQuick
import qs.config

// A value you drag, by a BEAD on a rail.
//
// It does NOT own its value. `value` is bound to whatever it controls and only
// changes when that thing changes; dragging emits `moved`, and the caller sets
// the real thing, which comes back round. Owning the value locally would make
// the slider disagree with reality the moment anything else changed the volume,
// which is exactly when you are most likely to be looking at it.
//
// The bead is the same object a Toggle's knob is and the same one the workspace
// column is strung with: a bright round thing riding a dim track. It is not
// decoration. A bare fill says what the value IS and never says that you can
// change it, and every fill in the sound menu is something you change.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1

    // Where "normal" ends, in value units. Past this the fill warns rather than
    // reassures: volume above 100% is amplification.
    property real warnAbove: 1

    // How far one notch of the wheel moves it, in value units. Five points of
    // volume, which is the granularity a person actually thinks in.
    property real step: 0.05

    // Still shows its value, but says the value is not in effect. Emptying the
    // track instead would throw away the one thing you want to know while muted:
    // what it will go back to.
    property bool dimmed: false

    signal moved(real value)

    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / Math.max(0.0001, to - from)))
    readonly property bool active: pointer.pressed || pointer.containsMouse

    // ONE colour at two weights. The fill is the same light as the bead, turned
    // down: this material separates things by opacity, never by inventing a
    // second colour (see Appearance's ramp).
    readonly property color lit: root.dimmed ? Appearance.colour.textFaint : root.value > root.warnAbove ? Appearance.colour.accent : Appearance.colour.text

    readonly property real rail: Appearance.sizes.sliderHeight

    // The bead's size at rest, and the travel that follows from it: the bead
    // stays inside the rail's ends rather than half hanging off them, so the
    // control's full width is reachable and looks it. A read-only slider has no
    // bead and therefore no inset, and the fill runs the whole rail.
    readonly property real beadSize: root.enabled ? rail * 2.2 : 0
    readonly property real travel: Math.max(1, width - beadSize)
    readonly property real beadCentre: beadSize / 2 + root.shown * travel

    // THE DETENT AT 100%.
    //
    // A magnet, not a stop. 100% is the value you land on far more often than
    // any other and the one you cannot hit reliably by hand, because it is a
    // point on a 250px rail and the pointer is a pixel; but going past it is
    // exactly what the extra range is for, so the notch has to let go when you
    // keep pulling. Inside a bead's reach of the mark the value takes the mark
    // exactly, and outside it the pointer is obeyed: it catches, and you can
    // pull through it.
    //
    // A bead's radius rather than a number of percent, because what makes a
    // detent feel right is how far your HAND has to move to escape it, and that
    // is pixels. The same rule on a shorter rail would otherwise swallow more of
    // the range.
    readonly property real detent: beadSize / 2

    function snap(v: real): real {
        if (root.warnAbove <= root.from || root.warnAbove >= root.to)
            return v;
        const perPixel = (root.to - root.from) / root.travel;
        return Math.abs(v - root.warnAbove) < root.detent * perPixel ? root.warnAbove : v;
    }

    // EXACT while you are dragging, smoothed when the value moves under you (a
    // media key, another app, the other end of a call). A slider that eases
    // toward your cursor feels broken; one that cuts when something else moves
    // it looks broken. `dragged` is what the pointer asked for, kept because the
    // value only comes back after PipeWire has agreed to it.
    property real dragged: 0
    readonly property real shown: pointer.pressed ? root.dragged : glide.value

    implicitHeight: Math.max(rail, beadSize * 1.35)
    implicitWidth: Appearance.sizes.menuWidth / 2

    // Ask for a value, from wherever the asking came from. Clamped, then pulled
    // to the detent, then SHOWN before it is sent: the bead has to be where the
    // hand put it now, and PipeWire cannot answer until next frame.
    function ask(v: real): void {
        const wanted = root.snap(Math.max(root.from, Math.min(root.to, v)));
        const f = (wanted - root.from) / Math.max(0.0001, root.to - root.from);
        root.dragged = f;
        glide.value = f;
        root.moved(wanted);
    }

    Follow {
        id: glide

        target: root.fraction
        speed: Appearance.anim.trackSpeed
        epsilon: 0.001
    }

    // The rail.
    G2Rect {
        anchors.verticalCenter: parent.verticalCenter

        width: parent.width
        height: root.rail
        radius: height / 2
        color: Appearance.colour.fill

        // How far it has come. It ends at the bead's centre rather than at the
        // value, so the bead always caps the fill instead of floating past its
        // end at one extreme and sinking into it at the other.
        G2Rect {
            width: root.beadCentre
            height: parent.height
            radius: height / 2
            color: root.lit
            opacity: 0.55
        }

        // WHERE 100% IS. Only drawn when the range actually goes past it, which
        // is the output and nothing else. Amplification already turns the fill
        // to the accent, but a colour that appears once you have crossed a line
        // cannot help you stop at it, and stopping at it is the whole reason to
        // look. Cut into the rail rather than laid on top, so it survives the
        // fill arriving.
        G2Rect {
            visible: root.warnAbove > root.from && root.warnAbove < root.to
            x: root.beadSize / 2 + ((root.warnAbove - root.from) / Math.max(0.0001, root.to - root.from)) * root.travel - width / 2
            width: Math.max(2, Math.round(root.rail / 3))
            height: parent.height
            radius: width / 2
            color: Appearance.colour.accentText
            opacity: 0.55
        }
    }

    // The bead. Scaled rather than resized, so it grows about its own centre and
    // the geometry the pointer is mapped against never moves under the drag.
    G2Rect {
        visible: root.enabled

        x: root.beadCentre - width / 2
        y: (root.height - height) / 2
        width: root.beadSize
        height: width
        radius: width / 2
        color: root.lit

        // Swells to meet the cursor, and gives when you push it.
        scale: pointer.pressed ? 1.15 : root.active ? 1.3 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutBack
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        // Grown to the accessible minimum rather than to a spacing token: a 6px
        // track with a 6px margin is an 18px target, and WCAG 2.2 SC 2.5.8 puts
        // the floor at 24. The rail stays thin; the thing you can hit does not.
        anchors.topMargin: -Math.max(0, (Appearance.sizes.minTarget - root.height) / 2)
        anchors.bottomMargin: anchors.topMargin
        anchors.leftMargin: -Appearance.padding.small
        anchors.rightMargin: anchors.leftMargin
        hoverEnabled: true
        // The grab is the slider's from the press, and nothing may take it
        // back. Menus scroll now, so this control lives inside a Flickable,
        // and a Flickable steals any grab whose pointer then drifts far enough
        // up or down: a bead dragged with the slightest slope was handed to
        // the list mid-adjustment, the volume froze, and the menu scrolled
        // instead. This is the exact inverse of the notification card's
        // arbitration, and the reason it can be a constant here when it could
        // not be there: a press on a card is ambiguous (a tap, a dismissal, or
        // a scroll that merely started on the card), so the card has to leave
        // the grab takeable until an axis wins. A slider press is never
        // ambiguous. The control is the target, not the surface it sits on, so
        // there is nothing to arbitrate and no one else the gesture could
        // belong to.
        preventStealing: true
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor

        // Mapped rather than offset by the margins above. Undoing those by hand
        // means writing the same number twice with opposite signs, and it was
        // already written once with the wrong one.
        function report(mx: real): void {
            const f = (pointer.mapToItem(root, mx, 0).x - root.beadSize / 2) / root.travel;
            const clamped = Math.max(0, Math.min(1, f));
            root.ask(root.from + clamped * (root.to - root.from));
        }

        onPressed: mouse => report(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse.x);
        }

        // A wheel over a volume control means volume, whatever else the wheel
        // does nearby. Notches rather than pixels: a touchpad sends fractions of
        // one and they add up to the same travel, so the same gesture moves the
        // same distance on either device.
        onWheel: wheel => {
            const notches = wheel.angleDelta.y / 120;
            root.ask(root.value + notches * root.step);
        }
    }
}
