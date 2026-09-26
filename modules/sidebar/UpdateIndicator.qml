import QtQuick
import qs.config
import qs.components
import qs.services

// THE UPDATE MARKER: the one thing in the bottom group that is allowed to
// interrupt, because it is the only gauge that speaks for a push the user has
// not seen yet.
//
// ABOVE THE CLOCK, and that placement is the message. Everything else down
// here answers a glance you chose to make; this says something happened
// without being asked, and the shell's one way of saying that loudly without
// a popup is to stand in the place the eye already visits (the clock is the
// thing this bar is mostly looked at for) wearing a colour nothing else wears.
//
// THREE DRESSINGS, ONE PLACE. Idle it is a quiet grey mark, a size down, so a
// state of "nothing confirmed" still has a home to be asked from without
// competing with the clock above it (DESIGN.md 2.1: it is furniture-sized
// presence, not information). A push waiting turns it RED and full size; a
// download landed turns it BLUE. Neither of those is on the ramp, for the
// terminal palette's reason - the colour IS the meaning.
Item {
    id: root

    // A tap on the marker asks for its menu - which, when nothing is
    // confirmed, is where "search for update" lives. No hover route and no
    // pull: like the clock's own two halves, this is a consultative thing,
    // and a menu arriving because a cursor crossed it would be the shell
    // interrupting rather than answering. Always deliberate, therefore.
    signal requested(bool deliberate)

    readonly property string state: Update.state

    // What the glyph says, per state. The two waiting states share the
    // download question and take the download's marks; idle holds the sync
    // mark, which is the menu's "search" verb drawn as a glyph.
    readonly property string glyph: {
        if (root.state === Update.idle)
            return "sync";
        if (root.state === Update.downloaded)
            return "download_done";
        if (root.state === Update.downloading)
            return "cloud_download";
        // system_update_ALT: the plain name is not in the installed face, and
        // a name the font does not have renders as its own question mark
        // (Icon's whole reason for checking).
        return "system_update_alt";
    }

    // A SIZE DOWN WHEN QUIET, the idle state's whole volume argument: the
    // marker must remain findable (it is the only way in to "search") without
    // ever reading as news. Icons are not on the text pixel grid, so a
    // fraction of the shell's icon size is a size and not a crime.
    readonly property real markSize: root.state === Update.idle ? Math.round(Appearance.font.iconSize * 0.8) : Appearance.font.iconSize

    // The colour IS the state: quiet grey until something is confirmed, red
    // while it waits, blue once it is down. The grey lifts on hover, because
    // a marker that stays grey under the hand reads as dead rather than
    // quiet.
    readonly property color tint: {
        if (root.state === Update.idle)
            return press.containsMouse ? Appearance.colour.text : Appearance.colour.textDim;
        if (root.state === Update.downloaded)
            return Appearance.colour.updateReady;
        return Appearance.colour.updateAvailable;
    }

    width: parent ? parent.width : 0
    height: Math.max(Appearance.sizes.minTarget, mark.implicitHeight)

    // THE DRAWN GLYPH, centred in the band the way every other mark in this bar
    // is, and answering the press by moving (the time's own rule: this has no
    // brighter tier above it to lift to, so a press is a shrink).
    Icon {
        id: mark

        anchors.centerIn: parent
        name: root.glyph
        fill: 1
        size: root.markSize
        color: root.tint

        scale: press.pressed ? 0.92 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.normal
            }
        }
    }

    // THE HIT AREA IS THE BAND, StatusIcon's lesson: full width, and it is
    // permanent now, because the quiet marker is a way in and not merely a
    // report.
    MouseArea {
        id: press

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.requested(true)
    }

    // NO TOOLTIP HERE, the gauges' rule: hovering this opens a menu whose
    // first line is the state in words, so a floating label would only say
    // the same thing twice.
}
