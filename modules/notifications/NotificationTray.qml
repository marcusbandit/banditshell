pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Notifications, in ONE tray hanging off the top-right corner.
//
// The tray is a single blob melted into the band, and the rows live INSIDE it.
// That is the third arrangement this has had, and the reasoning is worth
// keeping:
//
//   - Panels chained through the melt fused into each OTHER as well as into the
//     shell: three peers within melt distance became one lumpy mass with pinches
//     where the boundaries should have been.
//   - Melting each card into the band separately fixed that, and produced N
//     tongues off the edge, which is not one body either.
//   - A metaball chain cannot give both. Rows fuse into a column only when they
//     are closer together than half the melt, and that is exactly the spacing at
//     which they stop being legible.
//
// So the connection is made by a CONTAINER rather than by the field. One tray,
// one join to the shell, and the rows inside separated the ordinary way.
//
// It has two states and they are the same object, not two panels that hand over.
// Collapsed it shows what just arrived; put the cursor in the corner and it
// EXPANDS to everything unread, growing in place. Anything that merely timed out
// is still in there. Anything thrown away is not: see Notifs.beginLeave.
Item {
    id: root

    // How far in from the content area's top edge the tray sits.
    required property real inset

    // The band's thickness. The tray reaches past it, to the screen edge.
    required property real edgeInset

    readonly property real panelWidth: Appearance.sizes.notificationWidth

    // Summoned by the corner, and held open while the cursor is anywhere in the
    // tray.
    //
    // Leaving starts a GRACE timer rather than closing, the same as the menus.
    // Hover is a sloppy input and there is real dead space to cross: the corner
    // arms are in the band and the tray starts a gap below it, so an immediate
    // close makes the tray unreachable from the thing that opens it.
    property bool expanded: false

    readonly property bool hovering: cornerTop.containsMouse || cornerSide.containsMouse || trayHover.hovered

    onHoveringChanged: {
        if (root.hovering) {
            grace.stop();
            root.expanded = true;
        } else if (root.expanded) {
            grace.restart();
        }
    }

    Timer {
        id: grace

        interval: Appearance.anim.grace
        onTriggered: root.expanded = false
    }

    readonly property var items: root.expanded ? Notifs.history : Notifs.popups

    // Visible when there is something to show, and whenever it is summoned: an
    // empty tray that says so is the answer to "did I miss anything", and a
    // corner that does nothing is indistinguishable from a corner that is broken.
    readonly property bool any: root.items.length > 0 || root.expanded

    // Nothing expires while the list is being read.
    onExpandedChanged: Notifs.paused = root.expanded

    // What the window's input mask should cover: the TRAY, not this item.
    //
    // This item fills the screen, because the tray is positioned inside it.
    // Handing it to the mask as-is made the whole screen interactive the moment
    // any notification existed, so the shell swallowed every click anywhere. A
    // critical notification never times out, so it stayed that way.
    readonly property Item maskItem: tray

    // The tray's rectangle, for the chassis to melt in.
    //
    // PUSHED, not bound. A binding here has to read the tray's geometry, and
    // reading a lazy binding re-evaluates it, which emits the very change signal
    // that invalidates this list WHILE it is being computed: a binding loop on
    // every frame of every arrival. Qt.callLater coalesces the pushes, so a tray
    // that moves and resizes in the same frame rebuilds this once.
    property var blobs: []

    function sync(): void {
        if (!root.any || tray.height <= 0) {
            root.blobs = [];
            return;
        }
        root.blobs = [
            {
                x: tray.x,
                y: tray.y,
                w: tray.width,
                h: tray.height,
                radius: Appearance.rounding.large
            }
        ];
    }

    onAnyChanged: Qt.callLater(root.sync)
    onWidthChanged: Qt.callLater(root.sync)

    // Summon zone: an L along the two edges that meet at the corner.
    //
    // Both arms lie INSIDE the band, which is already in the input mask, so
    // neither needs a mask entry of its own. A corner is the cheapest target on
    // a screen: the pointer cannot overshoot it, so the arms can be exactly as
    // thin as the band and still be trivial to hit.
    readonly property real armLength: Appearance.sizes.cornerZone

    MouseArea {
        id: cornerTop

        hoverEnabled: true
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.armLength
        height: root.edgeInset
    }

    MouseArea {
        id: cornerSide

        hoverEnabled: true
        anchors.top: parent.top
        anchors.right: parent.right
        width: root.edgeInset
        height: root.armLength
    }

    Item {
        id: tray

        // Flush with the SCREEN edge, not with the band's inner edge. The tray
        // and the band are one body; held off the edge it would join the shell
        // through a neck instead of simply being part of it.
        x: root.width - root.panelWidth
        y: root.inset
        width: root.panelWidth
        height: Math.min(list.height, root.height - root.inset * 2) + Appearance.padding.normal * 2
        visible: root.any

        onYChanged: Qt.callLater(root.sync)
        onHeightChanged: Qt.callLater(root.sync)

        // A HANDLER, not a MouseArea. A hoverEnabled MouseArea is the topmost
        // thing that gets hover and everything under it gets none, so the moment
        // the cursor reached a row the tray stopped being hovered, decided the
        // cursor had left, and closed itself: the list vanished the instant you
        // tried to touch it. A HoverHandler is passive and stays hovered while
        // its own descendants are.
        HoverHandler {
            id: trayHover
        }

        // Scrolls only when it has to. A tray shorter than the screen is a
        // panel; one that always scrolls is a document.
        Flickable {
            id: view

            x: Appearance.padding.normal
            y: Appearance.padding.normal
            width: tray.width - Appearance.padding.normal * 2
            height: tray.height - Appearance.padding.normal * 2

            contentHeight: list.height
            interactive: contentHeight > height
            clip: interactive
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: view.width
                spacing: Appearance.padding.normal

                // The header only exists while the tray is a list rather than a
                // couple of arrivals, and it collapses the same way a row does
                // so the tray never jumps when it appears.
                Item {
                    id: headerSlot

                    readonly property real open: reveal.value

                    width: parent.width
                    height: header.implicitHeight * open
                    clip: true
                    visible: open > 0

                    Follow {
                        id: reveal

                        speed: Appearance.anim.revealSpeed
                        epsilon: 0.005
                        target: root.expanded ? 1 : 0
                    }

                    Row {
                        id: header

                        width: parent.width
                        spacing: Appearance.padding.normal

                        StyledText {
                            id: title

                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - clearAll.width - parent.spacing
                            text: Notifs.count > 0 ? `${Notifs.count} unread` : "Nothing unread"
                            font.pixelSize: Appearance.font.size.small
                            color: Appearance.colour.textFaint
                            elide: Text.ElideRight
                        }

                        G2Rect {
                            id: clearAll

                            width: Notifs.count > 0 ? clearLabel.implicitWidth + Appearance.padding.normal * 2 : 0
                            height: Appearance.sizes.minTarget
                            radius: height / 2
                            color: clearPress.containsMouse ? Appearance.colour.fillStrong : Appearance.colour.fill
                            visible: Notifs.count > 0

                            StyledText {
                                id: clearLabel

                                anchors.centerIn: parent
                                text: "Clear"
                                font.pixelSize: Appearance.font.size.small
                            }

                            MouseArea {
                                id: clearPress

                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Notifs.clear()
                            }
                        }
                    }
                }

                Repeater {
                    // A ScriptModel, NOT the array itself. A Repeater over a
                    // plain JS array has no idea what changed, so every
                    // assignment tears down every delegate and builds it again:
                    // dismissing one notification re-created all of them, which
                    // restarted their animations and dropped their state. This
                    // diffs the array into inserts and removes, so the rows that
                    // did not change are never touched.
                    model: ScriptModel {
                        values: root.items
                    }

                    delegate: NotificationCard {
                        required property var modelData

                        entry: modelData
                        fullWidth: list.width
                        onDismissed: Notifs.dismiss(modelData)
                    }
                }
            }
        }
    }
}
