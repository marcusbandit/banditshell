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

    readonly property real panelWidth: Appearance.sizes.launcherWidth

    // The whole screen while it is open, so a click anywhere lands on the shell
    // and can dismiss it. The panel alone would let every click outside fall
    // through to whatever is behind, which is how a launcher ends up typing into
    // the window you were trying to leave.
    readonly property Item maskItem: catcher

    readonly property var results: Apps.search(query.text)
    property int selected: 0

    // The blob the chassis melts in.
    readonly property var blobs: reveal.value <= 0 ? [] : [
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
        root.shown = true;
        query.text = "";
        root.selected = 0;
        reveal.target = 1;
        // DEFERRED. Focus is only worth taking once the window has actually
        // asked the compositor for the keyboard, and that follows from `shown`
        // in the same pass this is running in.
        Qt.callLater(query.forceActiveFocus);
    }

    function hide(): void {
        root.shown = false;
        reveal.target = 0;
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
        if (entry)
            Apps.launch(entry);
        root.hide();
    }

    // Wrapping, because getting stuck at the end of a list is a small papercut
    // you feel every time. The view follows, so arrowing past the bottom scrolls
    // rather than moving a selection you can no longer see.
    function move(delta: int): void {
        const n = root.results.length;
        if (n <= 0)
            return;
        root.selected = (root.selected + delta + n) % n;
        list.reveal(root.selected);
    }

    onResultsChanged: {
        root.selected = 0;
        list.reset();
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        epsilon: 0.005
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

        x: (root.width - width) / 2
        y: root.height / 2 - barOffset

        width: root.panelWidth
        // Unfurls DOWNWARDS from the bar's line. Height is what the reveal
        // animates, so opening reads as the panel opening out of the bar rather
        // than as a box arriving from somewhere.
        height: fullHeight * reveal.value

        // Stops at the bottom band's inner edge, which is where it TOUCHES the
        // chassis: a long result list grows down until it meets the shell and
        // melts into it, so the panel is hanging in the middle only while it has
        // little to say.
        readonly property real fullHeight: Math.min(root.height - y - root.inset, Appearance.padding.large * 2 + field.height + Appearance.padding.normal * 2 + separator.height + list.fullHeight)

        visible: reveal.value > 0

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

                        Keys.onEscapePressed: root.hide()
                        Keys.onReturnPressed: root.accept()
                        Keys.onEnterPressed: root.accept()
                        Keys.onDownPressed: root.move(1)
                        Keys.onUpPressed: root.move(-1)
                        // Tab moves too, because half the world reaches for it.
                        Keys.onTabPressed: root.move(1)
                        Keys.onBacktabPressed: root.move(-1)

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

                    // What the panel would need. Not capped here at all: the
                    // panel's own limit is the bottom band, and running into it
                    // is not a failure, it is the launcher REJOINING the
                    // chassis. A short result set still gets a short panel.
                    readonly property real fullHeight: root.results.length ? contentHeight : empty.implicitHeight

                    width: parent.width
                    height: Math.max(0, panel.height - y - Appearance.padding.large)
                    clip: true

                    model: root.results
                    cacheBuffer: Appearance.sizes.rowHeight * 4

                    delegate: MenuRow {
                        required property var modelData
                        required property int index

                        width: list.width
                        iconSize: Appearance.sizes.launcherIcon
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
