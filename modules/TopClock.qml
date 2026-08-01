import QtQuick
import Quickshell
import qs.config
import qs.components

// The notch: cursor to the top-centre edge and the time swells out of the band.
//
// It is NOT a pill that slides out from behind the edge. It is a blob in the
// shell's distance field, exactly like a menu, so it melts out of the top band
// and back into it. At rest its rectangle is precisely the band's own height, so
// it is entirely inside the body and invisible; growing past that is what makes
// it appear.
//
// That is the difference between something drawn over the shell and something
// the shell does.
Item {
    id: root

    // True while the notch should be out.
    readonly property bool active: zone.containsMouse || notchZone.containsMouse
    readonly property Item maskItem: notchZone

    property int border: Appearance.sizes.border

    readonly property real notchWidth: label.implicitWidth + Appearance.padding.huge * 2
    readonly property real notchHeight: root.border + label.implicitHeight + Appearance.padding.large * 2

    // What the chassis needs to melt this into the body.
    //
    // It DESCENDS from above the screen rather than growing in place. A blob
    // that merely shrinks to nothing still pulls the band toward it the whole
    // way, because a smooth minimum blends anything within `melt` of the
    // surface, so at rest the band would carry a permanent bulge where the notch
    // is parked. Starting a full melt-distance clear of the band means at rest
    // it has no influence at all, and the arrival is a real approach: it reaches
    // the band, merges with it, then swells out below.
    readonly property var blobs: [
        {
            x: (width - notchWidth) / 2,
            y: -(notchHeight + Appearance.sizes.melt) * (1 - drop.value),
            w: notchWidth,
            h: notchHeight,
            radius: Appearance.rounding.large
        }
    ]

    Follow {
        id: drop
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
        // Only tick while it is being looked at. A seconds clock bound to a
        // visible label wakes the render thread once a second whether or not
        // anything is on screen, and every one of those frames redraws the whole
        // chassis field and hands the compositor a new surface to blur.
        enabled: root.active
    }

    // Summon zone: a strip of the band at top-centre. It sits inside the body,
    // which is already in the input mask, so it needs no mask entry of its own.
    MouseArea {
        id: zone

        hoverEnabled: true
        height: root.border
        width: root.notchWidth
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    // The notch's own hit area, which follows the blob so the cursor can move
    // down into it without leaving.
    MouseArea {
        id: notchZone

        hoverEnabled: true
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.notchWidth
        // Follows the blob's lower edge, so the cursor can move down into the
        // notch without leaving it.
        height: Math.max(root.border, root.notchHeight - (root.notchHeight + Appearance.sizes.melt) * (1 - drop.value))

        StyledText {
            id: label

            anchors.horizontalCenter: parent.horizontalCenter
            // Rides the descending blob, so the time arrives WITH the shape
            // rather than being revealed inside a shape already there.
            y: parent.height - implicitHeight - Appearance.padding.large
            opacity: drop.value

            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            font.pixelSize: Appearance.font.size.large
        }
    }
}
