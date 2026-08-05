pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.menu
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.session
import qs.modules.settings
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
    readonly property SessionMenu session: sessionLayer
    readonly property SettingsPanel settings: settingsLayer
    // The tray and the notch register whole, but what the IPC handler actually
    // writes on them is the PIN and nothing else: presence on both is a derived
    // union (see NotificationTray.expanded), so a keybind pinning the tray and
    // a hand pinning it must land in the same state and leave by the same
    // doors. A separate CLI-owned flag was rejected for exactly that reason; a
    // second writer would fight the gesture.
    readonly property NotificationTray notifications: popups
    readonly property TopNotch notch: topNotch
    // EVERYTHING IN THE BAR THAT OPENS A MENU, gauges and tray items alike. The
    // sidebar answers this rather than one group of it: which group a key
    // belongs to is the sidebar's business, and the CLI wants the whole list.
    readonly property var statusItems: sidebar.menuItems
    readonly property var statusKeys: sidebar.menuKeys
    readonly property bool cursorOnShell: onShell.hovered

    Component.onCompleted: Shell.register(win)
    Component.onDestruction: Shell.unregister(win)

    // Open a menu by key, positioned beside its icon. The single entry point:
    // hovering an icon and calling this over IPC take the same path, so the
    // scriptable route cannot drift from the one people actually use.
    //
    // `pin` says the menu was ASKED FOR rather than wandered into, and it
    // DEFAULTS TO TRUE because the only caller that omits it is modules/Ipc.qml.
    // Somebody driving the shell from a terminal has no pointer resting on
    // anything, so an unpinned menu opened from there would have nothing holding
    // it and the grace timer would take it away a fifth of a second later: the
    // touchscreen's bug, wearing a different hat, and far more baffling from a
    // command line that just printed "open audio". The sidebar always says which
    // kind of open it is making, so the default is only ever the CLI's.
    function openMenu(key: string, pin = true): bool {
        const entry = sidebar.entryFor(key);
        const source = sidebar.iconFor(key);
        if (!entry || !source)
            return false;

        const centre = source.mapToItem(win.contentItem, source.width / 2, source.height / 2);
        menuLayer.show(key, entry.title, entry.body, centre.y, pin);
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

    // The keyboard, but ONLY while something here is being typed into.
    //
    // A layer surface receives no key events unless its window asks, which is
    // why the search field could be focused, draw a cursor, and still get
    // nothing typed into it. Exclusive rather than on-demand so Escape works
    // from anywhere, and dropped the instant it closes: an unconditional grab on
    // a surface that merely exists takes the keyboard from the desktop.
    //
    // A menu asks only while it holds a live prompt, never merely for being
    // open. Menus follow the cursor down the sidebar and stay up while it is
    // anywhere on the shell, so grabbing for an open one would take typing away
    // from the window the cursor is passing over.
    // THE SETTINGS PAGE ASKS ON DEMAND, not exclusively, which is the one thing
    // here that does.
    //
    // Everything above takes the keyboard outright because it is a thing you are
    // in the middle of doing and Escape has to work from anywhere. The settings
    // page is a thing you leave open while you go and look at what you changed,
    // and a layer surface holding the keyboard for it would mean you could not
    // type into whatever you opened it to change. On demand means it gets the
    // keyboard when you click it and gives it back when you click away, which is
    // exactly how the window it can be pulled out into behaves.
    //
    // Exclusive still wins when both apply: the launcher's search field takes
    // every printable key, and losing those to a page nobody is typing into
    // would be the worse failure.
    WlrLayershell.keyboardFocus: launcherLayer.open || sessionLayer.open || menuLayer.needsKeyboard ? WlrKeyboardFocus.Exclusive : settingsLayer.docked ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

        // Everything off a PINNED menu, so a tap anywhere else puts it away.
        //
        // Gated on `pinned` and deliberately not on `open`. A hover-opened menu
        // must go on letting clicks through to the desktop exactly as it does
        // now: the way a pointer closes one is by leaving, so nothing about it
        // needs dismissing, and swallowing the screen underneath would cost that
        // user a click every time they reached past a menu they never asked for.
        // A pinned one has no pointer to leave, and this is its way out. The
        // power panel's entry above is the same argument from the same side: the
        // panel that is summoned rather than reached for is the one with nothing
        // else to dismiss it.
        Region {
            intersection: Intersection.Combine
            item: menuLayer.pinned ? menuLayer.catcher : null
        }

        Region {
            intersection: Intersection.Combine
            item: launcherLayer.open ? launcherLayer.maskItem : null
        }

        // The whole screen while the power panel is out, so a click anywhere
        // off it puts it away. It is summoned by keybind rather than reached
        // for, so there is no edge to leave and nothing else to dismiss it.
        Region {
            intersection: Intersection.Combine
            item: sessionLayer.open ? sessionLayer.maskItem : null
        }

        // The card, and only while the shell is the one drawing it: the moment a
        // window takes the page over, a shell surface still claiming that
        // rectangle would be swallowing every click meant for the window
        // standing in exactly the same place.
        Region {
            intersection: Intersection.Combine
            item: settingsLayer.docked ? settingsLayer.maskItem : null
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

        // The notch's summon strip, ALWAYS, unlike the notch above it. Nothing
        // can make the notch active without first reaching this strip, so a
        // conditional entry would only ever open after the thing it was meant to
        // let you open. Same sentence as the launch edge and the settings
        // corner, and while `touchEdges` is off the strip is exactly the band
        // and this costs nothing at all.
        Region {
            intersection: Intersection.Combine
            item: topNotch.grabItem
        }

        Region {
            intersection: Intersection.Combine
            item: popups.any ? popups.maskItem : null
        }

        // The tray's corner square, ALWAYS, unlike the tray itself above. The
        // same argument the launch edge and the settings corner both make: at
        // rest the square is the only thing there is, and a target that only
        // exists once it has been hit is not a target. The entry above has to
        // be conditional because an empty tray has no rectangle to offer; this
        // one must not be, because an empty tray is exactly when the corner is
        // the only way to ask whether anything was missed.
        Region {
            intersection: Intersection.Combine
            item: popups.grabItem
        }

        // Only while it is out. Unlike the launch edge, the rail itself never
        // leaves the band, so at rest there is nothing here the chassis does not
        // already cover.
        Region {
            intersection: Intersection.Combine
            item: volumeRail.active ? volumeRail.maskItem : null
        }

        // The rail itself, ALWAYS, for the same reason: the entry above is
        // granted on `active`, and the rail cannot become active until it has
        // been pressed, so without this the widened target is a target only a
        // pointer that had already found the ten pixel band could reach.
        //
        // THIS IS STILL THE EXPENSIVE ONE, but far less than it was: the rail
        // became a centred third of the right edge rather than nearly the whole
        // of it, and the mask takes this item's own geometry, so the always-on
        // claim shrank with it without this file changing a line. While
        // `touchEdges` is on it takes fourteen pixels over that third from
        // whatever window is underneath, which is where scrollbars live; the
        // other two thirds went back to the windows when the rail became a
        // segment. That trade is the whole reason `touchEdges` exists rather
        // than the widening simply being done; see Config. Off, this collapses
        // to the band the chassis already owns.
        Region {
            intersection: Intersection.Combine
            item: volumeRail.grabItem
        }

        // ALWAYS, for the launch edge's reason: at rest the corner's grab square
        // is the only thing there is, and a target that only exists once it has
        // been hit is not a target.
        Region {
            intersection: Intersection.Combine
            item: settingsCorner.maskItem
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
            panels: [...menuLayer.blobs, ...launcherLayer.blobs, ...topNotch.blobs, ...popups.blobs, ...launchEdge.blobs, ...volumeRail.blobs, ...sessionLayer.blobs, ...tip.blobs, ...micIndicator.blobs, ...settingsCorner.blobs]
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

            // What the clock's summoning pull measures against: the surface's
            // diagonal, the same scale the notification tray's summon uses. A
            // summon measures against the SURFACE because the menu it summons
            // does not exist yet (Pull's travel note), and this is the first
            // place on the way down that can see one; the sidebar and the
            // clock just pass it along.
            pullSpan: Math.hypot(win.width, win.height)
        }

        // THE TWO GROUPS SEPARATELY, where this used to listen to the sidebar's
        // one merged signal.
        //
        // The gauges' request now carries a second thing, which is whether the
        // menu was asked for outright or merely wandered into, and the sidebar's
        // signal predates it: forwarded through there, every tap arrives looking
        // exactly like a hover, and that difference is the whole of what makes a
        // menu survive a finger. The sidebar's own `requested` still exists and
        // now goes unheard; the groups it forwards are already exactly what this
        // needs, so nothing is being worked around.
        //
        // Listening to the groups also keeps ONE call per request. Answering the
        // merged signal as well would mean two handlers on one emission, in an
        // order Qt does not promise, one of them able to reopen the menu the
        // other had just decided to close.
        Connections {
            target: sidebar.status

            // A SECOND TAP ON THE SAME GAUGE PUTS IT AWAY, mirroring the
            // notification corner, where a tap toggles its own pin. A control
            // that only opens is half a control, and the gauge is the one part
            // of a pinned menu's world that a finger already knows how to aim
            // at.
            //
            // Only a DELIBERATE request can close: under a finger, Qt's
            // synthesised hover arrives on the press and the tap on the release,
            // so if the hover counted, the first half of every tap would close
            // the menu the second half was about to open.
            function onRequested(key: string, deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === key) {
                    menuLayer.hide();
                    return;
                }
                win.openMenu(key, deliberate);
            }

            // THE GAUGE THAT IS A DOOR (StatusIcons' phrase): the settings
            // gauge has no menu, so its tap arrives on its own signal and
            // goes to the service rather than to the menu layer. On THIS
            // screen, the settings corner's argument exactly: the gauge you
            // pressed is on a particular monitor and the page belongs where
            // you are looking. Opened TO the icons page, because that is
            // what lived behind this gauge when it was a menu, and a door
            // that opened onto whichever page was last visited would be a
            // different door every day. Toggle, so a second tap while the
            // page is up puts it away: the same second-tap contract every
            // pinned menu above keeps, aimed at a panel instead.
            function onSettingsRequested(): void {
                Settings.toggle(win.screen.name, "icons");
            }

            function onReleased(): void {
                menuLayer.release();
            }
        }

        // The tray, whose request cannot say which kind it is: TrayIcons turns
        // a hover, a right button and a long press into the same one-word
        // signal, and it forwards from a delegate rather than owning the state,
        // so there is nowhere in it to hang the flag without changing what it
        // forwards. So every tray request is INCIDENTAL here, which is exactly
        // right for the pointer and leaves the finger to Menus: a menu no
        // pointer was ever on latches itself when the grace timer notices, and
        // nothing is guessed anywhere about which device is in use.
        Connections {
            target: sidebar.tray

            // The same contract as the gauges above, and for the same reasons.
            // A tray item's menu is reached by hover, by the right button and by
            // a long press, and only the first of those is somebody merely
            // passing through; the other two are the whole of what a tray item
            // does for a hand that has one button and no hover.
            function onRequested(key: string, deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === key) {
                    menuLayer.hide();
                    return;
                }
                win.openMenu(key, deliberate);
            }

            function onReleased(): void {
                menuLayer.release();
            }
        }

        // The clock's date, the third opener of menus and the one that is not a
        // group: the calendar is one control's menu, so the sidebar forwards
        // it under its own name rather than through either group's signal.
        // There is no hover route to it at all (Clock.qml says why), so no
        // release is forwarded and the grace timer never gets a vote: every
        // open below is a pinned one.
        Connections {
            target: sidebar

            // The gauges' contract, verbatim, aimed at one fixed key: a
            // deliberate tap on the date while its own menu is pinned puts it
            // away, and any other tap opens it. Repeating the two-line toggle
            // rather than sharing it with the blocks above is deliberate;
            // each handler states its whole meaning where it fires, and the
            // three would only be shareable through a helper that took the
            // key, which is more plumbing than the two lines are worth.
            function onCalendarRequested(deliberate: bool): void {
                if (deliberate && menuLayer.pinned && menuLayer.currentKey === "calendar") {
                    menuLayer.hide();
                    return;
                }
                win.openMenu("calendar", deliberate);
            }

            // The pull opens ON RECOGNITION, not on release (Clock's summon
            // note): the menu has no honest partial reveal to track, so the
            // panel is out and pinned the moment the gesture reads as a pull,
            // and reversing before the release is decided about a calendar
            // you can already see.
            function onCalendarPulled(): void {
                win.openMenu("calendar", true);
            }

            // The release only ever takes back: open=true means the pull
            // stood, and the menu it opened is already up, so there is
            // nothing to do that would not be doing it twice. False means
            // the reversal was meant, and the menu goes back where it came
            // from.
            function onCalendarPullEnded(open: bool): void {
                if (!open)
                    menuLayer.hide();
            }
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

            // See the session panel below: two overlays that both take the
            // keyboard cannot both be up.
            onOpenChanged: if (open)
                sessionLayer.hide()
        }

        // Power, on the right edge, summoned by keybind rather than reached for.
        SessionMenu {
            id: sessionLayer

            anchors.fill: parent
            border: win.border

            // Whichever asked for the keyboard second would be typing into the
            // other one: the launcher's search field takes every printable key,
            // including the ones this panel navigates with.
            onOpenChanged: if (open)
                launcherLayer.hide()
        }

        // The settings page, in the middle of the content area. The one panel
        // here that can stop being drawn without being closed: pull it out and a
        // real window holds it instead. See modules/settings/.
        SettingsPanel {
            id: settingsLayer

            anchors.fill: parent
            screen: win.screen

            // The chassis's hole, not the screen. The sidebar makes those two
            // different, and a page centred on the second sits visibly right of
            // the space it is actually in.
            holeX: chassis.holeX
            holeY: chassis.holeY
            holeWidth: chassis.holeWidth
            holeHeight: chassis.holeHeight

            // NOT mutually exclusive with the launcher and the power panel,
            // unlike those two with each other. They exclude one another because
            // they both take the keyboard outright; this one does not take it at
            // all unless you click it, so there is nothing to fight over, and
            // closing somebody's settings page because they reached for the
            // launcher would be a surprise with no reason behind it.
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

        // Dictation, when the microphone is actually open. It shares the top
        // edge with the notch and centres on the same axis, which is deliberate:
        // both are "the top of the screen telling you something", and the field
        // melts them together on the rare occasion the cursor is up here while
        // dictating, rather than showing two pills fighting for the same space.
        //
        // No mask entry, like the tooltip: it is a readout, not a control, and
        // nothing about it is meant to be clicked.
        MicIndicator {
            id: micIndicator

            anchors.fill: parent
            border: win.border
        }

        // The right edge, as a volume rail: scroll it, and the level comes out
        // of the band to say where it landed.
        VolumeRail {
            id: volumeRail

            anchors.fill: parent
            border: win.border
        }

        // The bottom-right corner, as a way in: rest the cursor there and the
        // corner becomes a settings mark, a click anywhere in the corner is the
        // press, and a push away from it along its own diagonal pulls the page
        // out with the gesture. See modules/SettingsCorner.qml for why there is
        // no button in it.
        SettingsCorner {
            id: settingsCorner

            anchors.fill: parent
            border: win.border

            // On THIS screen, not on whichever one holds the focused window: the
            // corner you pressed is on a particular monitor and the page belongs
            // where you are looking.
            onActivated: Settings.toggle(win.screen.name)

            // THE PULL GOES TO THE PANEL, not to the service, and that is the
            // whole difference between the two ways in.
            //
            // `Settings.open` is a switch: it can say that the page exists and
            // on which screen, and it has nowhere to put "seven tenths of the
            // way out of the corner". A drag needs a position on every frame, so
            // it is handed to the thing that draws the page, and the service is
            // only told once the gesture has committed. See SettingsPanel's
            // dragTo/dragEnd, which is the same contract the launch edge has
            // with the launcher.
            onDragged: fraction => settingsLayer.dragTo(fraction)
            onFinished: open => settingsLayer.dragEnd(open)
        }

        // LAST, so its label draws over the panels it explains. It has no input
        // of its own, so being on top costs nothing to anything underneath it.
        //
        // Its SHAPE is not here: it goes into the chassis with the panels above,
        // so a tooltip poking out past the panel that asked for it melts into
        // the body rather than sitting on it. That is the eighth and last slot
        // the field has, which is exactly how many things can want one.
        Tooltip {
            id: tip

            anchors.fill: parent
        }
    }
}
