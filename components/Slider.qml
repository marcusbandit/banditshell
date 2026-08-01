import QtQuick
import qs.config

// A value you drag.
//
// It does NOT own its value. `value` is bound to whatever it controls and only
// changes when that thing changes; dragging emits `moved`, and the caller sets
// the real thing, which comes back round. Owning the value locally would make
// the slider disagree with reality the moment anything else changed the volume,
// which is exactly when you are most likely to be looking at it.
Item {
    id: root

    property real value: 0
    property real from: 0
    property real to: 1
    // Where "normal" ends, as a fraction of the track. Past this the fill warns
    // rather than reassures: volume above 100% is amplification.
    property real warnAbove: 1

    // Still shows its value, but says the value is not in effect. Emptying the
    // track instead would throw away the one thing you want to know while muted:
    // what it will go back to.
    property bool dimmed: false

    signal moved(real value)

    readonly property real fraction: Math.max(0, Math.min(1, (value - from) / Math.max(0.0001, to - from)))
    readonly property bool active: pointer.pressed || pointer.containsMouse

    implicitHeight: Appearance.sizes.sliderHeight
    implicitWidth: Appearance.sizes.menuWidth / 2

    G2Rect {
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colour.fill
    }

    G2Rect {
        height: parent.height
        width: Math.max(height, parent.width * root.fraction)
        radius: height / 2
        color: root.dimmed ? Appearance.colour.textFaint : root.value > root.warnAbove ? Appearance.colour.accent : Appearance.colour.text
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        // Grown to the accessible minimum rather than to a spacing token: a 6px
        // track with a 6px margin is an 18px target, and WCAG 2.2 SC 2.5.8 puts
        // the floor at 24. The track stays thin; the thing you can hit does not.
        anchors.topMargin: -Math.max(0, (Appearance.sizes.minTarget - root.height) / 2)
        anchors.bottomMargin: anchors.topMargin
        anchors.leftMargin: -Appearance.padding.small
        anchors.rightMargin: -Appearance.padding.small
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function report(x: real): void {
            const f = Math.max(0, Math.min(1, (x + Appearance.padding.small) / root.width));
            root.moved(root.from + f * (root.to - root.from));
        }

        onPressed: mouse => report(mouse.x)
        onPositionChanged: mouse => {
            if (pressed)
                report(mouse.x);
        }
    }
}
