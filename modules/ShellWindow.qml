pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.menu
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.sidebar
import qs.services

// The shell. One surface per screen, and everything the shell draws lives in it.
//
// This is deliberately NOT one window per panel. The chassis (the band around
// the screen plus the sidebar) is a single shape, so two translucent panels can
// never overlap and double their opacity, and the whole contour rounds as one
// object. Menus and summoned widgets join the same surface, which is also what
// keeps the input mask contiguous: the cursor can travel from an edge zone into
// the thing it summoned without crossing dead pixels and dismissing it.
//
// It is on the TOP layer, not Overlay. The chassis is part of the shell, not a
// decoration floating over the desktop, and it should give way to a fullscreen
// window the way a bar does.
//
// It reserves nothing itself: FrameExclusions does that, because an exclusive
// zone belongs to a surface anchored to one edge and this is anchored to four.
PanelWindow {
    id: win

    // What the IPC handler drives. Registering here rather than being handed a
    // reference keeps shell.qml from having to wire anything up.
    readonly property Menus menus: menuLayer
    readonly property Launcher launcher: launcherLayer
    readonly property var statusItems: sidebar.status.items
    readonly property var statusKeys: statusItems.map(i => i.key)
    readonly property bool cursorOnShell: onShell.hovered

    Component.onCompleted: Shell.register(win)
    Component.onDestruction: Shell.unregister(win)

    // Open a menu by key, positioned beside its icon. The single entry point:
    // hovering an icon and calling this over IPC take the same path, so the
    // scriptable route cannot drift from the one people actually use.
    function openMenu(key: string): bool {
        const entry = sidebar.status.entryFor(key);
        const source = sidebar.status.iconFor(key);
        if (!entry || !source)
            return false;

        const centre = source.mapToItem(win.contentItem, source.width / 2, source.height / 2);
        menuLayer.show(key, entry.title, entry.body, centre.y);
        return true;
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "transparent"
    exclusiveZone: 0
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    // The keyboard, but ONLY while the launcher is up.
    //
    // A layer surface receives no key events unless its window asks, which is
    // why the search field could be focused, draw a cursor, and still get
    // nothing typed into it. Exclusive rather than on-demand so Escape works
    // from anywhere, and dropped the instant it closes: an unconditional grab on
    // a surface that merely exists takes the keyboard from the desktop.
    WlrLayershell.keyboardFocus: launcherLayer.open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // The compositor blurs this surface by name. Without that the chassis is a
    // flat translucent wash; with it, it is a material. See the banditshell
    // layerrule in ~/.config/hypr/hyprland/rules.conf.
    WlrLayershell.namespace: "banditshell"

    readonly property int border: Appearance.sizes.border

    // Mask gates INPUT, opacity gates VISUALS: keep them apart.
    //
    // The interactive region is exactly the chassis: everything except the
    // content area, plus whatever is currently open. That is contiguous, which
    // matters because a gap in it would drop the cursor mid-gesture and dismiss
    // what it was reaching for.
    mask: Region {
        width: win.width
        height: win.height

        Region {
            intersection: Intersection.Subtract
            x: chassis.holeX
            y: chassis.holeY
            width: chassis.holeWidth
            height: chassis.holeHeight
        }

        Region {
            intersection: Intersection.Combine
            item: menuLayer.open ? menuLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: launcherLayer.open ? launcherLayer.maskItem : null
        }

        // ALWAYS, not only while swollen. At rest the zone is exactly the band,
        // which the chassis already covers, so this costs nothing; while swollen
        // it reaches a few pixels past the band, and without it those would be
        // the only part of the swell the cursor could not reach.
        Region {
            intersection: Intersection.Combine
            item: launchEdge.maskItem
        }

        Region {
            intersection: Intersection.Combine
            item: topNotch.active ? topNotch.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: popups.any ? popups.maskItem : null
        }
    }

    // EVERYTHING the shell draws, in one item, so that one watcher can answer
    // "is the cursor on the shell at all?".
    //
    // Qt delivers a hover event to the topmost item that accepts it AND to that
    // item's ancestors, and to nobody else. Both obvious placements therefore
    // fail, and both were measured failing: a watcher ON TOP of everything takes
    // hover away from every control beneath it, so the gauges stop opening menus
    // (`blocking: false` does not save it); a watcher UNDER everything goes
    // blind the moment the cursor finds a control, so crossing the workspaces
    // reads as leaving the shell. A watcher that is their PARENT hears both: the
    // bare chassis, because nothing else accepted it, and every control, because
    // ancestors are told what their children took.
    Item {
        id: body

        anchors.fill: parent

        HoverHandler {
            id: onShell
        }

        Chassis {
            id: chassis

            anchors.fill: parent
            // Open panels join the shell's distance field rather than being drawn
            // on top of it, which is what lets them melt into the body.
            // Everything that joins the shell's body. Each melts into the CHASSIS
            // and none of them melt into each other; see blob.frag's meltPanel.
            panels: [...menuLayer.blobs, ...launcherLayer.blobs, ...topNotch.blobs, ...popups.blobs, ...launchEdge.blobs]
        }

        // Sidebar contents, laid out in the chassis's left band. The band is one
        // material, so the content centres in the whole of it rather than in some
        // inner rectangle.
        Sidebar {
            id: sidebar

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: win.border
            anchors.bottomMargin: win.border
            width: chassis.barWidth

            status.onRequested: key => win.openMenu(key)
            status.onReleased: menuLayer.release()
        }

        NotificationTray {
            id: popups

            anchors.fill: parent
            inset: win.border + Appearance.sizes.gap
            // Flush with the band's inner edge, so each card melts into the shell.
            edgeInset: win.border
        }

        Menus {
            id: menuLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            // The whole surface, not this panel: see `body` above.
            shellHovered: onShell.hovered
        }

        Launcher {
            id: launcherLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border
        }

        // The bottom edge, as a way in: it swells under the cursor, opens on a
        // click, and opens on a push up from it.
        LaunchEdge {
            id: launchEdge

            anchors.fill: parent
            border: win.border
            span: launcherLayer.panelWidth
            // Pointless while the thing it opens is already open, and worse than
            // pointless: the launcher's own panel comes out of the same edge.
            armed: !launcherLayer.open

            onDragged: fraction => launcherLayer.dragTo(fraction)
            onFinished: open => launcherLayer.dragEnd(open)
        }

        TopNotch {
            id: topNotch

            anchors.fill: parent
            border: win.border
        }
    }
}
