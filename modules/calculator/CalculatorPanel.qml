pragma ComponentBehavior: Bound

import QtQuick
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

    // The whole screen while it is out, so a click anywhere off it puts it away.
    // The power panel's note, word for word: summoned rather than reached for,
    // so there is no edge to leave.
    readonly property Item maskItem: catcher

    // The keypad is a menu BODY, so it is as wide as a menu's body is: this
    // panel and a menu are the same object seen from two directions, and a
    // calculator that was a different width in each would say they were not.
    readonly property real contentWidth: Appearance.sizes.menuWidth - Appearance.padding.large * 2

    readonly property real panelWidth: root.originX + root.contentWidth + Appearance.padding.large * 2
    readonly property real panelHeight: pad.implicitHeight + Appearance.padding.large * 2

    // It arrives from OFF the screen and ends flush with the sidebar's outer
    // edge. Parked a full melt-distance clear when closed, because a blob that
    // merely shrinks still pulls the band toward it the whole way and would
    // leave a permanent bulge halfway down the flank.
    readonly property real slide: (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property var blobs: [
        {
            x: -root.slide,
            y: (root.height - root.panelHeight) / 2,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    // What had the keyboard before this took it. Taking exclusive focus makes
    // the compositor unfocus the window under it, and letting go does not hand
    // it back: you would get the calculator, dismiss it, and be left typing into
    // nothing. The launcher and the power panel both keep this for the same
    // reason.
    property string restoreTo: ""

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedAddress;
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

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

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

        x: -root.slide
        y: (root.height - root.panelHeight) / 2
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        // Hung from the panel's own right padding, which is the edge that faces
        // the screen. The band is on the other side and belongs to the chassis,
        // so the content starts clear of it rather than under it.
        CalculatorMenu {
            id: pad

            x: root.originX + Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: root.contentWidth
        }
    }
}
