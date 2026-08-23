import QtQuick
import qs.config
import qs.components
import qs.services

// One thing running in the background.
//
// Built to StatusIcon's drawing exactly: the same slot, the same fill under the
// cursor, the same label tiers, because a tray item and a gauge are the same
// KIND of thing in this bar and two idioms for one kind is how a sidebar starts
// looking assembled rather than designed. What differs is underneath: a gauge
// has one meaning and one gesture, and a tray item is somebody else's
// application with three.
Item {
    id: root

    required property var item

    readonly property bool hovered: mouse.containsMouse
    readonly property bool urgent: Tray.urgent(root.item)

    // Whether the press under way has already been answered as a long press, so
    // the release at the end of it is not also read as a tap. Cleared on every
    // press rather than on every release, because the press is the one event
    // that is guaranteed to happen first.
    property bool longPressed: false

    // THE PRIMARY ACTION, and it is quiet now: the press below makes the call
    // itself, because it needs the answer back and a signal cannot carry one.
    // Nothing connects it any more, and it is kept declared rather than deleted
    // so that the day something wants to hear about an activation without also
    // making one, this is where it goes. See the left-button branch for the
    // whole argument.
    signal activated

    // Open this item's menu. `deliberate` says the menu was ASKED FOR rather
    // than wandered into, which is what decides whether it latches open or is
    // held only for as long as a pointer stays near it. Hover is the one caller
    // that is incidental; a long press, the right button and a tap that the
    // application refused are all somebody meaning it.
    signal requested(bool deliberate)

    // WHERE THE PICTURE ACTUALLY IS, for anything that has to point AT this icon
    // rather than merely sit inside it. The item is as wide as the band now and
    // the picture is not, so the tooltip TrayIcons hangs off one of these would
    // stand off the far edge of the bar, a finger's width from the thing it is
    // naming, if it were given the item to aim at.
    readonly property alias drawn: drawing

    // AS BIG AS THE PICTURE, and no bigger, which is now what it wants rather
    // than what it gets: TrayIcons hands it the width of the whole band, and
    // this is the fallback for a caller that hands it nothing.
    implicitWidth: drawing.width
    implicitHeight: drawing.height

    // The same three tiers the gauges use, and the accent kept for the one state
    // that has asked for it. A tray full of colour is a tray you stop reading.
    readonly property color markColour: root.urgent ? Appearance.colour.accent : root.hovered ? Appearance.colour.text : Appearance.colour.textDim

    // THE DRAWING, AND ONLY THE DRAWING, at exactly the slot it has always been,
    // for the reason written out in full in StatusIcon: the item reaches across
    // the band so a press anywhere on that line lands here, and a hover fill
    // anchored to the item would follow it out and become a 62px stripe instead
    // of the rounded square the bar is made of. Wrapping the picture rather than
    // centring each part of it separately means the next thing added in here
    // inherits the slot instead of the trap.
    Item {
        id: drawing

        anchors.centerIn: parent
        width: Appearance.sizes.traySlot
        height: Appearance.sizes.traySlot

        // NO HOVER FILL HERE: the group draws it, as one marker that travels
        // from item to item (see TrayIcons). A fill owned by a delegate cannot
        // travel - the old one ends where it is and the new one begins where it
        // is - and it also meant two lit boxes at once, its own and the
        // container's, for one cursor.

        // THE APPLICATION'S MARK, through the shell's own table, so a thing you
        // have picked an icon for looks the same here as it does in the
        // workspace column. The artwork the application sent over the bus is
        // what that falls back to, and it arrives already resolved: a themed
        // icon, or a pixmap for the ones that ship no icon at all.
        AppMark {
            anchors.centerIn: parent
            size: Appearance.sizes.trayIcon
            spec: Tray.markFor(root.item)
            color: root.markColour

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }
    }

    // THREE BUTTONS AND A WHEEL, because that is the whole of what the protocol
    // offers and an application decides for itself which of them it answers.
    // Left is "show me this", middle is whatever it calls secondary, and the
    // menu is on the right button and on hover both: reaching for it is how you
    // find out what an application will let you do without opening it.
    //
    // A HAND HAS ONE OF THE FOUR. Touch synthesises a left button and nothing
    // else: no hover that outlives the finger, no second or third button, no
    // wheel. So two thirds of what a tray item offers were simply unreachable,
    // and for an application that declares `onlyMenu` the part that was missing
    // was the entire interaction. The two additions below are for that hand, and
    // neither of them takes anything away from the one holding a mouse.
    //
    // The hit area follows StatusIcon's: the whole band across, and half the gap
    // up and down, for the reason written out in full there. The drawn slot is
    // the drawing, and every pixel of the bar an icon is sitting in the middle
    // of has to belong to one icon or another.
    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.trayGap / 2
        anchors.bottomMargin: -Appearance.sizes.trayGap / 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onEntered: root.requested(false)

        onPressed: root.longPressed = false

        // PRESS AND HOLD IS THE RIGHT BUTTON, for a hand that has not got one.
        // It is what every touch platform means by "the other thing this does",
        // so it is the one context gesture that does not have to be discovered,
        // and it lands on the same signal the right button and the hover already
        // use: there is one menu, and this is a third door into it.
        onPressAndHold: {
            root.longPressed = true;
            root.requested(true);
        }

        onClicked: event => {
            // The release that ends a long press is not a tap. Qt is not
            // consistent about whether `clicked` follows `pressAndHold`, and a
            // menu that opens under the finger and then has the application
            // activated out from under it half a second later is the worse
            // outcome, so this refuses rather than relying on the toolkit.
            if (root.longPressed) {
                root.longPressed = false;
                return;
            }

            if (event.button === Qt.MiddleButton)
                Tray.secondary(root.item);
            else if (event.button === Qt.RightButton)
                root.requested(true);
            else if (!Tray.activate(root.item))
                // THE APPLICATION REFUSED, which is a thing it is allowed to do:
                // `onlyMenu` is the protocol's way of saying a click on this
                // means nothing, and Tray.activate answers false rather than
                // sending one anyway. That false used to be dropped on the floor,
                // so a VPN agent or a sync client, whose menu IS the interaction,
                // was an icon that did nothing at all when pressed. Falling back
                // to the menu makes the primary gesture reach the only thing the
                // application offers.
                //
                // THE CALL IS MADE HERE rather than sent up as `activated`,
                // because the answer only exists at the call and a signal cannot
                // hand one back. The sidebar's own `onActivated` makes the
                // identical call, so this branch must not do both: two
                // activations in one press is a window that opens and shuts
                // again.
                root.requested(true);
        }

        onWheel: event => {
            Tray.scroll(root.item, event.angleDelta.y);
            event.accepted = true;
        }
    }
}
