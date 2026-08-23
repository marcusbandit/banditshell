pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.modules.calculator
import qs.modules.cheatsheet
import qs.modules.clipboard
import qs.modules.keyboard
import qs.modules.menu
import qs.modules.launcher
import qs.modules.notifications
import qs.modules.session
import qs.modules.settings
import qs.modules.sidebar
import qs.modules.wallpaper
import qs.modules.windows
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
    // The launcher's twin: the same gesture out of the same band, over the same
    // list machinery, showing what you copied instead of what you can run.
    readonly property ClipboardPanel clipboard: clipLayer
    readonly property WallpaperPicker wallpapers: wallpaperLayer
    readonly property SessionMenu session: sessionLayer
    // Summoned by name exactly as the power panel is, and out of the opposite
    // flank; see modules/calculator/CalculatorPanel.qml for why it is a panel
    // rather than a fifth gauge.
    readonly property CalculatorPanel calculator: calcLayer
    // The board for when the machine is folded over. Registered here like every
    // other panel, and then deliberately left OUT of `keyboardFocus` below: it
    // is the one surface that must not hold the keyboard, because it types
    // through it. See modules/keyboard/OnScreenKeyboard.qml.
    readonly property OnScreenKeyboard keyboard: keyboardLayer
    readonly property SettingsPanel settings: settingsLayer
    // NAMED FOR THE IPC TARGET, not for the type, like every line above it:
    // modules/Ipc.qml reaches this as `win.hotkeys` and `hotkeys status` reads
    // `rows`, `unnamed` and `sections` off it. The sheet is the one panel here
    // whose entire content is the USER'S config rather than the shell's state,
    // so the CLI is not merely a second way in, it is the only way in: there is
    // no gauge, no edge and no gesture that summons it, only a key bound to
    // `banditshell hotkeys toggle`.
    readonly property CheatSheet hotkeys: cheatLayer
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

    // THE USAGE LOG, MENTIONED SO THAT IT EXISTS. A QML singleton is created the
    // first time something reads it and never a moment before, so a diary of
    // when this machine was awake whose only reader is the calendar would open
    // its first span when somebody first looked at a month, and would have
    // missed the boot it exists to record. Letting the calendar be the one that
    // touches it was the rejected alternative, and it is what the log did when
    // it first landed; this line is the whole fix, because the surface it sits
    // on lives exactly as long as the shell does. See services/Usage.qml.
    readonly property var usage: Usage

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
    //
    // AND ONLY FOR A PROMPT ON THIS SURFACE, which is what a second monitor
    // changes about the line at the bottom of all this. There is one of these
    // windows per screen and one Prompts list behind every one of them, so "a
    // field is waiting" was true on every monitor at once: a password field in a
    // menu over here, any menu at all still up over there, and both surfaces
    // asked outright. Two layer surfaces holding the keyboard exclusively is the
    // one arrangement in this entire comment where the keys reach NOBODY, which
    // is worse than every misrouting described above it, and it needs no
    // unusual gesture to reach, only a second screen. So the menu layer asks
    // Prompts about its own window rather than about the shell
    // (Menus.needsKeyboard, components/Prompts.qml). Every other term below is
    // already a fact about this window's own panels.
    //
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
    //
    // THE HOTKEY SHEET ASKS OUTRIGHT, on the power panel's argument and one of
    // its own. It has no field and nothing to type into, so it wants exactly
    // one key, but that key is Escape and it has to work from wherever the
    // sheet was summoned: a keybind opens it while the pointer is still resting
    // on whatever window you were reading, and on demand would mean clicking
    // the sheet before Escape did anything. Clicking the sheet is the one thing
    // that cannot be asked for, because a click off the card is what the
    // catcher answers by closing it.
    //
    // AND ANYTHING THAT WAS PINNED, which is the newest group and the one that
    // does not fit the sentence the first four make. A pinned menu, a pinned
    // notification tray and a pinned notch are not things you are in the middle
    // of typing into; they want exactly one key, and it is Escape.
    //
    // PINNED IS THE WHOLE TEST, and each surface answers it for itself
    // (Menus.wantsEscape, NotificationTray.wantsEscape, TopNotch.wantsEscape),
    // so this line never has to know what any of them is made of. HOVER IS
    // DELIBERATELY NOT IN IT. A tray the cursor is resting in is closed by the
    // cursor leaving, so it needs no key at all, and a shell that took the
    // keyboard off the focused window every time a pointer crossed the top-right
    // corner would be swallowing somebody's typing on behalf of a panel they
    // never asked for. A pin is somebody having said so; it is the one state
    // that does not go away on its own; and that is exactly the set that has to
    // be given a door.
    //
    // THE MENU IS NAMED TWICE HERE, under two properties, and that is not a
    // duplicate. `needsKeyboard` is a live prompt wanting EVERY key, which is
    // why the three panels above each close a menu that claims it: two things
    // cannot read one keyboard. `wantsEscape` is a menu somebody asked for
    // wanting ONE key, and nothing excludes it, because a menu you left up is
    // not in that fight. Folding them together would have closed every pinned
    // menu the instant the launcher opened. Menus' own note says why its term is
    // the PIN rather than the pinned menu being the one on screen: an incidental
    // hover menu drifting over a pinned one would otherwise drop and retake the
    // compositor's keyboard once per gauge the cursor crosses.
    //
    // EXCLUSIVE, LIKE THE REST, and this was the close call of the three. While
    // the term is true the compositor sends every key here and none to the
    // window underneath, and neither the tray nor the notch fills the screen, so
    // nothing in the picture explains where the typing went; nor does clicking
    // the other window get it back, because an exclusive layer keeps the
    // keyboard through that. On demand was the cautious answer and is rejected
    // for being dead in the case this exists for: `banditshell notifications
    // open` and `notch open` are meant to be bound to keys, they leave the
    // pointer resting on somebody else's window, and on demand Escape would then
    // do nothing until you had gone and clicked the very thing you were trying
    // to get rid of. That is word for word the sheet's argument above, and the
    // requirement here is absolute: Escape closes what is open, however it was
    // opened.
    //
    // What keeps the grab honest is that it cannot outlive its reason. It is
    // true only while something is PINNED; a pin is one Escape, one tap on the
    // corner or the strip, one push back into the edge it came out of, or one
    // CLI call from being gone; and the surface holding the keyboard is on
    // screen the whole time it holds it.
    // EXCLUSIVE IS NOT ONLY ABOUT THE KEYBOARD, and nothing in the protocol
    // says so. A layer surface that asks for the keyboard exclusively becomes
    // the compositor's focused surface, and Hyprland then routes the POINTER to
    // it as well, straight over the input region the surface set. Measured: with
    // a menu holding the keyboard this way, the shell was told the cursor was at
    // 3844,720 in its own coordinates, a point squarely inside the hole this
    // window's mask subtracts, and every click there was delivered here instead
    // of to the window under it. The mask is not consulted. Asking for the
    // keyboard is asking for everything.
    //
    // So every term on the EXCLUSIVE side costs the desktop its input for as
    // long as it is true, and each one has to be worth that. The six panels
    // are: they are the whole screen, and there is nothing underneath them to
    // click. `needsKeyboard` is: a field is waiting, and this shell is what is
    // being typed into.
    //
    // A PINNED MENU IS NOT, and it used to be. It wants one key, so it asks ON
    // DEMAND: the compositor hands the surface the keyboard when the surface is
    // clicked, which a menu opened by clicking its gauge already was, and takes
    // it back the moment a window is clicked instead. Escape reaches the menu
    // while the menu is what you are dealing with, the desktop keeps every
    // event it should have had, and neither has to be traded for the other.
    WlrLayershell.keyboardFocus: launcherLayer.open || clipLayer.open || wallpaperLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.needsKeyboard || popups.wantsEscape || topNotch.wantsEscape ? WlrKeyboardFocus.Exclusive : menuLayer.wantsEscape || settingsLayer.docked ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

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

        // THE MENU LAYER PUTS NOTHING ELSE IN HERE. A full-screen region used
        // to be combined in whenever a menu was pinned, so a click off the menu
        // would dismiss it; what it actually did was take every press on the
        // desktop away from the windows underneath for as long as any menu was
        // up. Menus have four ways out that cost nothing. See Menus.

        Region {
            intersection: Intersection.Combine
            item: launcherLayer.open ? launcherLayer.maskItem : null
        }

        // The launcher's, unchanged, for the panel that comes out of the same
        // band and is put away the same way.
        Region {
            intersection: Intersection.Combine
            item: clipLayer.open ? clipLayer.maskItem : null
        }

        Region {
            intersection: Intersection.Combine
            item: wallpaperLayer.open ? wallpaperLayer.maskItem : null
        }

        // The whole screen while the power panel is out, so a click anywhere
        // off it puts it away. It is summoned by keybind rather than reached
        // for, so there is no edge to leave and nothing else to dismiss it.
        Region {
            intersection: Intersection.Combine
            item: sessionLayer.open ? sessionLayer.maskItem : null
        }

        // The same entry for the same reason, on the other flank. A calculator
        // you asked for by name has no edge to leave either.
        Region {
            intersection: Intersection.Combine
            item: calcLayer.open ? calcLayer.maskItem : null
        }

        // THE BOARD, AND ONLY THE BOARD, which is the one place in this list
        // where that matters. Every entry above it names either a panel or a
        // screen-filling catcher, and the catchers are there so that a click off
        // a summoned panel dismisses it. The tablet keyboard's mask is its own
        // rectangle precisely so that a tap anywhere else does NOT come here: it
        // is open in order to type into the window underneath, so every pixel
        // that is not a keycap has to belong to that window. A catcher here
        // would make the board impossible to use for its only purpose.
        Region {
            intersection: Intersection.Combine
            item: keyboardLayer.open ? keyboardLayer.maskItem : null
        }

        // The whole screen while the sheet is out, so a click anywhere off it
        // puts it away. Word for word the power panel's case above: summoned by
        // keybind rather than reached for, so there is no edge to leave and
        // nothing else to dismiss it. Gated on `open` and not on the card's
        // visibility, so the region does not disappear from under a push that
        // has driven the card to transparent but not yet let go of it.
        Region {
            intersection: Intersection.Combine
            item: cheatLayer.open ? cheatLayer.maskItem : null
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

        // The window edge's strip, ALWAYS, on the launch edge's argument above
        // and with one difference worth stating: at its default height this
        // entry adds NOTHING, because the strip is exactly the band and the
        // chassis already claims that. It exists so that raising `windows.grab`
        // widens the region along with the target, rather than widening a target
        // the compositor still refuses to deliver into.
        Region {
            intersection: Intersection.Combine
            item: windowEdge.maskItem
        }

        // THE WHOLE SCREEN WHILE A WINDOW IS IN THE AIR, which is the one thing
        // that lets a SECOND finger reach the shell: a layer surface hears
        // nothing outside its own region, and this one's region is the chassis.
        // See WindowEdge.grabItem. Conditional, unlike the strip above, because
        // it is the whole screen and must not outlive the gesture by a frame.
        Region {
            intersection: Intersection.Combine
            item: windowEdge.lifted ? windowEdge.grabItem : null
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
    //
    // AND A FOCUSSCOPE RATHER THAN AN ITEM, which is one word doing the same job
    // for the keyboard that the paragraph above does for the pointer.
    //
    // Qt gives active focus to exactly ONE item in a window, and every panel here
    // takes it for itself the moment it wants a key: each runs the same
    // `Qt.callLater(keys.forceActiveFocus)`. Two pinned surfaces therefore cannot
    // both hold it, and that much is harmless, because whichever holds it answers
    // Escape, closes, and hands the focus back. The hole is where it goes back
    // TO. Clearing focus inside a plain item hands active focus to the window's
    // root item, which is an ANCESTOR of everything drawn here, and a key event
    // travels UP from the focused item, never down: measured in a test window,
    // the state left behind by pinning the tray, opening the launcher over it and
    // closing the launcher again is a window where no item holds the focus at
    // all, while this surface goes on asking the compositor for every key because
    // the tray is still pinned. Every one of those keys is dropped on the floor,
    // and the tray can no longer be closed by the key that exists to close it.
    //
    // A focus scope catches exactly that: clearing focus inside a scope gives
    // active focus to the SCOPE. So it lands here, on the one item that is an
    // ancestor of every panel and can therefore answer for all of them. The
    // rejected alternative was to have each surface re-take the focus when it
    // noticed it had lost it, which is two items that both want it taking turns,
    // and the one after that was to have each new pin close the others, which is
    // a shell deciding you may only have asked for one thing.
    //
    // `focus: true` is the other half. It makes this the item holding focus
    // before anything has been opened at all, so the first Escape of a session
    // works like the tenth; a panel that asks still wins it the instant it asks,
    // so nothing about the launcher's search field changes.
    FocusScope {
        id: body

        anchors.fill: parent
        focus: true

        // ESCAPE, FOR WHATEVER IS OPEN, and only ever as the fallback.
        //
        // Every panel answers its own Escape and ACCEPTS the event, and an
        // accepted key stops travelling, so while any of them holds the focus
        // this handler is not reached and cannot double-close anything. It runs
        // in the state the note above describes, where the focus came back here
        // because a panel handed it over while another one is still up, and it
        // then has to say what that panel would have said.
        //
        // ONE THING PER PRESS, and the order is what the press would have found
        // if the focus had been where it belonged. Whichever panel took the
        // keyboard for itself goes first, because it is the thing you are in the
        // middle of doing (the three are mutually exclusive, so at most one of
        // them is up). Then the pinned menu, which is the only one of the rest
        // that also holds the POINTER, since its catcher covers the screen. Then
        // the settings page, which is a document you left open on purpose. Then
        // the notch and the tray, which are readouts hanging off an edge and are
        // the least in anybody's way. Those last two cannot overlap on screen, so
        // the order between them decides nothing except which of two presses
        // takes which, and the notch is written first because it hangs over the
        // middle of the screen where the tray keeps to its corner.
        //
        // THE TRAY AND THE NOTCH DROP THE PIN rather than being closed, which is
        // what their own handlers do, and what the corner tap and the push-back
        // do as well. Presence on both is a union and the pin is one term of it,
        // so a cursor still resting in the tray holds it open until the cursor
        // leaves. Ordering them closed from here would be exactly the argument
        // those unions exist to end.
        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;

            if (launcherLayer.open)
                launcherLayer.hide();
            else if (clipLayer.open)
                clipLayer.hide();
            else if (wallpaperLayer.open)
                wallpaperLayer.hide();
            else if (sessionLayer.open)
                sessionLayer.hide();
            else if (cheatLayer.open)
                cheatLayer.hide();
            else if (calcLayer.open)
                calcLayer.hide();
            else if (menuLayer.wantsEscape)
                menuLayer.hide();
            else if (settingsLayer.docked)
                settingsLayer.hide();
            else if (topNotch.wantsEscape)
                topNotch.pinned = false;
            else if (popups.wantsEscape)
                popups.pinned = false;
            else
                return;

            event.accepted = true;
        }

        HoverHandler {
            id: onShell
        }

        // THE BAR'S OWN BLOBS, moved into the chassis's frame.
        //
        // Everything else in the list below is laid out against this same frame
        // and hands its shapes over ready to use; the sidebar is the one source
        // that lives INSIDE something, so what it publishes is in its own
        // coordinates and this is where that becomes the window's. Read off the
        // item rather than restated as `win.border`, so it stays right the day
        // the bar is anchored somewhere else.
        readonly property var barBlobs: sidebar.blobs.map(b => ({
                    x: b.x + sidebar.x,
                    y: b.y + sidebar.y,
                    w: b.w,
                    h: b.h,
                    radius: b.radius,
                    smooth: b.smooth
                }))

        Chassis {
            id: chassis

            anchors.fill: parent
            // Open panels join the shell's distance field rather than being drawn
            // on top of it, which is what lets them melt into the body.
            // Everything that joins the shell's body. Each melts into the CHASSIS
            // and none of them melt into each other; see blob.frag's meltPanel.
            panels: [...body.barBlobs, ...menuLayer.blobs, ...launcherLayer.blobs, ...clipLayer.blobs, ...wallpaperLayer.blobs, ...topNotch.blobs, ...popups.blobs, ...launchEdge.blobs, ...volumeRail.blobs, ...sessionLayer.blobs, ...calcLayer.blobs, ...keyboardLayer.blobs, ...tip.blobs, ...micIndicator.blobs, ...launchNotice.blobs, ...settingsCorner.blobs]
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

            // THERE IS NO SETTINGS HANDLER HERE ANY MORE. A gauge that was a
            // door stood in the column, emitting a `settingsRequested` of its
            // own that this block answered; StatusIcons took it out on purpose
            // (its own note says why: a place is not a glance) and the signal
            // went with it. A Connections handler for a signal the target does
            // not declare is not inert, it is a warning on every reload and a
            // paragraph of reasoning about a control nobody can press, so it is
            // gone rather than kept "in case". Settings is reached by the
            // bottom-right corner, by `banditshell settings`, and therefore by
            // any keybind.

            function onReleased(): void {
                menuLayer.release();
            }
        }

        // The tray, wired exactly like the gauges above and carrying the same
        // second word: TrayIcons says whether a menu was asked for outright or
        // merely wandered into, so a hover stays incidental and the right
        // button and the long press do not. This block used to guess, because
        // the tray forwarded one word and there was nowhere in it to hang the
        // flag; the flag exists now, so the toggle below is the gauges' two
        // lines verbatim rather than a weaker version of them.
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

            // WHO IS ALREADY READING THE KEYBOARD, so that a pin cannot take it
            // off them.
            //
            // Every pinned surface here grabs the window's focus for its own
            // Escape (the tray, the notch and the menu layer all run the same
            // deferred forceActiveFocus), and Qt gives active focus to exactly
            // ONE item in a window. A pin can arrive at any moment: `banditshell
            // notifications open` is meant to be bound to a key, and a compositor
            // bind is still delivered while a layer surface holds the keyboard.
            // Landing on top of the launcher it took the caret out of the search
            // field, which went on drawing and stopped hearing, and nothing gave
            // it back, because the exclusions written on the three panels below
            // fire when a panel OPENS and this pin arrived second.
            //
            // THE SAME TERMS keyboardFocus's first half names, because it is the
            // same question: who wants EVERY key. A menu holding a live prompt is
            // one of them however little it looks like a panel. The settings page
            // is deliberately not: it asks on demand and answers only Escape, so
            // a pin taking the focus from it costs one extra press through the
            // fallback above rather than a field that has gone deaf.
            //
            // Handed down rather than looked up, like every other property on
            // these layers: this file is the one place that can see all of them
            // at once, and a tray reaching up here by id would be the layer
            // reading the file that declares it.
            keyboardHeld: launcherLayer.open || clipLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.needsKeyboard
        }

        Menus {
            id: menuLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            // The whole surface, not this panel: see `body` above.
            shellHovered: onShell.hovered

            // THE GAUGES' MENUS, BUILT BEFORE ANYBODY POINTS AT ONE. See
            // MenuPanel.warm for what that buys and what it costs, and Menus.
            // warmSource for why this list being rebuilt constantly is fine.
            //
            // The gauges and nothing else: they are the four things a hand
            // sweeps across, they are a fixed set that cannot change at
            // runtime, and the tray's menus could not be warmed anyway (one
            // Component, many applications). The sidebar's whole `menuItems`
            // would have swept up the tray and the clock's two pages with them.
            warmSource: sidebar.status.items

            // The tray's note above, MINUS ONE TERM. A menu's own live prompt is
            // this layer's business rather than this file's, so Menus asks its
            // own `needsKeyboard` inside the grab and is handed only the three
            // panels it cannot see. Naming its own claim here as well would be
            // one fact in two places, and the copy out here would be the one to
            // go stale.
            keyboardHeld: launcherLayer.open || clipLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open
        }

        Launcher {
            id: launcherLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            // See the session panel below: nothing that takes the keyboard
            // outright can be up with anything else that does, and a menu
            // holding a live prompt is one of those things however little it
            // looks like a panel.
            onOpenChanged: if (open) {
                sessionLayer.hide();
                cheatLayer.hide();
                wallpaperLayer.hide();
                clipLayer.hide();
                calcLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        // WHAT YOU COPIED. The launcher's twin, and stated as one: same band,
        // same rise, same put-away, same exclusive keyboard, and the same list
        // that a click off it dismisses.
        //
        // Mutually exclusive with every other panel that takes the keyboard
        // outright, for the reason the power panel's note spells out: whichever
        // asked second would be typing into the first. This one has a stronger
        // form of the same problem, because its list answers bare letters (`p`
        // keeps a row, `x` throws one away) rather than only navigation keys.
        ClipboardPanel {
            id: clipLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border

            onOpenChanged: if (open) {
                launcherLayer.hide();
                wallpaperLayer.hide();
                sessionLayer.hide();
                cheatLayer.hide();
                calcLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        // THE SECOND THING THE BOTTOM EDGE DOES. Out of the same edge, in the
        // same motion, as the alternative to what is already up rather than as
        // a panel of its own: see the edge below, and WallpaperPicker's own
        // note. Mutually exclusive with the launcher because they occupy the
        // same place on the screen and are reached by the same gesture, which
        // is as exclusive as two things get.
        WallpaperPicker {
            id: wallpaperLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border
            // Whatever the live launcher concept is actually as wide as, with a
            // floor for the moment before its loader has built one: a zero
            // would size the picker off its own minimum for one frame and it
            // would visibly settle.
            launcherSpan: Math.max(launcherLayer.panelWidth, Appearance.sizes.launcherWidth)

            onOpenChanged: if (open) {
                launcherLayer.hide();
                clipLayer.hide();
            }
        }

        // Power, on the right edge, summoned by keybind rather than reached for.
        SessionMenu {
            id: sessionLayer

            anchors.fill: parent
            border: win.border

            // Whichever asked for the keyboard second would be typing into the
            // other one: the launcher's search field takes every printable key,
            // including the ones this panel navigates with.
            //
            // AND A MENU HOLDING A PROMPT, which is the fourth exclusive state
            // and the one that was in nobody's list. `keyboardFocus` above names
            // four terms and only three of them excluded each other, because a
            // menu is normally not a keyboard thing at all: it asks for the
            // keyboard ONLY while a field inside it is waiting to be typed into
            // (Menus.needsKeyboard), which is rare enough to have been missed
            // and is exactly when losing it hurts most. Whichever of these panels
            // opens over a live prompt calls `forceActiveFocus` on its own key
            // item, which takes the caret out of that field: the password can no
            // longer be typed, and the click that would put the caret back lands
            // on the new panel's screen-filling catcher and dismisses that
            // instead. The prompt is dead the moment the keyboard moves, so it is
            // put away honestly rather than left on screen pretending to listen.
            //
            // Gated on `needsKeyboard` and NOT on the menu merely being open. A
            // menu with nothing to type into is a readout the cursor wandered
            // into, it fights over nothing, and closing it here would take away
            // the audio menu somebody left up because they reached for the
            // launcher.
            onOpenChanged: if (open) {
                launcherLayer.hide();
                clipLayer.hide();
                cheatLayer.hide();
                calcLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        // Arithmetic, out of the sidebar's flank: the power panel's twin,
        // mirrored. Summoned by name, keyboard taken outright, whole screen in
        // the mask so a click anywhere off it puts it away, and mutually
        // exclusive with everything else that takes the keyboard for exactly the
        // reason spelled out over the power panel above.
        //
        // GIVEN ONLY `originX`, where the panels around it are given an inset
        // too: it is centred on the screen rather than hung from a band, so the
        // only thing it has to know is where the chassis stops.
        CalculatorPanel {
            id: calcLayer

            anchors.fill: parent
            originX: chassis.barWidth

            onOpenChanged: if (open) {
                launcherLayer.hide();
                clipLayer.hide();
                wallpaperLayer.hide();
                sessionLayer.hide();
                cheatLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }
        }

        // THE TABLET BOARD, out of the bottom band, for when the machine is
        // folded over and the real keyboard is face down on the table.
        //
        // IT CLOSES NOTHING AND NOTHING CLOSES IT, which is why it has no
        // `onOpenChanged` block like the two panels above. Every other summoned
        // surface here is exclusive with the rest, because they all want the
        // keyboard and only one can have it. This one wants the opposite: it is
        // open in order to type into something else, so a launcher opening over
        // it is a perfectly sensible thing to want to type into. Making it
        // dismiss its neighbours would mean the board could not be used on the
        // one surface a folded machine most needs it for.
        OnScreenKeyboard {
            id: keyboardLayer

            anchors.fill: parent
            originX: chassis.barWidth
            inset: win.border
        }

        // EVERY BIND THE COMPOSITOR KNOWS ABOUT, summoned by name and drawn
        // from `hyprctl binds -j` on every open. It is the only panel here that
        // recites something the shell does not own, which is exactly why it
        // asks the compositor afresh each time instead of being handed a list:
        // the sheet is what you open after changing a bind, so a cached one is
        // wrong at the moment it is consulted. See modules/cheatsheet/.
        //
        // NOTHING IS PASSED DOWN TO IT. It reads the same band and sidebar
        // tokens the chassis derives its hole from, so it centres in the
        // content area on its own; if Chassis's formula ever changes, the
        // honest fix is to hand it the hole the way the settings page is handed
        // one, and there is a note in the file saying so.
        //
        // IT CONTRIBUTES NO BLOB and must not be added to `chassis.panels`. The
        // field is for things that GROW OUT of the shell's body, where the
        // fillet says the two are connected (DESIGN.md 14); this is a document
        // floating clear of every band, and a melt reaching that far would be
        // claiming a connection that is not there. The field has twelve slots
        // and ten sources already, so the restraint is not free either.
        CheatSheet {
            id: cheatLayer

            anchors.fill: parent

            // The third panel that takes the keyboard outright, so it excludes
            // the other two and both of them exclude it, and a menu holding a
            // live prompt is the fourth (the session panel above carries that
            // argument in full). Stated on each of them rather than in one
            // place, matching how the first two already exclude each other:
            // each panel says what it does to the others where it is declared,
            // and a central arbiter would be one more thing to keep in step
            // with the list.
            //
            // AND THE SETTINGS PAGE, which the other two deliberately leave
            // alone. Its own note below says why and it stands: a page you left
            // open while you went to look at what you changed should survive
            // somebody reaching for the launcher. This panel is the one
            // exception because it is the one that STANDS IN THE SAME
            // RECTANGLE. Both centre themselves in the chassis's hole; the page
            // is declared after this one, so it draws and takes input ON TOP of
            // the sheet; and this panel takes the keyboard the instant it opens,
            // which pulls focus off the page and leaves its Escape dead. What
            // that added up to was a settings card sitting opaque over the
            // middle of the sheet, hiding the rows and swallowing the presses
            // aimed at them, dismissable by neither key nor click. Two
            // documents cannot share one hole, so the one just asked for wins.
            //
            // Only while the SHELL is drawing it. A page a window has taken over
            // is a window like any other, standing wherever its owner put it and
            // nowhere near this rectangle, and closing it from here would be a
            // layer surface reaching outside itself.
            onOpenChanged: if (open) {
                launcherLayer.hide();
                clipLayer.hide();
                sessionLayer.hide();
                calcLayer.hide();
                if (settingsLayer.docked)
                    settingsLayer.hide();
                if (menuLayer.needsKeyboard)
                    menuLayer.hide();
            }

            // THE SHEET'S TWO CHOICES, KEPT ACROSS A RESTART. This is the other
            // half of the contract written over `board` and `symbols` in
            // CheatSheet.qml: the sheet holds them for the session and says
            // plainly that it cannot give itself a key in config.json, because
            // the schema is Config's defaults block. The key exists now, so this
            // is what makes it real rather than a setting that lies.
            //
            // HERE RATHER THAN IN THE SHEET, which is the compromise and not the
            // design. The sheet's own note asks for `readonly property bool
            // board: Config.get(...)` with the pick handler calling `Config.set`,
            // and that is where this belongs the next time that file is open: one
            // line each, no handlers, and no window in the middle of it. Wired
            // from out here it works today and it breaks loudly rather than
            // quietly if the sheet ever takes the job back, because assigning to
            // a readonly property is a warning on the console.
            //
            // Read on completion AND on the file landing, because either can
            // happen first. Config reads config.json asynchronously, so a shell
            // starting cold has the defaults at this moment and the real answer a
            // moment later; a hot reload has it the other way round, with the
            // values already loaded before this panel exists. Neither order can
            // lose the setting, and neither can write over it: the guard below
            // means a restore never becomes a save.
            Component.onCompleted: {
                cheatLayer.board = Config.get("cheatsheet.board");
                cheatLayer.symbols = Config.get("cheatsheet.symbols");
            }

            // Written where the choice changes rather than where it is made, so
            // that the CLI route persists too: `banditshell config set
            // cheatsheet.board true` moves the sheet through the block below, and
            // a pick moves the file through this one. Each handler carries its
            // own guard rather than sharing a helper, which is the same call the
            // three menu toggles above make: the guard is the whole of what the
            // handler means, and it stops the restore below bouncing back as a
            // second write of a value the file already holds.
            onBoardChanged: {
                if (cheatLayer.board !== Config.get("cheatsheet.board"))
                    Config.set("cheatsheet.board", cheatLayer.board);
            }

            onSymbolsChanged: {
                if (cheatLayer.symbols !== Config.get("cheatsheet.symbols"))
                    Config.set("cheatsheet.symbols", cheatLayer.symbols);
            }
        }

        // THE FILE ANSWERING BACK, which is what makes the two settings above
        // behave like settings rather than like a cache of the last click.
        //
        // Config watches config.json, so this fires for a hand edit, for the
        // generic `banditshell config set`, and for the sheet's own pick coming
        // back round. It is also the only thing that makes the choice agree
        // across SCREENS: there is one of these surfaces per monitor and
        // therefore one sheet per monitor, and without this a pick made on one
        // would leave the other still drawing the view it was last shown.
        //
        // A Connections rather than a binding on the properties themselves,
        // because `board` and `symbols` are written by the sheet's own pick
        // handlers, and a binding is destroyed by the first thing that assigns
        // through it: the sheet would toggle once and then never again.
        Connections {
            target: Config

            function onValuesChanged(): void {
                cheatLayer.board = Config.get("cheatsheet.board");
                cheatLayer.symbols = Config.get("cheatsheet.symbols");
            }
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
            //
            // THE HOTKEY SHEET IS THE EXCEPTION, and about geometry rather than
            // about the keyboard: it is the only other panel that centres itself
            // in the chassis's hole, so the two are drawn one on top of the
            // other in the same rectangle. Its declaration above carries that
            // argument; the block below is the other half of it, because an
            // exclusion stated in one direction is only half an exclusion.
        }

        // THE SHEET GIVES WAY TO THE PAGE, the way the page gives way to the
        // sheet. Both are reachable while the other is up: the settings corner
        // is declared after the sheet and so sits above its catcher, and
        // `banditshell settings` and any keybind for it work from anywhere. The
        // sheet is what goes, because the page is what was just asked for and
        // the sheet is one keypress from being back.
        //
        // A Connections RATHER THAN AN `onDockedChanged` WRITTEN ON THE PANEL
        // ABOVE, and that is load-bearing rather than a style choice.
        // SettingsPanel declares its own `onDockedChanged` (it snaps the card's
        // four followers so an opening page is placed rather than flown to, and
        // takes focus there), and a handler written at the usage site is an
        // assignment to that same slot: it would REPLACE the panel's own
        // instead of running beside it, and the page would animate in from
        // wherever it last happened to be with no keyboard. Connections adds a
        // second receiver and leaves the first alone. The three panels above can
        // safely write their handlers inline only because none of them declares
        // one internally.
        Connections {
            target: settingsLayer

            function onDockedChanged(): void {
                if (settingsLayer.docked)
                    cheatLayer.hide();
            }
        }

        // The bottom edge, as a way in: it swells under the cursor, opens on a
        // click, and opens on a push up from it.
        //
        // AND IT DOES A SECOND THING ON THE SECOND PULL. The edge used to be
        // disarmed the moment the launcher was up, on the theory that an edge
        // whose panel is already out has nothing left to offer. It has: the
        // same motion, made again, is how a touchscreen walks through what
        // lives in one place, and the two things that live at the bottom of
        // this screen are the launcher and the wallpapers. So a pull with the
        // launcher up is a pull for the picker, and the launcher goes as the
        // picker arrives.
        //
        // Which one the pull is FOR is decided at the press rather than at the
        // release, because the drag has to track the right panel the whole way
        // up. `armed` is still false once the picker itself is up: at that
        // point there genuinely is nothing further along, and a third pull
        // should do nothing rather than cycle back to the launcher, which would
        // make the edge a carousel nobody asked for.
        LaunchEdge {
            id: launchEdge

            // Which panel this pull is driving. Latched on the press, so a
            // launcher that closes mid-drag (because the picker it is handing
            // over to has opened) cannot move the gesture to a different panel
            // halfway through it.
            property var target: null

            anchors.fill: parent
            border: win.border
            span: launcherLayer.open ? wallpaperLayer.panelWidth : launcherLayer.panelWidth

            // ARMED EVEN AT THE END OF THE STACK, where the pull has nowhere
            // left to go. It has to be: unarmed, the press falls through to
            // whatever is under the band, which with the picker up is the
            // dismiss catcher, and a swipe UP would put the panel away. That is
            // the one thing a swipe up must never do. Armed, the press is
            // consumed and the gesture simply saturates, which is what the
            // phone this borrows from does at the end of its own stack.
            armed: true

            // WHICH PANEL THIS PULL IS FOR, decided once.
            //
            // The bottom edge holds two things and one pull moves you one step
            // along them: nothing up, and it is the launcher; the launcher up,
            // and it is the wallpapers. At the end there is no third thing, and
            // the answer is nothing at all rather than a wrap back to the
            // start: a gesture that cycles is a gesture you have to count, and
            // the whole appeal of this one is that it is the same motion
            // meaning the same "further in" every time.
            //
            // Latched at the earliest moment the gesture says anything, and NOT
            // re-read after that. `pressed` is that moment for a finger on the
            // edge; a gesture that arrives some other way (a two-finger scroll
            // has no press) says its first word in `dragged`, so that latches
            // too when nothing has yet. Deciding it twice is the bug this
            // exists to prevent: the launcher closes the instant the picker
            // opens, so a second reading mid-drag would hand the rest of the
            // gesture to a different panel.
            property bool aimed: false

            // WHAT THE PULL IS LEAVING, when it is leaving something. A pull
            // for the picker is also a pull AWAY from the launcher, and the two
            // halves are one motion rather than a change that happens at the
            // end of one: the launcher goes down by exactly as much as the
            // picker comes up, so the finger is holding a handover rather than
            // holding one panel while another waits its turn behind it.
            //
            // It also makes the gesture reversible in the way the rest of this
            // shell is. Push halfway and change your mind, and the launcher
            // comes back up from where it had got to, with everything still
            // typed into it.
            property var leaving: null

            function aim(): void {
                if (launchEdge.aimed)
                    return;
                launchEdge.aimed = true;
                launchEdge.target = wallpaperLayer.open ? null : launcherLayer.open ? wallpaperLayer : launcherLayer;
                launchEdge.leaving = launchEdge.target === wallpaperLayer ? launcherLayer : null;
            }

            onPressed: {
                launchEdge.aimed = false;
                launchEdge.aim();
            }

            onDragged: fraction => {
                launchEdge.aim();
                launchEdge.target?.dragTo(fraction);
                // One minus, because it is the same fraction seen from the
                // other end: a picker a quarter of the way out is a launcher
                // three quarters of the way home.
                launchEdge.leaving?.dragTo(1 - fraction);
            }

            onFinished: open => {
                launchEdge.aim();
                launchEdge.target?.dragEnd(open);
                // INVERTED, and the inversion is the whole point: the pull
                // carrying on means the picker arrives AND the launcher leaves,
                // and reversing means neither. `dragEnd(true)` on a launcher
                // that is already shown simply walks it back up from where the
                // drag left it, which is exactly what changing your mind should
                // look like.
                launchEdge.leaving?.dragEnd(!open);
                launchEdge.aimed = false;
                launchEdge.target = null;
                launchEdge.leaving = null;
            }
        }

        // THE SAME EDGE, ANSWERING A FINGER, and answering it about the window
        // rather than about the shell. Push up from the bottom of a window and
        // it comes up with you: let go and it is closed, hold and the workspaces
        // come out to put it on. See modules/windows/WindowEdge.qml, which
        // carries the whole argument for why two gestures can share one edge.
        //
        // DECLARED AFTER THE LAUNCH EDGE, so it is offered the press first and
        // can hand it back. Everything it does not want (a mouse, a finger with
        // no window above it, a finger while a panel is up) is refused on the
        // press and falls through to the pull below exactly as before.
        WindowEdge {
            id: windowEdge

            anchors.fill: parent
            screen: win.screen
            border: win.border

            // WHERE A SWIPE WITH NO WINDOW ABOVE IT GOES. The window edge takes
            // the touch points itself now, so it can no longer refuse a press
            // and let it fall through to the pull below: it hands the gesture
            // over instead. That is what keeps the launcher reachable by finger
            // from a bare workspace, which is the whole of what the bottom edge
            // used to mean.
            fallback: launchEdge

            // The chassis's hole, not the screen: the card is sized against the
            // space windows actually live in, and the shelf centres in it.
            holeX: chassis.holeX
            holeY: chassis.holeY
            holeWidth: chassis.holeWidth
            holeHeight: chassis.holeHeight

            // EVERYTHING THAT COMES OUT OVER THE BAND. A finger landing on the
            // bottom of the screen while one of these is up is aiming at the
            // panel, not at the window behind it, and the on-screen keyboard is
            // the sharpest case: it IS the bottom of the screen, and its bottom
            // row of caps sits exactly in this strip.
            //
            // A pinned menu counts even though it lives on the other side of the
            // screen, because its catcher covers everything and a tap anywhere
            // off it is how it is dismissed. The notification tray does not:
            // it hangs in the top corner and has never owned this edge.
            blocked: keyboardLayer.open || launcherLayer.open || clipLayer.open || wallpaperLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.open || settingsLayer.docked
        }

        TopNotch {
            id: topNotch

            anchors.fill: parent
            border: win.border

            // The tray's note above, verbatim and for the same reason: a pin must
            // not take the keyboard off whatever is being typed into, and `notch
            // open` is as much a keybind as `notifications open` is.
            keyboardHeld: launcherLayer.open || clipLayer.open || sessionLayer.open || cheatLayer.open || calcLayer.open || menuLayer.needsKeyboard
        }

        // LOAD-BEARING, and its blob above must stay in `panels`. This is the
        // only feedback that the microphone is live; see MicIndicator.qml.
        //
        // Dictation, when the microphone is actually open. It comes out of the
        // same top edge as the notch and the field melts the two together when
        // they meet, rather than showing two pills fighting for the same space.
        //
        // It does NOT share the notch's axis any more. The notch is about the
        // screen and this is about a window: it rides over whatever holds the
        // keyboard, on that monitor alone. See MicIndicator's `anchor`.
        //
        // No mask entry, like the tooltip: it is a readout, not a control, and
        // nothing about it is meant to be clicked.
        MicIndicator {
            id: micIndicator

            anchors.fill: parent
            border: win.border
        }

        // WHAT YOU JUST ASKED FOR, while it is still coming up. Out of the
        // bottom band, which is the edge the launcher went back into: you
        // pressed Return there, so that is where the answer belongs.
        //
        // A readout like the mic indicator, so no mask entry: a launch you are
        // waiting for is not something to press.
        LaunchNotice {
            id: launchNotice

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
