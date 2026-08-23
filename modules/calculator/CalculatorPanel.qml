pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

// The calculator, summoned by name. Out of the sidebar's flank, centred.
//
// WHY IT IS NOT A GAUGE, which is the obvious place and the wrong one.
// modules/sidebar/StatusIcons.qml spends a paragraph on why the settings door
// was taken out of that column: the four gauges each answer a GLANCE, a menu's
// worth of state a hover can hold open and a look can finish, and a door
// standing among them reads as a fifth gauge so a hand goes to it expecting the
// same kind of answer. A calculator is not a glance either. It is somewhere you
// go, do a thing, and leave, which makes it the power panel's kind of object
// rather than the audio menu's: summoned by name, from wherever you were.
//
// SO IT IS SessionMenu's SHAPE, MIRRORED. Same construction, same reveal, same
// whole-screen catcher, same keyboard discipline, and the same reason for each:
// a panel nothing reached for has no edge to leave and nothing else to dismiss
// it. It arrives from off the screen and ends flush against the sidebar's outer
// edge, so the approach is a real one rather than a box fading up in place, and
// it is a blob in the chassis's distance field, so it melts out of the band
// instead of being drawn over it.
//
// It comes out of the LEFT rather than the right because that is where this
// shell keeps the things you operate: the bar, the menus, the launcher's own
// band. The right edge is the volume rail's and the power panel's, and a third
// object arriving there would be three unrelated answers to one gesture.
//
// AND IT TAKES THE KEYBOARD, which the menu body inside it is explicitly built
// not to need. That is not a contradiction, it is the whole difference between
// the two ways this calculator is reached. A menu opens on HOVER, so a menu that
// grabbed every key would take the keyboard away from the window you were
// working in by you merely crossing the bar; this opens because somebody asked
// for it, it already holds exclusive focus for its own Escape, and the number
// row is therefore free. See CalculatorMenu.typeKey for the mapping, which is
// routed through the same press() the targets use so a key and a click cannot
// drift apart.
Item {
    id: root

    // Where the chassis ends and the desktop begins. The panel starts exactly
    // here, so the two never overlap; the menus are given the same number.
    required property real originX

    readonly property bool open: root.shown
    property bool shown: false

    // WHICH OF THE TWO SHAPES IT IS STANDING IN.
    //
    // false is the panel this file describes above: a strip out of the sidebar's
    // flank, as wide as a menu's body, for the sum you do while something else
    // has your attention. true is the same calculator with the screen: summoned
    // from the launcher by name like any other application, standing over
    // everything, for when the arithmetic IS what you are doing.
    //
    // ONE OBJECT IN TWO SHAPES, and not two objects. The line is the reason. This
    // file already argues that closing a calculator must not clear what is on it;
    // popping one out into a second panel with its own keypad would break that
    // rule in the one place it is most obviously wrong, since you would press the
    // button precisely because the sum got serious and would watch it vanish. So
    // the body below is a single instance that changes size, and `full` is a
    // property of the container rather than a second container.
    //
    // IT IS STICKY, deliberately. It survives a close, so the key opens the
    // calculator you were last using rather than the one this file happened to
    // default to; a window that reopened at some other size every time would be
    // one you had to resize every time.
    property bool full: false

    // The whole screen while it is out, so a click anywhere off it puts it away.
    // The power panel's note, word for word: summoned rather than reached for,
    // so there is no edge to leave.
    readonly property Item maskItem: catcher

    // The keypad is a menu BODY, so it is as wide as a menu's body is: this
    // panel and a menu are the same object seen from two directions, and a
    // calculator that was a different width in each would say they were not.
    readonly property real contentWidth: Appearance.sizes.menuWidth - Appearance.padding.large * 2

    // ------------------------------------------------------------------
    // THE TWO SHAPES, and the one number that is somewhere between them.

    // THE FLANK, as it always was: flush with the sidebar's outer edge, a menu
    // body wide, and as tall as the keypad at its resting size.
    //
    // WRITTEN OUT rather than read off `pad.implicitHeight`, which is what it
    // used to be. The body grows on the way to fullscreen, so reading its live
    // height here would have the flank shape ballooning as the panel left it, and
    // the shape it is departing has to hold still for the departure to read as
    // one motion. Every term is the body's own published arithmetic, so the two
    // can only disagree if the keypad stops being rows of keys with gaps.
    readonly property real flankWidth: root.originX + root.contentWidth + Appearance.padding.large * 2
    readonly property real flankHeight: pad.chromeHeight + pad.rows * pad.restKeyHeight + (pad.rows - 1) * pad.gap + Appearance.padding.large * 2

    // THE SCREEN, which for this shell means the hole in the chassis and not the
    // display: the band and the sidebar are the shell's own body, and a panel
    // drawn over them would be the shell covering itself up.
    //
    // INSET BY THE MELT DISTANCE, which is the one number here that is not a
    // layout token, and it is the right one because it is not a margin: it is
    // exactly how far apart two shapes have to be for the chassis field to stop
    // pulling them together (config/Config.qml's blob.melt, and see
    // components/blob/blob.frag). At any less than this the slab and the band
    // fuse into a single piece and the chassis stops having a shape; at this, it
    // stands clear, which is what an application overlaying the desktop should
    // look like. Deriving it from the field rather than picking a gap that looked
    // right means it stays correct if the field is ever retuned.
    readonly property real inset: Appearance.sizes.melt
    readonly property real fullX: root.originX + root.inset
    readonly property real fullY: Appearance.sizes.band + root.inset
    readonly property real fullWidth: root.width - root.fullX - Appearance.sizes.band - root.inset
    readonly property real fullHeight: root.height - (Appearance.sizes.band + root.inset) * 2

    // HOW FAR ALONG THE MORPH IS, 0 on the flank and 1 fullscreen. Everything
    // below is one lerp on this, so the panel, its blob and the keypad inside it
    // cannot arrive at different times; the shape is one object changing size,
    // and a body that finished growing before the slab did would say it was two.
    readonly property real fullness: shape.value

    function mix(a: real, b: real): real {
        return a + (b - a) * root.fullness;
    }

    readonly property real panelWidth: root.mix(root.flankWidth, root.fullWidth)
    readonly property real panelHeight: root.mix(root.flankHeight, root.fullHeight)

    // Where it rests once it is out. The flank shape starts at the screen's own
    // left edge and holds the chassis inside itself (which is what `originX` is
    // for); the fullscreen one starts clear of the sidebar.
    readonly property real restX: root.mix(0, root.fullX)
    readonly property real restY: root.mix((root.height - root.flankHeight) / 2, root.fullY)

    // It arrives from OFF the screen and ends flush with the sidebar's outer
    // edge. Parked a full melt-distance clear when closed, because a blob that
    // merely shrinks still pulls the band toward it the whole way and would
    // leave a permanent bulge halfway down the flank.
    //
    // THE SAME EXIT IN BOTH SHAPES, which is why this reads `panelWidth` rather
    // than the flank's own: a fullscreen calculator that faded where the flank
    // one slid would be two panels wearing one name. It is a big motion at full
    // width, and it is the motion the file already contracts to.
    readonly property real slide: (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property real panelX: root.restX - root.slide

    readonly property var blobs: [
        {
            x: root.panelX,
            y: root.restY,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    // ------------------------------------------------------------------
    // HOW BIG THE KEYS GET.
    //
    // The type scale has three sizes for the whole shell and the keypad already
    // spends all three (~/.claude/rules/type-scale.md), so a calculator handed a
    // screen cannot answer with a bigger number: it answers with a bigger keypad,
    // which is the dimension a fixed scale leaves free and, for a thing you hit,
    // the more useful one anyway.
    //
    // A CEILING AND A ROOM, and the smaller wins. The ceiling is a key drawn as
    // one line of the LARGEST type in the shell inside the LARGEST padding ring
    // in the shell, which is as big as a target can get before its label starts
    // to look lost in the middle of it; both terms are tokens, so it is a
    // sentence about the scale rather than a number somebody measured. The room
    // is what the fullscreen box actually has once the readout and the rule are
    // taken out of it. Floored at the resting height so a short screen never
    // makes fullscreen the smaller of the two shapes.
    readonly property real keyCeiling: Math.round(Appearance.font.size.large * 4 / 3) + Appearance.padding.huge * 2
    readonly property real keyRoom: (root.fullHeight - Appearance.padding.large * 2 - pad.chromeHeight - (pad.rows - 1) * pad.gap) / pad.rows
    readonly property real fullKeyHeight: Math.max(pad.restKeyHeight, Math.min(root.keyCeiling, root.keyRoom))

    // AND THE GRID KEEPS ITS PROPORTIONS, which is why the width is the resting
    // width times the same growth rather than a second set of measurements: a
    // keypad that got taller without getting wider is a different keypad. Clamped
    // to the room, so the columns cannot walk off a narrow screen.
    readonly property real fullBodyWidth: Math.min(root.fullWidth - Appearance.padding.large * 2, root.contentWidth * (root.fullKeyHeight / pad.restKeyHeight))

    // What had the keyboard before this took it. Taking exclusive focus makes
    // the compositor unfocus the window under it, and letting go does not hand
    // it back: you would get the calculator, dismiss it, and be left typing into
    // nothing. The launcher and the power panel both keep this for the same
    // reason.
    //
    // ON THIS SCREEN, which is the whole of what `Hypr.focusedOn` adds over the
    // shell-wide answer this used to read. There is one calculator per monitor
    // and the one you summoned is the one on the screen you are at; the window
    // it must hand the keyboard back to is the one that was in front of you
    // there, not whichever window happened to hold the keyboard on the other
    // screen. See services/Hypr.qml's `focusedByMonitor` for what that cost.
    property string restoreTo: ""

    // WHICH SCREEN THIS PANEL IS DRAWN ON, for the line above.
    //
    // ASKED OF THE WINDOW rather than handed down from ShellWindow, which is the
    // idiom modules/SettingsCorner.qml established and both
    // modules/sidebar/Sidebar.qml and modules/notifications/NotificationTray.qml
    // use: the screen is not a fact about the calculator the way its keypad is,
    // it is a fact about the surface the calculator happens to be drawn on. It
    // is also free to anything that builds this panel outside the shell's own
    // wiring, which a property threaded down through ShellWindow would not be.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.shown = true;
        // DEFERRED: the surface only asks the compositor for the keyboard once
        // `open` has propagated, and focus forced before that lands is focus in a
        // surface with no keys to give. See ShellWindow's keyboardFocus.
        Qt.callLater(keys.forceActiveFocus);
    }

    // WHAT IT DOES NOT DO IS CLEAR THE LINE. Closing a calculator is not the
    // same act as pressing C, and a panel that forgot the number the moment you
    // looked away would be one you could not put down to go and read the figure
    // you were about to divide by. The keypad's state lives in the body, which
    // this panel keeps loaded for exactly as long as the shell does, so what was
    // on the line is still on it when you come back.
    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        keys.focus = false;
        Hypr.restoreFocus(root.restoreTo);
        root.restoreTo = "";
    }

    function toggle(): void {
        if (root.shown)
            root.hide();
        else
            root.show();
    }

    // THE TWO SHAPES, AS VERBS, because "open it" and "open it as the
    // application" are different requests and only one of them is a toggle.
    //
    // Asking for a shape you are already in is not a request to close: pressing
    // the launcher's Calculator entry while the flank panel happens to be out
    // means "give me the big one", and answering that by putting the calculator
    // away would be the entry doing the opposite of what it says. Closing is
    // `hide`, the key, the catcher and Escape, all of which are still there. The
    // CLI's `app` verb is where the toggle lives, because a desktop entry
    // launched twice does have to put its window away (see
    // assets/applications/banditshell-calculator.desktop).
    function app(): void {
        root.full = true;
        root.show();
    }

    function panel(): void {
        root.full = false;
        root.show();
    }

    // The control on the readout. It never closes and never opens: it is a
    // request about SIZE, from a body that is by definition already on screen.
    function toggleFull(): void {
        root.full = !root.full;
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    // THE MORPH, on its own follower rather than on the reveal's.
    //
    // They are genuinely two motions: one is the panel arriving and leaving, the
    // other is the shape it is in while it is here, and the second has to be able
    // to happen with the first standing still. Sharing a follower would mean the
    // button could only change the size of a panel that was also entering.
    //
    // Snapped rather than animated on the first frame it is asked for, if the
    // panel is not out: growing a shape nobody can see costs a second of the
    // reveal being wrong about how big the thing arriving is, and `banditshell
    // calculator app` from a launcher is exactly that case. `Follow` handles the
    // visible case; this one line handles the invisible one.
    Follow {
        id: shape

        speed: Appearance.anim.revealSpeed
        target: root.full ? 1 : 0
        epsilon: 0.005

        Component.onCompleted: snap()
    }

    // Nothing to animate when nothing is on screen: `full` set while the panel is
    // away is the shape it will ARRIVE in, not a shape to be watched changing.
    onFullChanged: if (!root.shown)
        shape.snap()

    // THE KEYBOARD, on an item of its own rather than on the panel, which is
    // invisible until the reveal has moved off zero: an invisible item cannot
    // hold focus, so focusing the panel on the way up would silently do nothing
    // and the first Escape would go to the desktop. SessionMenu and the settings
    // page both say this over their own `keys`.
    Item {
        id: keys

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.hide();
                event.accepted = true;
                return;
            }

            // Everything else is the keypad's if it wants it, and nothing's if it
            // does not. Tested on the event rather than through the named
            // handlers, which SessionMenu measured never firing on an item
            // reached this way.
            event.accepted = pad.typeKey(event.key, event.text);
        }
    }

    // DECLARED FIRST, so it sits under the panel: declaration order is input
    // order in QML. Anywhere that is not the panel puts the panel away.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: root.hide()
    }

    // The panel itself SLIDES, rather than being a fixed frame that reveals its
    // contents: the keys ride in with the shape they are in.
    Item {
        id: panel

        x: root.panelX
        y: root.restY
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        // ON THE FLANK it is hung from the panel's own right padding, which is
        // the edge that faces the screen: the band is on the other side and
        // belongs to the chassis, so the content starts clear of it rather than
        // under it. FULLSCREEN there is no band inside the shape at all, so the
        // keypad is simply centred in it, and the room around it is the point
        // rather than an overhang.
        CalculatorMenu {
            id: pad

            x: root.mix(root.originX + Appearance.padding.large, (panel.width - width) / 2)
            anchors.verticalCenter: parent.verticalCenter

            width: root.mix(root.contentWidth, root.fullBodyWidth)
            rowHeight: root.mix(pad.restKeyHeight, root.fullKeyHeight)

            // The door out of the room, drawn only where there is another room to
            // go to, which is both of the shapes this panel stands in and neither
            // of the surfaces the body is drawn on elsewhere.
            expandable: true
            expanded: root.full

            onExpandToggled: root.toggleFull()
        }
    }
}
