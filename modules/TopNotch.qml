import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

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
//
// It carries TWO things, and only one of them was asked for. The time is the
// focus: it is what going to the top of the screen means. Whatever is playing
// rides underneath it, quieter, because the same trip is when you would want to
// know (DESIGN.md 2.4, contextual prominence). The clock does not move to make
// room: the contents hang from the notch's bottom edge and the notch is as long
// as its contents, so a track appearing grows the notch DOWNWARD and leaves the
// time exactly where it was.
Item {
    id: root

    // True while the notch should be out.
    readonly property bool active: zone.containsMouse || notchZone.containsMouse
    readonly property Item maskItem: notchZone

    property int border: Appearance.sizes.border

    // What is in it, and therefore how big it is: the time always, the track
    // when there is one. `hasTrack` rather than `available`, because a player
    // that is merely open is not something to make the notch longer for.
    readonly property bool showsMedia: Media.hasTrack
    readonly property real contentWidth: Math.max(label.implicitWidth, showsMedia ? preview.implicitWidth : 0)
    readonly property real contentHeight: label.implicitHeight + (showsMedia ? Appearance.padding.large + preview.implicitHeight : 0)

    // The SHAPE follows the contents rather than being them, because the
    // contents change while the notch is open: a track ends, the next one has a
    // longer name, a player disappears. Taking those instantly would make the
    // shell twitch at something the cursor did not do. Snapped as it opens, so
    // arriving is never an animation of the notch finding its own size.
    readonly property real notchWidth: wide.value + Appearance.padding.huge * 2
    readonly property real notchHeight: root.border + tall.value + Appearance.padding.large * 2

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

    onActiveChanged: {
        if (!root.active)
            return;
        wide.snap();
        tall.snap();
        // Ask the player where it is. MPRIS does not push position and Media
        // only polls it while something is PLAYING, so a paused track that was
        // seeked in the player itself would open showing where it used to be.
        Media.active?.positionChanged();
    }

    Follow {
        id: drop
        speed: Appearance.anim.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: wide
        speed: Appearance.anim.resizeSpeed
        target: root.contentWidth
    }

    Follow {
        id: tall
        speed: Appearance.anim.resizeSpeed
        target: root.contentHeight
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

        // Everything the notch holds, hung from its bottom edge so it rides the
        // descending blob: the contents arrive WITH the shape rather than being
        // revealed inside a shape that is already there.
        Item {
            id: content

            anchors.horizontalCenter: parent.horizontalCenter
            width: wide.value
            height: root.contentHeight
            y: parent.height - height - Appearance.padding.large
            opacity: drop.value

            StyledText {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top

                text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                font.pixelSize: Appearance.font.size.large
            }

            MediaPreview {
                id: preview

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: implicitHeight
                visible: root.showsMedia
            }
        }
    }
}
