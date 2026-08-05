pragma ComponentBehavior: Bound

import QtQuick
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
// and anything else you do answers no. The two that cost nothing to get wrong
// (lock, suspend) go on the first press; see services/Power.qml for which is
// which.
//
// It is icon-only, like the one it replaces, so ONE caption under the column
// says what is currently chosen. One line serving five buttons rather than five
// labels: the labels would be read once and then never again, and the caption is
// the only thing on screen during the confirm, which is the moment it matters.
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
    property int selected: 0

    // The action that has been asked for once and is waiting to be asked again,
    // by key. "" is the resting state.
    property string arming: ""

    // The window that had the keyboard before this took it, so it can have it
    // back. A power menu that leaves focus on the desktop after Escape is a power
    // menu you have to click out of.
    property string restoreTo: ""

    readonly property var actions: Power.actions

    // The WHOLE screen while it is open, so a click anywhere outside puts it
    // away. Same shape as the launcher's catcher.
    readonly property Item maskItem: catcher

    readonly property real button: Appearance.sizes.sessionButton
    readonly property real gap: Appearance.padding.normal

    // What a confirm says. Its own line under the label rather than appended to
    // it, so the label stays the label: during a confirm you want to read WHAT
    // is about to happen at least as much as what to do about it.
    readonly property string hint: "press again"

    // Sized for the LONGEST caption it can ever show, not the one it is showing.
    //
    // The caption changes on the same press that arms a button, so a panel sized
    // to fit would step wider at exactly the moment you are being asked to
    // confirm, and the shape would be answering the click as well as the
    // question. Measured off the action table rather than guessed, so adding an
    // entry cannot outgrow it.
    readonly property string widestCaption: {
        let widest = root.hint;
        for (const entry of root.actions)
            if (entry.label.length > widest.length)
                widest = entry.label;
        return widest;
    }

    readonly property real contentWidth: Math.max(root.button, caption.width)

    // Measured off what is actually in the panel rather than recomputed from the
    // same numbers the layout used. StyledText fixes its line box at 4/3 of the
    // type size, which TextMetrics does not know about, so adding the two up here
    // lands a couple of pixels short and the caption sits in the padding.
    readonly property real contentHeight: column.implicitHeight

    readonly property real panelWidth: root.border + root.contentWidth + Appearance.padding.large * 2
    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

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
        root.restoreTo = Hypr.focusedAddress;
        root.selected = 0;
        root.arming = "";
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
    // once, and wrapping from Shut down back to Lock puts the most destructive
    // entry one keypress from the least.
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

    // What the widest caption measures, so the panel can be built around it
    // without anyone having to know how wide a character is.
    TextMetrics {
        id: caption

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: root.widestCaption
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

        // Hung from the panel's own left padding, which is the edge that faces
        // the screen. The band is on the other side and belongs to the chassis.
        Column {
            id: column

            x: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: root.contentWidth
            spacing: Appearance.padding.normal

            Column {
                spacing: root.gap
                anchors.horizontalCenter: parent.horizontalCenter

                Repeater {
                    model: root.actions

                    delegate: G2Rect {
                        id: cell

                        required property var modelData
                        required property int index

                        readonly property bool armed: root.arming === cell.modelData.key
                        readonly property bool chosen: root.selected === cell.index

                        width: root.button
                        height: root.button
                        radius: Appearance.rounding.normal

                        // ONE colour at three weights for the ordinary states,
                        // and the accent only for armed. The accent is reserved
                        // for state that earns a colour, and "this will end your
                        // session if you press it again" earns one.
                        color: cell.armed ? Appearance.colour.accentFill : cell.chosen ? Appearance.colour.fillStronger : Appearance.colour.fill

                        Icon {
                            anchors.centerIn: parent

                            name: cell.armed ? "check" : cell.modelData.icon
                            size: Appearance.sizes.sessionIcon
                            color: cell.armed ? Appearance.colour.accent : cell.chosen ? Appearance.colour.text : Appearance.colour.textDim
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

            // What is chosen, and under it the confirm. Centred on the column
            // rather than on the panel, so it reads as belonging to the buttons
            // above it.
            Column {
                anchors.horizontalCenter: parent.horizontalCenter

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: root.actions[root.selected]?.label ?? ""
                    font.pixelSize: Appearance.font.size.small
                    color: root.arming ? Appearance.colour.accent : Appearance.colour.textDim
                }

                // ALWAYS here, faded rather than hidden. A line that appears
                // would grow the panel at the exact moment it is asking you to
                // confirm, which moves the button you are about to press again.
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter

                    text: root.hint
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textFaint
                    opacity: root.arming ? 1 : 0
                }
            }
        }
    }
}
