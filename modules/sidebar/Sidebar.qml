import QtQuick
import qs.config

// What the sidebar contains.
//
// No background of its own: the sidebar IS part of the chassis shape, drawn once
// by Chassis.qml. This is only the layout of what sits in that band.
//
// THREE QUESTIONS, in the three places a vertical band has. What is running
// (the tray, at the top), where you are (the workspaces, in the middle, because
// they are the thing the sidebar is mostly for), and how the machine is doing
// (the clock and the gauges, at the bottom).
//
// The groups get a quiet container so related controls read as one thing; the
// clock gets none, because it is the thing you actually look at.
Item {
    id: root

    // Forwarded up to the menu layer, which lives outside the sidebar because
    // the menus are not part of it. Both of these open menus, by the same keys
    // and through the same call, which is what `entryFor` below is for.
    property alias status: status
    property alias tray: tray

    signal requested(string key)
    signal released

    // Every key that opens a menu, in the order they are down the bar. The CLI
    // lists these and opens by name, so a tray item is drivable from a terminal
    // exactly as a gauge is.
    readonly property var menuItems: [...tray.items, ...status.items]
    readonly property var menuKeys: root.menuItems.map(i => i.key)

    // WHICH GROUP OWNS A KEY, answered here so nothing above the sidebar has to
    // know there is more than one. Asked in the same order the bar is read in.
    function entryFor(key: string): var {
        return tray.entryFor(key) ?? status.entryFor(key);
    }

    function iconFor(key: string): Item {
        return tray.iconFor(key) ?? status.iconFor(key);
    }

    // FULL WIDTH, like the workspaces below and for a related reason: a group in
    // here draws a 28px column but is aimed at across the whole 62px band, and a
    // target can only be as wide as the thing that was given the width. Centred,
    // each group answered over less than half the bar and left seventeen dead
    // pixels either side of every icon, on a surface that is nothing but icons.
    // The groups centre their own drawing (see TrayIcons), so nothing moves.
    TrayIcons {
        id: tray

        anchors.top: parent.top
        anchors.topMargin: Appearance.padding.normal
        anchors.left: parent.left
        anchors.right: parent.right

        onRequested: key => root.requested(key)
        onReleased: root.released()
    }

    // Full width, unlike everything else in here: the workspace ruler is drawn
    // ON the screen's edge and reaches in from it, so it needs the whole band to
    // measure from rather than a centred column.
    Workspaces {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
    }

    // FULL WIDTH for the same reason the tray is, and the width is passed
    // straight through to the gauges rather than stopping here: a Column is as
    // wide as its widest child unless told otherwise, so a centred one would
    // have been the clock's width, which is neither the band nor a slot and
    // whichever it happened to be would decide how far a gauge answered.
    Column {
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Appearance.padding.normal
        anchors.left: parent.left
        anchors.right: parent.right

        spacing: Appearance.padding.large

        // Still centred, and now centred in the band rather than in a column the
        // clock itself was setting the width of. Same line either way: the
        // column used to be centred in the band too.
        Clock {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        StatusIcons {
            id: status

            anchors.left: parent.left
            anchors.right: parent.right

            onRequested: key => root.requested(key)
            onReleased: root.released()
        }
    }
}
