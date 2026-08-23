pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE LIST CONCEPT: a search field over a dense, icon-led list of everything
// installed, ranked by what you use.
//
// One of two launchers; Launcher.qml picks between them and both stay in the
// tree. See NiagaraLauncher for the other, and `banditshell set
// launcher.concept` to change which one is live.
//
// It hangs from the TOP BAND, centred on the content area, and swells downwards
// out of it. It used to grow from the sidebar, which kept it part of the chassis
// but put it against one edge: fine on a 16:9 screen, a long way from where you
// are looking on an ultrawide. Centred and top-hung it is both, because the top
// band runs the whole width and so the shell has something to melt it out of
// wherever it sits.
//
// It is the ONE thing here that takes the keyboard. A layer surface gets no key
// events unless its window asks for them, so ShellWindow raises the surface's
// keyboard focus while this is open and drops it the moment it closes: without
// that the field looks focused, shows a cursor, and receives nothing.
//
// It closes on a CLICK anywhere outside, and never on hover. Hover-close is
// right for something the cursor summoned and wrong for something a keybind
// did: the pointer is nowhere near it when it opens, so closing when the pointer
// leaves would close it before it had been used.
Item {
    id: root

    required property real originX
    required property real inset

    readonly property bool open: shown
    property bool shown: false

    // For `banditshell status`. Open and DRAWN are different states, and the
    // difference is invisible from outside: a panel that is shown but zero
    // pixels tall looks exactly like one that is closed.
    readonly property real drawnHeight: panel.height
    readonly property int resultCount: results.length
    readonly property string scrollInfo: `row ${root.selected} of ${root.results.length}, at ${Math.round(list.contentY)}/${Math.round(list.maxScroll)}`

    readonly property real panelWidth: Appearance.sizes.launcherWidth

    // Which way it leaves. A panel that reaches the bottom band is PART of the
    // shell down there, so it withdraws into it the way it came; one hanging
    // free in the middle has nothing to withdraw into, and sliding it down to an
    // edge it never touched is a journey to nowhere. That one folds into itself.
    property bool collapseToCentre: false

    // The whole screen while it is open, so a click anywhere lands on the shell
    // and can dismiss it. The panel alone would let every click outside fall
    // through to whatever is behind, which is how a launcher ends up typing into
    // the window you were trying to leave.
    readonly property Item maskItem: catcher

    readonly property var results: Apps.search(query.text)
    property int selected: 0

    // WHAT THE QUERY COMES TO, when the query is a sum. Null for everything
    // else, which is nearly everything: Calc.answer refuses anything that did
    // not actually ask for a calculation, so a search for "7" is a search and
    // only an expression carrying an operator gets a row. See
    // modules/launcher/AnswerRow.qml.
    readonly property var answer: Calc.answer(query.text)

    // WHOSE KEY RETURN IS. It starts as the answer's, because a query that
    // parses as a sum is one somebody typed on purpose and the row is right
    // under the caret; it becomes the list's the moment they step into the list,
    // which is the only unambiguous signal that they meant an application after
    // all. Re-armed on every change to the query, so correcting a typo in a sum
    // gives the answer the key back rather than leaving it with a list nobody is
    // looking at.
    property bool answerHolds: false

    onAnswerChanged: root.answerHolds = !!root.answer

    // One row's pitch, computed HERE and handed to the rows, rather than read
    // back off the list once it has laid itself out.
    //
    // That readback was a cycle: the panel's height came from the list's
    // contentHeight, and the list's height came from the panel. It bootstrapped
    // only because cacheBuffer happens to build a few delegates even in a
    // zero-height view, which is an accident, not a mechanism. Knowing the pitch
    // up front means the panel's size follows from the RESULT COUNT and the list
    // never has to be measured at all.
    // Tighter than a menu row's on purpose. A menu is a handful of settings and
    // can afford air; this is a list of every application installed, and every
    // pixel of row height is one fewer result you can see at a glance.
    readonly property real rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.small * 2)

    // The blob the chassis melts in.
    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    // What had the keyboard before this took it.
    //
    // Taking exclusive focus makes the compositor unfocus the window under it,
    // and letting go does NOT hand it back: you got the launcher, dismissed it,
    // and were left typing into nothing until you clicked the window again.
    //
    // An ADDRESS off the event stream, not Hyprland's `activeToplevel`, which is
    // refreshed by an IPC round trip and so is one window behind at the moment
    // this needs it. Captured on the way up, because by the time the grab is
    // live there is nothing left to capture.
    //
    // AND THIS SCREEN'S ADDRESS, not the shell's. There is one launcher per
    // monitor and the bottom edge that opens it is under a hand rather than
    // under the keyboard, so the window this panel came out in front of is the
    // one that was in front of you HERE. `Hypr.focusedAddress` is a single slot
    // holding whichever window last took the keyboard anywhere, and reading it
    // meant a launcher opened on the quiet screen handing the keyboard back
    // across the desk on Escape, with the pointer deliberately left behind to
    // undo it a twitch later. `Hypr.focusedOn` is the same question asked of one
    // screen; services/Hypr.qml's `focusedByMonitor` carries the argument.
    property string restoreTo: ""

    // WHICH SCREEN THIS LAUNCHER IS DRAWN ON, for the line above.
    //
    // ASKED OF THE WINDOW rather than handed down. modules/SettingsCorner.qml
    // established the idiom and modules/sidebar/Sidebar.qml and
    // modules/notifications/NotificationTray.qml both follow it: the screen is
    // not a fact about the launcher the way `originX` is, it is a fact about the
    // surface the launcher happens to be drawn on, and this one is built by a
    // Loader inside modules/launcher/Launcher.qml that would otherwise have to
    // forward a property it has no other use for, twice, once per concept.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    function show(): void {
        // TAKEN ONLY WHEN IT IS ACTUALLY OPENING, which is the one thing this
        // function does that must not happen twice. `banditshell launcher open`
        // never asks whether the panel is already up, and neither does a drag
        // that ends open on one it never closed; both of those mean "start the
        // query again", and neither of them means "forget where I came from".
        // Every other panel in the shell refuses the whole call when it is
        // already showing (the clipboard, the calculator, the power panel, the
        // hotkey sheet, the settings page) and so has never had to say this.
        // This one cannot: reopening onto a stale query is the bug those
        // guards would reintroduce here, so the reset stays unconditional and
        // the memory is what gets guarded instead.
        //
        // ON ONE SCREEN THE SECOND READ IS HARMLESS, which is why it stood.
        // The panel holds the keyboard by then, and Hyprland announces focus
        // moving to a layer surface as an empty activewindowv2 that
        // services/Hypr.qml drops on purpose, so the remembered address still
        // names the window it named on the way up and reading it again gets the
        // same answer. On two screens it did not. Push the pointer onto the
        // other monitor while this is open and the window under it takes focus
        // for real, with a real address, and a second show() swapped the window
        // you were working in for one you merely passed over. Escape then handed
        // the keyboard to the wrong monitor, which is the failure this whole
        // property exists to prevent, arrived at from the other end.
        //
        // AND THE SOURCE HAS BEEN FIXED UNDERNEATH IT SINCE. That stray focus
        // now lands in the OTHER monitor's slot, so this screen's answer does
        // not change when the pointer wanders off it and a second read gets what
        // the first one got. The guard stays anyway, because it says something
        // the map does not: reopening a panel that is already up means start the
        // query again, and never means forget where you came from. Being right
        // about that twice costs one comparison.
        if (!root.shown)
            root.restoreTo = Hypr.focusedOn(root.screenName);
        // Always out of the bottom edge, whatever the last close did.
        root.collapseToCentre = false;
        root.unsized = true;
        root.shown = true;
        query.text = "";
        root.selected = 0;
        // DEFERRED. Focus is only worth taking once the window has actually
        // asked the compositor for the keyboard, and that follows from `shown`
        // in the same pass this is running in.
        Qt.callLater(query.forceActiveFocus);
    }

    function hide(): void {
        // Decided HERE, while the panel is still open, because by the time it is
        // closing its own geometry no longer says where it came from.
        root.collapseToCentre = !panel.bottomAnchored;
        root.shown = false;
        query.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // BEING MOVED BY HAND, and how far out it is while that lasts.
    //
    // Named and shaped exactly like the niagara concept's pair, because both
    // concepts answer the same two calls from Launcher.qml and a forwarder that
    // has to ask which one it is talking to is not a forwarder. It also means
    // the bottom edge, which could only ever open this concept with a jump
    // before, now drags it out the way it always dragged the other one out.
    //
    // While `dragging` is true the panel's reveal is the HAND'S rather than the
    // animation's: the top edge has to be where the finger is or the gesture is
    // a switch with a picture of a drag on it. The animation takes back over at
    // the moment of release, from wherever the drag left it.
    property bool dragging: false
    property real dragProgress: 0

    // How far out the panel is, 0 to 1, from whichever of the two currently has
    // it. ONE expression, read by both the height and the y below, because a
    // drag that moved one of them and left the other on the animation would tear
    // the panel in half.
    readonly property real revealed: root.dragging ? root.dragProgress : rise.value

    function dragTo(fraction: real): void {
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(fraction, 1));
    }

    function dragEnd(open: bool): void {
        root.dragging = false;
        // Hand the smoother the depth the drag ended at, so it carries on from
        // there instead of snapping back to the edge to start the journey again.
        rise.value = root.dragProgress;
        if (open) {
            // ONLY if it is not already up, which matters now that this call
            // arrives from two different gestures. The bottom edge pulling a
            // closed launcher out wants everything show() does; the panel's own
            // put-away push, reversed mid-flight, wants none of it. show()
            // clears the query and the selection, and deciding not to close
            // something must not also throw away what you had typed into it. A
            // launcher that is already shown has `rise` pointed at 1 anyway, so
            // letting go simply walks it back up.
            if (!root.shown)
                root.show();
        } else {
            root.hide();
            // Back into the EDGE, whatever the panel's own geometry would
            // otherwise have picked. hide() chooses the way out from whether the
            // panel was touching the bottom band, which is the right question
            // for a dismissal that came from nowhere in particular; a push has
            // already answered it with a direction, and folding into its own
            // middle from wherever the finger left it would be a jump sideways
            // out of the gesture that was still being made.
            root.collapseToCentre = false;
        }
        // Back to nothing, so the NEXT press starts from the bottom. Left at the
        // last drag's depth, a plain click would hand the animation a starting
        // point half way up and the panel would appear already half open.
        root.dragProgress = 0;
    }

    function accept(): void {
        // ONTO THE CLIPBOARD, which is the only thing an answer can usefully
        // become: it was asked for in the middle of doing something else, and
        // what you want is it in the thing you were doing. Through the same
        // service the clipboard panel writes with, so the answer lands in the
        // history like any other copy rather than as a special case nothing else
        // knows about.
        if (root.answerHolds && root.answer) {
            Clipboard.copy({
                text: root.answer.text
            });
            root.hide();
            return;
        }

        const entry = root.results[root.selected];
        if (entry) {
            Apps.launch(entry);
            // The window being asked for is the one that should end up focused,
            // so the handback is cancelled: restoring the window this was opened
            // from would take focus straight back off the thing just launched.
            root.restoreTo = "";
            Hypr.claimNextWindow();
        }
        root.hide();
    }

    // Wrapping, because getting stuck at the end of a list is a small papercut
    // you feel every time. The view follows, so arrowing past the bottom scrolls
    // rather than moving a selection you can no longer see.
    function move(delta: int): void {
        // ARROWING IS THE HANDOVER, and it happens even when there is nothing to
        // arrow to: pressing Down with an answer up and no applications matching
        // is still somebody saying they did not mean the answer, and leaving the
        // key with it because the list happened to be empty would make the
        // gesture depend on what else was on screen.
        root.answerHolds = false;
        const n = root.results.length;
        if (n <= 0)
            return;
        root.moveTo((root.selected + delta + n) % n);
    }

    // A ROW, CHOSEN OUTRIGHT. Clicking an application is as clear a handover as
    // arrowing onto one, and without this the click would land on `accept` while
    // the answer still held the key and copy a number instead of launching what
    // was pressed.
    function chooseRow(index: int): void {
        root.answerHolds = false;
        root.selected = index;
        root.accept();
    }

    // Absolute, and CLAMPED rather than wrapped: a page down near the end means
    // "the end", not "back to the top".
    function moveTo(index: int): void {
        root.answerHolds = false;
        const n = root.results.length;
        if (n <= 0)
            return;
        root.selected = Math.max(0, Math.min(index, n - 1));
        list.reveal(root.selected);
    }

    onResultsChanged: {
        root.selected = 0;
        list.reset();
    }

    // TWO motions, because they are two different things happening.
    //
    // `grow` is the SIZE: a new set of results is one height to another, chased
    // at the same speed and shape as a menu resizing, because it is the same
    // event. Searching used to snap to the new content, which reads as the panel
    // being replaced rather than as it changing its mind.
    //
    // `rise` is the OPEN: 0 to 1, and what it means geometrically depends on
    // where the panel is. See panel.y.
    Follow {
        id: grow

        target: panel.implicitHeight
        speed: Appearance.anim.resizeSpeed
        epsilon: 0.5
    }

    Follow {
        id: rise

        target: root.shown ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
    }

    // The first size of a new opening is ARRIVED AT, not travelled to: the
    // query was just cleared, so the panel would otherwise animate from
    // whatever the last search narrowed it to while it is also sliding up.
    //
    // Assigned on the change rather than snapped in show(), because snap() reads
    // a target that is a binding on the very thing being waited for, and whether
    // it has re-evaluated yet is the kind of ordering question that works on one
    // machine and not the next. Same trick as MenuPanel.
    property bool unsized: false

    Connections {
        target: panel

        function onImplicitHeightChanged(): void {
            if (root.unsized) {
                root.unsized = false;
                grow.value = panel.implicitHeight;
            }
        }
    }

    // DECLARED FIRST so it sits UNDER the panel. Declaration order is input
    // order in QML: a catch-all that comes last swallows every click meant for
    // the thing it is supposed to be behind.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    // THE WAY BACK IN. Push the panel down and it goes back into the bottom edge
    // it rose out of, which is the shell's one rule for getting rid of anything
    // (DESIGN.md 15): everything goes back into the edge or corner it came out
    // of, by the gesture that brought it out, reversed.
    //
    // It has to be HERE rather than on the bottom edge, because the bottom edge
    // is not reachable once the launcher is up: LaunchEdge is armed only while
    // the launcher is closed, and it clamps its own reported fraction at zero, so
    // it can say "opening" and nothing else. The panel is what is on the screen,
    // so the panel is what you push.
    //
    // AND IT FIXES A SECOND, WORSE THING while it is here. The panel's frame is
    // `padding.large` on all four sides, and the frame, the gap above the
    // separator and the separator itself are bare Items with no MouseArea in
    // them. Every press that landed on any of that fell straight through to the
    // `catcher` declared above and CLOSED the launcher. A cursor hits that frame
    // occasionally; a nine-millimetre fingertip aiming at the search field or at
    // the first row hits it constantly, so the launcher was dismissing itself on
    // the way to being used. Covering the panel with this catches those presses
    // here instead.
    //
    // `onTapped` is deliberately UNWIRED. A tap on the panel's own padding
    // should do nothing at all: it was aimed at something and it missed, and the
    // answer to a miss is to leave the screen alone rather than to guess. A tap
    // OUTSIDE the panel still closes it via the catcher, which is the correct
    // dismissal and the discoverable one.
    Pull {
        id: putAway

        // A SIBLING of the panel wearing the panel's geometry, rather than a
        // child filling it, and that is a correctness question rather than a
        // preference.
        //
        // Pull measures the gesture in its PARENT's coordinates, because the
        // parent is the frame that stays still while the pull item's own
        // top-left is moved about by the thing it is driving (components/Pull.qml
        // and DESIGN.md 15). Make it a child of the panel and the parent IS the
        // thing being dragged: the panel's top edge tracks the finger by design,
        // so a press origin measured against that edge never moves at all, every
        // delta reported is only the frame-to-frame remainder, and the gesture
        // collapses into noise. Out here the parent is this screen-sized item,
        // which does not move, and the pull item's own y is exactly the panel's,
        // so `y + mouse.y` is the finger's position on the screen and nothing
        // else.
        //
        // It still sits UNDER the panel's contents, which is the other half of
        // what the primitive asks for over a panel: declaration order is input
        // order in QML, so declared before the panel it covers the same
        // rectangle and gets only the presses the field, the rows and their own
        // clicks did not want.
        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        // Nothing to push away that is not up. `armed` rather than `enabled`,
        // which is the mechanism the primitive provides for exactly this: an
        // unarmed Pull refuses the press and lets it fall through, where a
        // disabled MouseArea would have to be torn down mid-gesture to become
        // one.
        armed: root.open

        // Straight down, back into the edge it rose from, written as the vector
        // it is. These two numbers are the whole of what says which way this
        // gesture runs.
        dirX: 0
        dirY: 1

        // An EDGE's tolerance, not a corner's. A corner has ninety degrees of
        // "into the screen" to divide between its gestures and an edge has a
        // hundred and eighty, so the same number that is generous in a corner is
        // stingy here.
        angle: Appearance.sizes.pullAngleEdge

        // The panel's own settled height, so one finger-length of panel is one
        // finger-length of travel and the top edge stays under the hand.
        //
        // implicitHeight rather than `height`, and that is not a detail: `height`
        // is `grow.value * revealed`, which this very gesture is collapsing, so
        // the scale would shrink as you pushed and the panel would accelerate
        // away from the finger measuring it. implicitHeight is where the panel
        // SETTLES, which is a fact about the panel rather than about how far
        // through the gesture you are, and it is never zero: it always contains
        // at least the frame and the field.
        travel: panel.implicitHeight

        // TWO INVERSIONS, and both are real rather than bookkeeping.
        //
        // `dragTo` takes how far OPEN the panel is and this gesture reports how
        // far PUT AWAY it is, so the two are one minus each other: a push that
        // has travelled a quarter of the panel's height leaves three quarters of
        // it showing.
        onPulled: fraction => root.dragTo(1 - fraction)

        // And `finished(true)` means the push CARRIED ON in its direction, which
        // for a dismissal means gone, which is `open: false` to dragEnd. Reverse
        // it mid-push and `finished(false)` arrives instead, and the launcher
        // stays up with everything still typed into it.
        onFinished: gone => root.dragEnd(!gone)
    }

    Item {
        id: panel

        // Placed so the SEARCH BAR lands on the screen's centre, not so the
        // panel does: the bar is the fixed point you aim at and the results are
        // whatever happens to be below it, so centring the box would move the
        // bar every time the number of results changed.
        readonly property real barOffset: Appearance.padding.large + field.height / 2

        readonly property real restY: root.height / 2 - barOffset
        // The bottom band's inner edge: where the panel comes from, and where it
        // meets the chassis when it has enough to say.
        readonly property real bandY: root.height - root.inset
        readonly property bool bottomAnchored: restY + grow.value >= bandY - 1

        x: (root.width - width) / 2

        // Growing OUT OF THE BOTTOM EDGE: at rest it is a zero-height sliver in
        // the band, and opening carries it up to where it belongs while it fills
        // out. Closing runs the same path backwards, unless it never reached the
        // band, in which case it folds into its own middle instead.
        y: root.collapseToCentre ? restY + (grow.value - height) / 2 : bandY + (restY - bandY) * root.revealed

        width: root.panelWidth

        // implicitHeight is where the panel is GOING, height is where it IS: the
        // same split the menus use, so a resize can be watched rather than cut
        // to.
        //
        // It stops at the bottom band's inner edge, which is where it TOUCHES
        // the chassis: a long result list grows down until it meets the shell
        // and melts into it, so the panel hangs free in the middle only while it
        // has little to say.
        // Measured from where the panel will SETTLE, never from where it
        // currently is. y travels while it opens, and computing the height from
        // it made the two chase each other: the panel starts its rise down at
        // the band, where the room left below is zero, so the height it was
        // growing towards was zero and it could never leave.
        implicitHeight: Math.min(root.height - restY - root.inset, Appearance.padding.large * 2 + field.height + Appearance.padding.normal * 2 + separator.height + answerRow.height + (answerRow.visible ? Appearance.padding.normal : 0) + list.needed)

        height: grow.value * root.revealed

        visible: height > 0

        Item {
            anchors.fill: parent
            clip: true

            Column {
                id: layout

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: root.panelWidth - Appearance.padding.large * 2
                spacing: Appearance.padding.normal

                Item {
                    id: field

                    width: parent.width
                    implicitHeight: Math.max(searchGlyph.implicitHeight, query.implicitHeight)
                    height: implicitHeight

                    // In the SAME COLUMN as a row's icon, and the same width, so
                    // the query and the results it produces share one left edge
                    // instead of sitting a few pixels apart for no reason.
                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        width: Appearance.sizes.launcherIcon
                        size: Appearance.font.size.normal
                        name: "search"
                        color: Appearance.colour.textFaint
                    }

                    TextInput {
                        id: query

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.normal
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        // ONE handler testing the key, rather than the named
                        // Keys.onUpPressed / onDownPressed signals. Those never
                        // fired here while onTabPressed and onEscapePressed on
                        // the same item did, so the arrows moved nothing at all
                        // and the list could only be walked with Tab. Testing
                        // the key is also the only form that can ACCEPT the
                        // event, which stops the text field treating an arrow as
                        // a request to move its cursor.
                        //
                        // Page and Home/End earn their place on a list this
                        // long: 133 entries is a lot of Tab.
                        Keys.onPressed: event => {
                            const page = Math.max(1, Math.floor(list.height / root.rowPitch) - 1);

                            switch (event.key) {
                            case Qt.Key_Escape:
                                root.hide();
                                break;
                            case Qt.Key_Return:
                            case Qt.Key_Enter:
                                root.accept();
                                break;
                            case Qt.Key_Down:
                            case Qt.Key_Tab:
                                root.move(1);
                                break;
                            case Qt.Key_Up:
                            case Qt.Key_Backtab:
                                root.move(-1);
                                break;
                            case Qt.Key_PageDown:
                                root.moveTo(root.selected + page);
                                break;
                            case Qt.Key_PageUp:
                                root.moveTo(root.selected - page);
                                break;
                            case Qt.Key_Home:
                                root.moveTo(0);
                                break;
                            case Qt.Key_End:
                                root.moveTo(root.results.length - 1);
                                break;
                            default:
                                return;
                            }
                            event.accepted = true;
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text
                            // Short, because the field is set a tier above body
                            // and the old sentence ran off the end of it. A
                            // search box does not need to explain itself.
                            text: "Search"
                            font.pixelSize: Appearance.font.size.normal
                            color: Appearance.colour.textFaint
                        }
                    }
                }

                Separator {
                    id: separator

                    width: parent.width
                }

                AnswerRow {
                    id: answerRow

                    width: parent.width
                    iconSize: Appearance.sizes.launcherIcon
                    rowHeight: root.rowPitch
                    labelSize: Appearance.font.size.normal

                    result: root.answer
                    expression: query.text
                    holds: root.answerHolds

                    onCopied: {
                        root.answerHolds = true;
                        root.accept();
                    }
                }

                // A LIST VIEW, not a Column. Nothing is truncated any more, so
                // with an empty query this is every application installed; a
                // Column would build a row for every one of them on every
                // keystroke. This builds only what is on screen, and glides: see
                // GlideList for what Qt's own wheel handling does instead.
                GlideList {
                    id: list

                    // What the list would need if nothing stopped it, FROM THE
                    // COUNT rather than from its own contentHeight: see
                    // root.rowPitch for why measuring itself was a cycle. Not
                    // capped here either. The panel's limit is the bottom band,
                    // and reaching it is not truncation, it is the launcher
                    // rejoining the chassis.
                    readonly property real needed: Math.max(1, root.results.length) * root.rowPitch

                    width: parent.width
                    height: Math.max(0, panel.height - y - Appearance.padding.large)
                    clip: true

                    // A ScriptModel, so a keystroke that narrows the results
                    // keeps the delegates of everything that survived it rather
                    // than tearing the whole list down and building it again.
                    model: ScriptModel {
                        values: root.results
                    }

                    // Recycle rather than destroy. Scrolling a few hundred
                    // entries then becomes a fixed number of rows being handed
                    // new content, which is what keeps a long list as cheap to
                    // scroll as a short one.
                    reuseItems: true
                    cacheBuffer: root.rowPitch * 4

                    delegate: MenuRow {
                        required property var modelData
                        required property int index

                        width: list.width
                        iconSize: Appearance.sizes.launcherIcon
                        rowHeight: root.rowPitch
                        // The BODY size, not the display size. The field above
                        // is the one thing here set large; a hundred rows all
                        // shouting is not hierarchy, it is just loud.
                        labelSize: Appearance.font.size.normal
                        inlineDetail: true
                        // The entry's own icon, resolved out of the icon theme,
                        // with the generic mark only as a fallback for entries
                        // that name none.
                        iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        icon: "apps"
                        label: modelData.name ?? ""
                        detail: modelData.genericName || modelData.comment || ""
                        // Never while the answer above still owns Return: two
                        // rows drawn as the selection is two answers to what
                        // Enter does, and only one of them is true.
                        selected: index === root.selected && !root.answerHolds

                        onActivated: root.chooseRow(index)
                    }

                    StyledText {
                        id: empty

                        // Never under an answer. A sum that came out is a match,
                        // and a panel showing 14 over the words "nothing
                        // matches" is disagreeing with itself.
                        visible: !root.results.length && !root.answer
                        text: query.text ? "nothing matches" : "no applications found"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
