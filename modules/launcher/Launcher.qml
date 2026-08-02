pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// The launcher.
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

    // One row's pitch, computed HERE and handed to the rows, rather than read
    // back off the list once it has laid itself out.
    //
    // That readback was a cycle: the panel's height came from the list's
    // contentHeight, and the list's height came from the panel. It bootstrapped
    // only because cacheBuffer happens to build a few delegates even in a
    // zero-height view, which is an accident, not a mechanism. Knowing the pitch
    // up front means the panel's size follows from the RESULT COUNT and the list
    // never has to be measured at all.
    readonly property real rowPitch: Math.max(Appearance.sizes.rowHeight, Appearance.sizes.launcherIcon + Appearance.padding.normal * 2)

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
    property string restoreTo: ""

    function show(): void {
        root.restoreTo = Hypr.focusedAddress;
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
        Hypr.focusAddress(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    function accept(): void {
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
        const n = root.results.length;
        if (n <= 0)
            return;
        root.moveTo((root.selected + delta + n) % n);
    }

    // Absolute, and CLAMPED rather than wrapped: a page down near the end means
    // "the end", not "back to the top".
    function moveTo(index: int): void {
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
        y: root.collapseToCentre ? restY + (grow.value - height) / 2 : bandY + (restY - bandY) * rise.value

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
        implicitHeight: Math.min(root.height - restY - root.inset, Appearance.padding.large * 2 + field.height + Appearance.padding.normal * 2 + separator.height + list.needed)

        height: grow.value * rise.value

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

                    Icon {
                        id: searchGlyph

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
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
                        font.pixelSize: Appearance.font.size.large
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
                            // Short, because the field is set in the large
                            // size now and the old sentence ran off the end of
                            // it. A search box does not need to explain itself.
                            text: "Search"
                            font.pixelSize: Appearance.font.size.large
                            color: Appearance.colour.textFaint
                        }
                    }
                }

                Separator {
                    id: separator

                    width: parent.width
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
                        // The entry's own icon, resolved out of the icon theme,
                        // with the generic mark only as a fallback for entries
                        // that name none.
                        iconSource: modelData.icon ? Quickshell.iconPath(modelData.icon, true) : ""
                        icon: "apps"
                        label: modelData.name ?? ""
                        detail: modelData.genericName || modelData.comment || ""
                        selected: index === root.selected

                        onActivated: {
                            root.selected = index;
                            root.accept();
                        }
                    }

                    StyledText {
                        id: empty

                        visible: !root.results.length
                        text: query.text ? "nothing matches" : "no applications found"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }
                }
            }
        }
    }
}
