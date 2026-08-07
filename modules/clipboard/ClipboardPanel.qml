pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// WHAT YOU COPIED, and getting it back.
//
// Built as the launcher's twin rather than as a new idiom: it rises out of the
// bottom band, it takes the keyboard outright while it is up, a click anywhere
// off it puts it away, and a push back down into the band it came from does the
// same. Two lists reached by one gesture should not be two different objects,
// and the one thing that genuinely differs is what a row is made of.
//
// THE SEARCH IS NOT ALWAYS THERE, which is the one place this deliberately
// parts company with the launcher. A launcher has nothing to show until you have
// typed, so its field is the whole interface and holding the keyboard is what it
// is for. A clipboard's list is the answer the moment it opens: the thing you
// want is nearly always the first or second row, and a field with a caret in it
// would make every one of those cases begin by pressing Escape. So the list has
// the keys, `/` asks for the field, and Escape hands them back rather than
// closing. That is the vim bargain and it is why the letters stay free: `p`
// keeps a row and `x` throws one away without a modifier anywhere.
Item {
    id: root

    // Where the chassis's inner edge is, so the panel is centred in the space
    // the desktop actually has rather than in the screen.
    required property real originX
    required property real inset

    readonly property bool open: root.shown
    property bool shown: false

    // WHICH LIST. The clipboard proper, and the transcription clipboard: what
    // was copied, and what was said. Two histories of the same act, which is
    // "something I want back", so they are one panel and one gesture rather
    // than two.
    //
    // The tabs differ in what ACCEPTING a row means, and only in that. Tab 0
    // puts the entry on the clipboard, ready for a paste. Tab 1 loads it into
    // the slot SUPER+SHIFT+R types from, ready for that key. Both leave the
    // thing you picked one keystroke from the window you were in, which is why
    // neither of them types anything itself.
    property int tab: 0
    readonly property var tabs: ["Clipboard", "Transcription"]

    readonly property bool speech: root.tab === 1

    property bool searching: false
    property int selected: 0
    // Which row the POINTER is over, which is a different question from which
    // row the keyboard is on. NiagaraLauncher's note: hover cannot move the
    // selection, because the pointer is not the only thing that moves. Type a
    // letter and the list under a perfectly still cursor is a different list.
    property int hovered: -1

    // WHICH ENTRY THE FULL VIEW IS SHOWING, held separately from `selected`.
    //
    // Not derived from the selection, because the two stop agreeing the moment
    // the list changes underneath: something copied while you are reading pushes
    // a new row to the top and moves every index down one, and a view bound to
    // an index would silently start showing its neighbour. An entry is a thing;
    // an index is a position, and positions here are not stable.
    //
    // Null is the whole of "not reading anything", so there is no second flag to
    // keep in step with it.
    property var reading: null

    readonly property bool expanded: !!root.reading

    // What had the keyboard before this took it, so it can have it back.
    //
    // This matters more here than it does for the launcher, and in the opposite
    // direction: a launcher's whole purpose is that something NEW ends up
    // focused, so it cancels the handback and claims the window it opened. A
    // clipboard is the other way round. You are putting something back on the
    // clipboard in order to paste it into the window you were already in, so
    // that window must have the keyboard again by the time this is gone, and
    // nothing else may claim it.
    property string restoreTo: ""

    readonly property real panelWidth: Math.min(Appearance.sizes.clipboardWidth, root.width - root.originX - root.inset * 2)

    readonly property var blobs: panel.height <= 0 ? [] : [
        {
            x: panel.x,
            y: panel.y,
            w: panel.width,
            h: panel.height,
            radius: Appearance.rounding.large
        }
    ]

    readonly property Item maskItem: catcher

    // WHAT THE LIST IS SHOWING. The tab decides which question is asked; the
    // query narrows the answer. Both sources are searched the same way, because
    // Dictation.search defers to Clipboard's own matcher rather than scoring
    // matches a second way.
    readonly property var results: root.speech ? Dictation.search(query.text) : Clipboard.search(query.text)

    readonly property var entry: root.results[root.selected] ?? null

    // ------------------------------------------------------------------

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedAddress;
        root.shown = true;
        root.selected = 0;
        root.hovered = -1;
        // ALWAYS ON THE LIST. The full view is a place you went, not a place you
        // live: reopening onto whatever was last read would be the panel
        // answering a question nobody asked this time.
        root.reading = null;
        root.stopSearch();
        list.reset();
        // DEFERRED: the surface only asks the compositor for the keyboard once
        // `open` has propagated to ShellWindow's keyboardFocus, and focus taken
        // before that lands on an item that receives nothing.
        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        root.reading = null;
        root.stopSearch();
        keys.focus = false;
        // The window you were in gets the keyboard back, because pasting is what
        // happens next and it has to happen there. No claimNextWindow: nothing
        // is being opened.
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // ON BOTH TABS. It used to refuse on tab 1 because there was nothing behind
    // it to search; now there is, and a dictation history is the list that needs
    // it MOST. A paragraph you said an hour ago is not something you find by
    // scrolling, and it is the one kind of entry you can reliably remember a
    // word from.
    function startSearch(): void {
        root.searching = true;
        Qt.callLater(query.forceActiveFocus);
    }

    // BACK TO THE LIST, and the query goes with it. A field left holding text it
    // is no longer showing would make the next `/` open onto somebody else's
    // search, and the list under it would already be narrowed by a word nothing
    // on screen is displaying.
    function stopSearch(): void {
        root.searching = false;
        query.text = "";
        if (root.shown)
            Qt.callLater(keys.forceActiveFocus);
    }

    function move(delta: int): void {
        const n = root.results.length;
        if (n <= 0)
            return;
        // Wrapping, like the launcher's: getting stuck at the end of a list is a
        // small papercut with no argument for it.
        root.moveTo((root.selected + delta + n) % n);
    }

    function moveTo(index: int): void {
        const n = root.results.length;
        if (n <= 0)
            return;
        root.selected = Math.max(0, Math.min(index, n - 1));
        list.reveal(root.selected);
    }

    // INTO A THING. Reads the entry, not the index; see `reading`.
    // Transcriptions expand too, and are the better argument for the full view
    // than anything on the clipboard: a row shows one line and a dictated
    // paragraph is twenty, so the list can only ever show you enough to guess
    // with. The tab test that used to be here was guarding an empty tab.
    function expand(): void {
        const e = root.entry;
        if (!e)
            return;
        root.reading = e;
    }

    function collapse(): void {
        if (!root.expanded)
            return;
        root.reading = null;
        // The keyboard comes back to the list rather than staying wherever the
        // full view left it, so the arrows work immediately on return. Deferred
        // for the reason every focus call in this file is: the item has to be
        // there to take it.
        if (root.shown && !root.searching)
            Qt.callLater(keys.forceActiveFocus);
    }

    // TAKE IT, from either page, and always the thing being looked at. On the
    // list that is the selected row; in the full view it is the entry on screen,
    // which is not necessarily the same row any more.
    //
    // WHAT "TAKE" MEANS IS THE TAB'S ONE DIFFERENCE. A clipboard entry goes on
    // the clipboard, ready for a paste. A transcription goes into the slot
    // SUPER+SHIFT+R types from, ready for that key. Neither types anything here:
    // this runs with the panel still up and the keyboard held by the shell, so
    // anything typed now would land in the panel or in whatever catches focus on
    // the way out. Both leave the thing you picked one keystroke away, in the
    // window you were already in.
    function accept(): void {
        const e = root.expanded ? root.reading : root.entry;
        if (e) {
            if (root.speech)
                Dictation.use(e);
            else
                Clipboard.copy(e);
        }
        root.hide();
    }

    // KEEP IT, AND KEEP LOOKING AT IT.
    //
    // Pinning re-sorts the list, because pinned entries are shown first, so the
    // row that was under the cursor is now somewhere else and the index that was
    // selected belongs to a different entry. Left alone, pressing `p` moves the
    // highlight onto a neighbour, which reads as the key having done something
    // to the wrong row. So the ENTRY is followed rather than the index: the
    // selection lands wherever the thing you just kept ended up.
    function pinCurrent(): void {
        const e = root.entry;
        // NOTHING PINS A TRANSCRIPTION. That list is time-ordered and the daemon
        // caps it, so a pin would be a promise this shell cannot keep: the entry
        // would still fall off the end. Silently doing nothing is right here,
        // because `p` is a list key and the list is still a list.
        if (!e || root.speech)
            return;
        Clipboard.setPinned(e, !e.pinned);
        root.follow(e.id);
    }

    function follow(id: string): void {
        const at = root.results.findIndex(e => e.id === id);
        if (at < 0)
            return;
        root.selected = at;
        list.reveal(at);
    }

    function discardCurrent(): void {
        const e = root.entry;
        if (!e)
            return;
        if (root.speech)
            Dictation.drop(e);
        else
            Clipboard.remove(e);
        // Held where it was rather than reset, so throwing four things away in a
        // row is four presses in one place. Clamped, because the list is one
        // shorter than the index was chosen against.
        root.selected = Math.max(0, Math.min(root.selected, root.results.length - 1));
    }

    function setTab(index: int): void {
        if (index === root.tab)
            return;
        root.tab = Math.max(0, Math.min(index, root.tabs.length - 1));
        // The full view belongs to the list it was opened from, so changing
        // which list is showing closes it rather than leaving it over a tab it
        // has nothing to do with.
        root.reading = null;
        root.stopSearch();
        root.selected = 0;
        list.reset();
    }

    // The keys that mean the same thing whichever half of the panel is holding
    // them, so the list's handler and the field's handler cannot drift apart.
    // Returns whether it took the key.
    function commonKey(event: var): bool {
        const page = Math.max(1, Math.floor(list.height / Math.max(1, list.pitch)) - 1);

        switch (event.key) {
        case Qt.Key_Return:
        case Qt.Key_Enter:
            root.accept();
            return true;
        // RIGHT GOES IN, LEFT COMES BACK, on every page and on both halves of
        // the panel, which is the whole reason the tab strip lost the arrows: a
        // direction that meant "next tab" here and "open this" there would be
        // the same motion asking two questions depending on where you happened
        // to be looking. Tab still changes the tab, and it is the key with the
        // control's own name on it.
        case Qt.Key_Right:
            root.expand();
            return true;
        case Qt.Key_Left:
            root.collapse();
            return true;
        // THE FULL VIEW SCROLLS ITSELF. Up and down belong to the list, and
        // handing them to it while a document is open would walk the selection
        // behind the page you are reading, so the reader keeps them.
        case Qt.Key_Down:
            if (root.expanded)
                return false;
            root.move(1);
            return true;
        case Qt.Key_Up:
            if (root.expanded)
                return false;
            root.move(-1);
            return true;
        case Qt.Key_PageDown:
            root.moveTo(root.selected + page);
            return true;
        case Qt.Key_PageUp:
            root.moveTo(root.selected - page);
            return true;
        // TAB CHANGES THE TAB, which is the one key this shell's other panels
        // give to moving down a list. Here there is a tab strip on screen with
        // the word on it, and no other panel has one; a key that visibly matches
        // a control the user is looking at beats consistency with a list that is
        // already walked by the arrows and by j and k.
        case Qt.Key_Tab:
            root.setTab((root.tab + 1) % root.tabs.length);
            return true;
        case Qt.Key_Backtab:
            root.setTab((root.tab - 1 + root.tabs.length) % root.tabs.length);
            return true;
        }
        return false;
    }

    // ------------------------------------------------------------------

    // DECLARED FIRST so it sits UNDER the panel. Declaration order is input
    // order in QML and there is no z anywhere in this shell: a catch-all that
    // comes last swallows every click meant for the thing it is behind.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open
        onClicked: root.hide()
    }

    // THE KEYBOARD, on an item of its own rather than on the panel. The panel is
    // invisible until the reveal has moved off zero and an invisible item cannot
    // hold focus, so focusing it on the way up would silently do nothing and the
    // first Escape would go to the desktop. This has no size and is always
    // visible, so it is always focusable. The cheatsheet's, unchanged.
    Item {
        id: keys

        // ONE handler testing the key, never the named Keys.onUpPressed signals.
        // Those were measured not firing on items reached this way in three
        // separate files here, and testing the key is also the only form that
        // can accept the event.
        Keys.onPressed: event => {
            if (root.commonKey(event)) {
                event.accepted = true;
                return;
            }

            switch (event.key) {
            // ESCAPE COMES BACK BEFORE IT CLOSES, which is the same bargain the
            // search field makes one layer along: two states, two presses, and
            // no single key that can lose more than one of them at a time.
            case Qt.Key_Escape:
                if (root.expanded)
                    root.collapse();
                else
                    root.hide();
                break;
            // THE WAY IN TO SEARCHING, and the reason the letters below are free
            // to mean anything at all.
            case Qt.Key_Slash:
                root.startSearch();
                break;
            case Qt.Key_J:
                if (!root.expanded)
                    root.move(1);
                break;
            case Qt.Key_K:
                if (!root.expanded)
                    root.move(-1);
                break;
            // L and H, the other half of the vim pair the arrows already answer.
            case Qt.Key_L:
                root.expand();
                break;
            case Qt.Key_H:
                root.collapse();
                break;
            case Qt.Key_Home:
                root.moveTo(0);
                break;
            case Qt.Key_End:
                root.moveTo(root.results.length - 1);
                break;
            case Qt.Key_P:
                root.pinCurrent();
                break;
            case Qt.Key_X:
            case Qt.Key_Delete:
                root.discardCurrent();
                break;
            default:
                return;
            }
            event.accepted = true;
        }
    }

    // THE WAY BACK: a push down into the band it came out of, which is the
    // summoning gesture reversed.
    //
    // A SIBLING of the panel wearing the panel's rectangle, and declared BEFORE
    // it. Pull keeps its press anchor in its PARENT's frame, which survives this
    // item moving inside a still parent and does not survive the parent moving,
    // and moving the panel is this gesture's whole job. Declared first so it only
    // sees presses the rows and the field did not take, and so a press on the
    // panel's own padding is a pull rather than falling through to the catcher
    // and dismissing the thing under the finger.
    Pull {
        id: putAway

        x: panel.x
        y: panel.y
        width: panel.width
        height: panel.height

        armed: root.open

        dirX: 0
        dirY: 1
        angle: Appearance.sizes.pullAngleEdge

        // The SETTLED height, never the live one: a travel that shrank as the
        // panel was pushed would make the panel accelerate away from the finger.
        travel: panel.fullHeight

        onPulled: fraction => root.pushTo(fraction)
        onFinished: gone => root.pushEnd(gone)
        // onTapped is deliberately unwired. A tap on the frame missed something
        // and should do nothing; dismissing belongs to the catcher.
    }

    // How far the push has taken it, as a fraction, and the one subtraction made
    // here so `revealed` below goes on meaning what it meant when the reveal was
    // the only thing writing it.
    property bool pushing: false
    property real pushOut: 0

    readonly property real revealed: root.pushing ? root.pushOut : rise.value

    function pushTo(fraction: real): void {
        if (!root.open)
            return;
        root.pushing = true;
        root.pushOut = 1 - Math.max(0, Math.min(fraction, 1));
    }

    function pushEnd(gone: bool): void {
        // A release always arrives and a push does not always precede it.
        if (!root.pushing)
            return;
        root.pushing = false;
        // Hand the smoother the depth the hand let go at, so it carries on from
        // there rather than starting the journey again.
        rise.value = root.pushOut;
        root.pushOut = 0;
        if (gone)
            root.hide();
    }

    // WHICH PAGE, as a fraction rather than as an index, so the strip can be
    // anywhere between the two and a gesture can be halfway through changing its
    // mind. 0 is the list, 1 is the full view.
    Follow {
        id: turn

        speed: Appearance.anim.revealSpeed
        target: root.expanded ? 1 : 0
        epsilon: 0.005
    }

    Follow {
        id: rise

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        // A 0-to-1 fraction, not a pixel count: the default quarter-pixel
        // epsilon would leave a closed panel permanently a quarter open, and
        // every `if (open)` downstream silently true.
        epsilon: 0.005
    }

    Item {
        id: panel

        readonly property real bandY: root.height - root.inset
        readonly property real fullHeight: root.height - root.inset * 2

        x: root.originX + (root.width - root.originX - root.panelWidth) / 2
        width: root.panelWidth

        // Grows out of the bottom edge: at rest a zero-height sliver in the
        // band, and opening carries it up to where it belongs.
        height: fullHeight * root.revealed
        y: bandY - height

        visible: height > 0

        // Clipped, so the reveal is a wipe rather than the contents sliding
        // around inside a box that is the wrong size for them.
        Item {
            id: viewport

            anchors.fill: parent
            clip: true

            // TWO PAGES ON ONE STRIP, slid rather than swapped.
            //
            // A Loader that replaced one with the other would be a cut, and a
            // cut cannot say which way you went: arriving and leaving would look
            // identical, and the direction is the whole vocabulary here (right
            // goes in, left comes back, on the arrows and on the fingers alike).
            // On a strip the motion IS the answer, and a gesture can be halfway
            // through it and change its mind, which a cut also cannot offer.
            Item {
                id: pages

                width: viewport.width * 2
                height: viewport.height
                x: -turn.value * viewport.width

                Item {
                    id: listPage

                    width: viewport.width
                    height: viewport.height

            Item {
                id: header

                x: Appearance.padding.large
                y: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
                height: Math.max(tabStrip.height, field.height)

                Segments {
                    id: tabStrip

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    options: root.tabs
                    current: root.tab
                    onPicked: index => root.setTab(index)
                }

                // THE SEARCH, which is not here until it is asked for.
                //
                // It takes the header's right-hand side rather than replacing
                // the tabs, so the thing you were looking at does not move when
                // you start typing: a control that jumps as the caret arrives
                // makes you re-find the list you were already reading.
                Item {
                    id: field

                    anchors.right: parent.right
                    anchors.left: tabStrip.right
                    anchors.leftMargin: Appearance.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    height: Math.round(Appearance.font.size.small * 4 / 3) + Appearance.padding.small * 2

                    opacity: root.searching ? 1 : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    G2Rect {
                        anchors.fill: parent
                        radius: height / 2
                        color: Appearance.colour.fill
                    }

                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        name: "search"
                        size: Appearance.font.iconSize
                        color: Appearance.colour.textFaint
                    }

                    TextInput {
                        id: query

                        anchors.left: searchGlyph.right
                        anchors.leftMargin: Appearance.padding.small
                        anchors.right: parent.right
                        anchors.rightMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.small
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text
                        selectionColor: Appearance.colour.accent
                        selectedTextColor: Appearance.colour.accentText
                        clip: true

                        Keys.onPressed: event => {
                            if (root.commonKey(event)) {
                                event.accepted = true;
                                return;
                            }

                            // ESCAPE GOES BACK TO THE LIST, and does not close.
                            // Two states, two presses: the first undoes the `/`,
                            // the second closes the panel. A single Escape that
                            // did both would make an abandoned search cost the
                            // whole panel.
                            if (event.key === Qt.Key_Escape) {
                                root.stopSearch();
                                event.accepted = true;
                            }

                            // Everything else, including the arrows this handler
                            // did not claim, falls through to the field: Left and
                            // Right are the caret's while there is a caret, and
                            // the tabs are still reachable on Tab.
                        }

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !query.text
                            text: root.speech ? "Search what you said" : "Search what you copied"
                            color: Appearance.colour.textGhost
                        }
                    }
                }

                // THE PROMPT, where the field will be. It is the only place the
                // one non-obvious key in this panel can be said, and it costs a
                // line of the quietest colour there is.
                StyledText {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !root.searching
                    text: "/  to search"
                    color: Appearance.colour.textGhost
                }
            }

            Separator {
                id: rule

                anchors.top: header.bottom
                anchors.topMargin: Appearance.padding.normal
                x: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
            }

            GlideList {
                id: list

                // The row pitch, computed HERE and handed down rather than read
                // back off the list's own contentHeight, which is a binding cycle
                // (panel height <- contentHeight <- list height <- panel height).
                // Rows here are not uniform: a picture is taller than a line of
                // text. So this is the pitch `reveal` and the page keys reason
                // with, and it is the smallest a row can be, which keeps a page
                // conservative rather than wrong.
                readonly property real pitch: Appearance.sizes.rowHeight + Appearance.padding.small

                anchors.top: rule.bottom
                anchors.topMargin: Appearance.padding.normal
                x: Appearance.padding.large
                width: parent.width - Appearance.padding.large * 2
                height: Math.max(0, panel.fullHeight - y - Appearance.padding.large)
                clip: true

                // A ScriptModel, so a keystroke that narrows the results keeps
                // the delegates of everything that survived it rather than
                // rebuilding the whole list under the cursor.
                model: ScriptModel {
                    values: root.results
                }

                // FALSE, because the rows animate. A recycled delegate gets new
                // content while its removal is still running and draws two
                // entries on one line.
                reuseItems: false
                cacheBuffer: list.pitch * 6

                // `index` is NOT redeclared here. ClipRow requires one, and a
                // view injects a required property called `index` into the
                // delegate root itself; declaring a second one shadows the
                // injected value and leaves ClipRow's own required property
                // never initialised, which is a delegate that cannot be built at
                // all rather than one that merely numbers its rows wrong.
                delegate: ClipRow {
                    required property var modelData

                    width: list.width
                    entry: modelData
                    selected: index === root.selected

                    onActivated: {
                        root.selected = index;
                        root.accept();
                    }
                    // Routed by tab for the same reason accept() is: the row is
                    // the same row, and what these mean to it is not.
                    onPinned: if (!root.speech)
                        Clipboard.setPinned(modelData, !modelData.pinned)
                    onDiscarded: {
                        if (root.speech)
                            Dictation.drop(modelData);
                        else
                            Clipboard.remove(modelData);
                    }
                    // The selection follows the row that was thrown open, so
                    // coming back leaves the keyboard on the thing you were just
                    // reading rather than wherever it was before you reached for
                    // the mouse.
                    onExpanded: {
                        root.selected = index;
                        root.reading = modelData;
                    }
                    pointed: index === root.hovered

                    onEntered: root.hovered = index
                    // DELIBERATELY NOT CLEARED HERE. A row that grows when it is
                    // pointed at reflows the list under a pointer that has not
                    // moved, so it can drop its own hover, shrink, get it back
                    // and strobe. Letting go is therefore ANOTHER row's job (the
                    // onEntered above) or the pointer's, by leaving the list
                    // (offList below). Neither can be caused by this row
                    // resizing, so the loop cannot close. See ClipRow.pointed.
                    onExited: {}
                }

                // THE OTHER WAY THE LATCH LETS GO. A row hands the pointer to
                // whichever row takes it next, and this is what happens when
                // nothing does because the pointer left the list altogether.
                // Passive, so it never takes an event off a row or the wheel.
                HoverHandler {
                    id: offList

                    onHoveredChanged: if (!offList.hovered)
                        root.hovered = -1
                }

                remove: Transition {
                    NumberAnimation {
                        property: "opacity"
                        to: 0
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutCubic
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        property: "y"
                        duration: Appearance.anim.normal
                        easing.type: Easing.OutCubic
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    visible: !root.results.length
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colour.textFaint
                    // FOUR DIFFERENT EMPTIES, because they are four different
                    // facts and only one of them is a bug. A search that matched
                    // nothing, a history nothing has been put in yet, and a
                    // dictation daemon that is not running at all: telling the
                    // last one apart matters most, since it is the only one you
                    // can do something about.
                    text: {
                        if (query.text)
                            return "Nothing matches.";
                        if (!root.speech)
                            return "Nothing has been copied yet.";
                        if (!Dictation.present)
                            return "The dictation daemon is not running.\nStart it with  voice up";
                        return "Nothing has been dictated yet.\nSUPER + R starts.";
                    }
                }
            }

            // TWO FINGERS ACROSS GO IN AND COME BACK.
            //
            // This used to change the TAB, and the full view took the gesture off
            // it: a horizontal swipe now means the same thing everywhere in this
            // panel (right goes into a thing, left comes back out), on a row's
            // drag, on the arrow keys and here. A tab strip is a control you can
            // see and press, and it kept the key that names it; a hidden
            // horizontal gesture that ALSO changed tabs would have made the same
            // motion mean two different things depending on which page you were
            // looking at.
            //
            // Declared AFTER the list, which is what puts it on top for a wheel:
            // a wheel goes to the topmost item under the pointer and stops at the
            // first thing that accepts. That is the only way to see the event
            // before GlideList, which accepts every scroll it is given. It hands
            // back everything that is not predominantly horizontal, so the list
            // scrolls exactly as it always did and only the axis it has no use
            // for is taken.
            //
            // It handles no buttons, so nothing about clicking a row changes.
            WheelHandler {
                id: pager

                property bool spent: false

                onWheel: event => {
                    // A MOUSE WHEEL IS NEVER A SWIPE. It reports an angle and no
                    // pixels, it has one axis, and there is no motion in it to
                    // track. Handed straight back so it falls through to the
                    // list, where a notch has always meant scroll.
                    if (event.pixelDelta.x === 0 && event.pixelDelta.y === 0) {
                        event.accepted = false;
                        return;
                    }

                    if (Math.abs(event.pixelDelta.x) <= Math.abs(event.pixelDelta.y)) {
                        event.accepted = false;
                        return;
                    }

                    event.accepted = true;
                    swipe.feed(event);
                }
            }

            ScrollGesture {
                id: swipe

                armed: root.open

                onBegan: pager.spent = false

                onMoved: (dx, dy) => {
                    // ONE CROSSING PER GESTURE. The primitive hands out the TOTAL
                    // travel, so without a latch a long swipe would keep clearing
                    // the threshold and toggle the page on every event after the
                    // first.
                    if (pager.spent)
                        return;
                    const step = Math.max(1, root.panelWidth * Appearance.sizes.pullTravel);
                    if (Math.abs(dx) < step)
                        return;
                    pager.spent = true;
                    // Natural scrolling is already resolved by the primitive, so
                    // this reads as the content following the fingers: push the
                    // page left and what was off the right edge arrives.
                    if (dx < 0)
                        root.expand();
                    else
                        root.collapse();
                }
            }
                }

                // THE FULL VIEW, parked off the right edge until it is asked for.
                //
                // Built rather than loaded on demand, and it costs nothing to do
                // so: it holds one entry, the entry is null until something is
                // opened, and every heavy thing inside it (the picture, the
                // highlighted lines) is bound to that entry and so builds
                // nothing while there is none. A Loader here would buy the same
                // emptiness and pay for it with a rebuild on every open, which
                // is the frame the slide is happening in.
                ClipDetail {
                    id: detail

                    x: listPage.width
                    width: viewport.width
                    height: viewport.height

                    entry: root.reading

                    onBack: root.collapse()
                    onAccepted: root.accept()
                }
            }
        }
    }
}
