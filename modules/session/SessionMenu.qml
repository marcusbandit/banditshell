pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// Power, on the right edge: the one panel you summon by name rather than reach.
//
// It is where caelestia's was, because that is a keybind's worth of muscle
// memory and there is nothing to be gained by moving it. Everything else about
// it is this shell's: it is a blob in the chassis's distance field, so it melts
// out of the right band instead of being drawn over it, and it arrives from off
// the screen rather than growing in place. See modules/VolumeRail.qml, which
// comes out of the same edge the same way.
//
// EVERY DESTRUCTIVE ENTRY ASKS FIRST, in place. Not a modal and not an "are you
// sure" that trains you to click yes: the button itself becomes the question,
// and anything else you do answers no. The one that costs nothing to get wrong
// (lock) goes on the first press; see services/Power.qml for which is which.
//
// NO WORDS ON IT. Four marks in a column and nothing else.
//
// This had a caption naming whichever button was chosen, and then briefly a full
// list of names beside them. Both were answering a question this panel does not
// get asked: it is opened by a keybind, by someone who put the keybind there, to
// press one of four things they already know. The names were furniture, and they
// set the panel's width, so the whole shape was sized by text nobody was reading.
// The confirm speaks in the mark instead, which is where you are already looking.
//
// The buttons are one GROUP rather than four loose squares. They are variants of
// a single choice and they are always all four, which a shared shell says in a
// way four gaps of background cannot.
//
// WHAT IS CHOSEN IS ONE SHAPE THAT MOVES, not a fill that turns on in a new
// square. Four buttons in a fixed column is exactly the case where a snapping
// highlight reads as a flicker: nothing travels, so the eye has to re-find the
// mark after every step. A marker that slides carries your attention with it, and
// it is the same exponential chase everything else in this shell tracks with, so
// dragging the cursor down the column drags the shape rather than restarting an
// animation four times. See components/Follow.qml.
Item {
    id: root

    // The band's own thickness. The panel reaches the screen's edge and includes
    // it, so the shape starts at the band rather than floating clear of it.
    required property real border

    readonly property bool open: root.shown
    property bool shown: false

    // WHICH ONE IS CHOSEN, for the keyboard and the cursor alike. One value, not
    // one per input: hovering and arrowing are the same question, and a panel
    // that tracked them separately would show two chosen buttons the moment you
    // touched the mouse after using the keys.
    property int selected: root.resting

    // The action that has been asked for once and is waiting to be asked again,
    // by key. "" is the resting state.
    property string arming: ""

    // The window that had the keyboard before this took it, so it can have it
    // back. A power menu that leaves focus on the desktop after Escape is a power
    // menu you have to click out of.
    //
    // The window on THIS screen, asked of `Hypr.focusedOn`. A power menu you
    // dismissed should leave the machine exactly as it found it, and a shell-
    // wide answer left it with the keyboard on a different monitor than the one
    // it started on: see services/Hypr.qml's `focusedByMonitor`.
    property string restoreTo: ""

    // WHICH SCREEN THIS PANEL IS DRAWN ON, for the line above. Asked of the
    // window, per modules/SettingsCorner.qml and modules/sidebar/Sidebar.qml.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    readonly property var actions: Power.actions

    // WHERE THE PANEL OPENS, which is not the top. Shut down is first in the
    // list, and a panel that arrives with it already chosen puts the end of the
    // session under whatever you press next. Found rather than written down: the
    // first entry that costs nothing to get wrong, so reordering the table moves
    // this with it and adding an entry above Lock cannot quietly arm anything.
    readonly property int resting: Math.max(0, root.actions.findIndex(a => a.safe))

    // The WHOLE screen while it is open, so a click anywhere outside puts it
    // away. Same shape as the launcher's catcher.
    readonly property Item maskItem: catcher

    readonly property real button: Appearance.sizes.sessionButton

    // ONE step, used for the space between rows and for the group's own inset.
    // The gap inside the group and the gap around it being the same is what
    // makes it read as a group and not as a border: the buttons are spaced by
    // the shell they sit in rather than by a rule of their own.
    readonly property real gap: Appearance.padding.small

    // The panel's own margin. Down a tier from the old one, which was set when
    // the panel had a caption under it and needed the width to look deliberate.
    // Around a group that is already inset by its own shell, the wider margin
    // just read as unclaimed space.
    readonly property real pad: Appearance.padding.normal

    // ONE ROW TO THE NEXT, which is the only distance the marker knows. Every
    // position in the column is this times an index; nothing here holds a list of
    // where the four buttons are.
    readonly property real step: root.button + root.gap

    // THE GROUP, from the count rather than from a measured child: a Column's
    // implicitHeight is only right once its delegates exist, and this decides
    // the shape the panel slides in as.
    readonly property real groupWidth: root.button + root.gap * 2
    readonly property real groupHeight: root.actions.length * root.step - root.gap + root.gap * 2

    // The corner a button gets, and the group's derived from it rather than
    // picked. A shell inset by `gap` around a corner of radius r is concentric
    // with it at r + gap; any other number and the two curves visibly diverge in
    // the corners, which is the one place both are on screen at once.
    readonly property real cellRadius: Appearance.rounding.normal
    readonly property real groupRadius: root.cellRadius + root.gap

    readonly property real contentWidth: root.groupWidth
    readonly property real contentHeight: root.groupHeight

    readonly property real panelWidth: root.border + root.contentWidth + root.pad * 2
    readonly property real panelHeight: root.contentHeight + root.pad * 2

    // It arrives from OFF the screen and ends flush with the right edge, so the
    // approach is a real one: it reaches the band, merges with it, then swells
    // out to the left. Parked a full melt-distance clear when closed, because a
    // blob that merely shrinks still pulls the band toward it the whole way and
    // would leave a permanent bulge halfway down the edge.
    readonly property real slide: (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value)

    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + root.slide,
            y: (root.height - root.panelHeight) / 2,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large
        }
    ]

    function show(): void {
        if (root.shown)
            return;
        root.restoreTo = Hypr.focusedOn(root.screenName);
        root.selected = root.resting;
        root.arming = "";
        // WHERE IT LEFT OFF IS NOT A "FROM". The marker chases whatever is
        // chosen, and the panel opens on the resting entry however it closed, so
        // without this it would slide up the column while the panel is still
        // flying in from off the screen: two travels at once, neither readable.
        marker.snap();
        root.shown = true;
        // DEFERRED: the surface only asks the compositor for the keyboard once
        // `open` has propagated, and forcing focus before that happens gets a
        // focused item that receives nothing. See ShellWindow's keyboardFocus.
        Qt.callLater(keys.forceActiveFocus);
    }

    function hide(): void {
        if (!root.shown)
            return;
        root.shown = false;
        root.arming = "";
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

    // Choosing a different button is one of the things that answers no.
    function choose(index: int): void {
        if (index < 0 || index >= root.actions.length || index === root.selected)
            return;
        root.selected = index;
        root.arming = "";
    }

    // Clamped rather than wrapped. The list is short enough to see all of at
    // once, and wrapping past Lock onto Shut down puts the most destructive entry
    // one keypress off the least, which is exactly the press you make when you
    // have run out of list and not noticed.
    function move(delta: int): void {
        root.choose(Math.max(0, Math.min(root.actions.length - 1, root.selected + delta)));
    }

    function activate(index: int): void {
        const entry = root.actions[index];
        if (!entry)
            return;

        if (entry.safe || root.arming === entry.key) {
            Power.run(entry);
            root.hide();
        } else {
            root.arming = entry.key;
        }
    }

    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.shown ? 1 : 0
        epsilon: 0.005
    }

    // WHERE THE MARKER IS, in the group's own coordinates, chasing where it
    // should be. The target is arithmetic off the chosen index rather than the
    // position of a delegate, so it is right before the delegates exist and stays
    // right if the table grows.
    Follow {
        id: marker

        speed: Appearance.anim.trackSpeed
        target: root.selected * root.step
    }

    // THE KEYBOARD, on an item of its own rather than on the panel.
    //
    // The panel is invisible until the reveal has moved off zero, and an
    // invisible item cannot hold focus, so focusing the panel on the way up
    // would silently do nothing and the first Escape would go to the desktop.
    // This one has no size and is always visible, so it is always focusable.
    Item {
        id: keys

        Keys.onPressed: event => {
            // Tested on `event.key` rather than through the named handlers:
            // Keys.onUpPressed and its siblings were measured never firing on an
            // item reached this way, while onEscapePressed on the same item did.
            const ctrl = event.modifiers & Qt.ControlModifier;

            if (event.key === Qt.Key_Escape)
                root.hide();
            else if (event.key === Qt.Key_Up || (ctrl && (event.key === Qt.Key_K || event.key === Qt.Key_P)))
                root.move(-1);
            else if (event.key === Qt.Key_Down || (ctrl && (event.key === Qt.Key_J || event.key === Qt.Key_N)))
                root.move(1);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                root.activate(root.selected);
            else
                return;

            event.accepted = true;
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
    // contents: the buttons ride in with the shape they are in.
    Item {
        id: panel

        x: root.width - root.panelWidth + root.slide
        y: (root.height - root.panelHeight) / 2
        width: root.panelWidth
        height: root.panelHeight
        visible: reveal.value > 0.001
        enabled: root.open

        // THE GROUP. One shell, four buttons in it, and the shell is what
        // supplies the spacing between them. Hung from the panel's own left
        // padding, which is the edge that faces the screen; the band is on the
        // other side and belongs to the chassis.
        G2Rect {
            x: root.pad
            anchors.verticalCenter: parent.verticalCenter
            width: root.groupWidth
            height: root.groupHeight
            radius: root.groupRadius
            color: Appearance.colour.fill

            // THE MARKER, declared before the buttons so it sits behind their
            // marks: it is the surface they are on, not a thing in front of them.
            //
            // ONE shape for four buttons. The alternative is a fill on whichever
            // cell is chosen, which is what this was, and it cannot travel: the
            // old fill has to end somewhere and the new one has to start
            // somewhere, and no amount of fading between them is movement.
            G2Rect {
                x: root.gap
                y: root.gap + marker.value
                width: root.button
                height: root.button
                radius: root.cellRadius

                // The accent is reserved for state that earns a colour, and
                // "this will end your session if you press it again" earns one.
                // Crossfaded rather than switched, because the marker may be
                // travelling when it changes and a hard colour cut mid-slide
                // reads as a second, different event.
                color: root.arming ? Appearance.colour.accentFill : Appearance.colour.fillStronger

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            // Placed at the same inset the marker starts from rather than
            // centred, so the two are laid out by one number and cannot drift
            // apart by a rounding.
            Column {
                x: root.gap
                y: root.gap
                spacing: root.gap

                Repeater {
                    model: root.actions

                    delegate: Item {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property bool armed: root.arming === cell.modelData.key
                        readonly property bool chosen: root.selected === cell.index

                        width: root.button
                        height: root.button

                        Icon {
                            anchors.centerIn: parent

                            name: cell.armed ? "check" : cell.modelData.icon
                            size: Appearance.sizes.sessionIcon

                            // Faded between weights on the same clock the marker
                            // moves on, so a mark brightens as the marker arrives
                            // under it rather than the instant the cursor crosses
                            // the edge of a square it has not reached yet.
                            color: cell.armed ? Appearance.colour.accent : cell.chosen ? Appearance.colour.text : Appearance.colour.textDim

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.anim.normal
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: root.choose(cell.index)
                            onClicked: {
                                root.choose(cell.index);
                                root.activate(cell.index);
                            }
                        }
                    }
                }
            }
        }
    }
}
