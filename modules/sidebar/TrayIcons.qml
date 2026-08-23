pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

// WHAT IS RUNNING WITHOUT A WINDOW, at the top of the sidebar.
//
// The workspace column below is complete about windows and therefore silent
// about everything else: an application that has put itself away has no window,
// so it is on no workspace, so the sidebar's answer to "what is this machine
// doing" was missing the half that never asks for the screen. This is that half.
//
// AT THE TOP, and the reason is that the sidebar now says three things and they
// are three different questions: what is running (here), where you are (the
// middle), how the machine is doing (the bottom, around the clock). Added to the
// bottom group it would have been a fourth thing in a stack that grows upward,
// so a busy tray would push the clock into the workspace column on a short
// screen. Up here it grows down into a band that is empty anyway.
//
// EMPTY MEANS ABSENT, not an empty container. Nothing running in the background
// is the ordinary state of a machine, and it should look like nothing.
Item {
    id: root

    // `deliberate` says the menu was ASKED FOR rather than wandered into, and it
    // decides whether the menu latches open or is merely held while a pointer
    // stays near it. Hover cannot say it; a long press, the right button and a
    // tap the application refused all can.
    //
    // WITHOUT THIS the tray was the one opener that could not say so, and a
    // long press, which is the whole of the touch story up here, opened a menu
    // that the grace timer took away a fifth of a second later. Menus has a
    // backstop for exactly that case (a menu no pointer has ever been near
    // latches itself rather than closing), and this makes the backstop the
    // second line of defence rather than the only one.
    signal requested(string key, bool deliberate)
    signal released

    // Which item the cursor is on, by key, "" for none. ONE source of truth, for
    // the same reason StatusIcons keeps one: sliding from one icon to the next
    // fires a leave and an enter in an order Qt does not promise, and the leave
    // would otherwise undo the open the enter just did.
    property string hoveredKey: ""

    // Hover only, so never deliberate. A deliberate open does not come through
    // here at all: it goes straight out from the delegate, because routing it
    // through `hoveredKey` would lose it whenever the pointer was already on the
    // icon, which under a finger it always is (the press synthesises the hover
    // and the release is the tap, in that order, on the same icon).
    // The marker is moved from the same handler rather than from a binding,
    // because "" means HOLD where it is and fade, not travel to the top. See
    // StatusIcons, which carries the same marker for the same reason.
    onHoveredKeyChanged: {
        root.markItem(root.hoveredKey);

        if (root.hoveredKey)
            root.requested(root.hoveredKey, false);
        else
            root.released();
    }

    // WHICH SLOT THE MARKER IS AIMED AT, and the pitch the column lays the
    // items out on.
    property int markedIndex: 0

    readonly property real pitch: Appearance.sizes.traySlot + Appearance.sizes.trayGap

    function markItem(key: string): void {
        const i = root.shown.findIndex(item => root.keyFor(item) === key);
        if (i < 0)
            return;

        const cold = lit.value < 0.01;
        root.markedIndex = i;
        if (cold)
            slide.snap();
    }

    Follow {
        id: slide

        speed: Appearance.anim.trackSpeed
        target: root.markedIndex * root.pitch
    }

    Follow {
        id: lit

        speed: Appearance.anim.revealSpeed
        target: root.hoveredKey ? 1 : 0
        epsilon: 0.005
    }

    // CAPPED, like every other list in this shell. A tray is somebody else's
    // list and it has no upper bound: an ordinary session is four or five items,
    // a bad one is fifteen, and that is a column longer than the workspaces it
    // sits above.
    readonly property var shown: Tray.items.slice(0, Appearance.sizes.trayMax)

    // A menu key for an item, which is also the CLI's handle on it:
    // `banditshell menu open tray:spotify`. Namespaced, so a tray item calling
    // itself "battery" cannot collide with the gauge of that name.
    function keyFor(item: var): string {
        return `tray:${Tray.keyOf(item)}`;
    }

    // The rows the menu layer needs, in the shape it already understands, so a
    // tray item and a status gauge are opened by exactly the same code.
    readonly property var items: root.shown.map(i => ({
                key: root.keyFor(i),
                title: Tray.nameOf(i),
                body: trayMenu
            }))

    // WHICH ITEM THE MENU IS ABOUT, which this lookup is also the moment to
    // decide.
    //
    // The menu layer is handed a Component and never a value: it holds one menu
    // at a time and does not know what any of them are about. Every tray item
    // shares one Component, so the item itself has to travel some other way, and
    // this is the one place both routes into a menu pass through, the cursor's
    // and the CLI's. TrayMenu takes a COPY on the way up, so the menu being
    // faded out keeps showing the application it was about instead of snapping
    // to the new one halfway through the cross-fade.
    property var openItem: null

    function entryFor(key: string): var {
        const entry = root.items.find(i => i.key === key) ?? null;
        if (entry)
            root.openItem = root.shown.find(i => root.keyFor(i) === key) ?? null;
        return entry;
    }

    function iconFor(key: string): Item {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.key === key)
                return item;
        }
        return null;
    }

    // THE WIDTH IS GIVEN, the height is asked for, exactly as in StatusIcons.
    // The sidebar hands this group the whole band so each item's target can span
    // it, and the implicit one is only what it draws, for a caller that hands it
    // nothing. Both stay conditional on there being anything to show, because an
    // empty tray is not a tray of nothing, it is no tray.
    implicitWidth: root.shown.length ? Appearance.sizes.traySlot : 0
    implicitHeight: root.shown.length ? column.implicitHeight : 0
    visible: root.shown.length > 0

    // Where the drawn box is, since it is not this item's rectangle. Read by the
    // bar to stand the group off the screen's edge by the distance it stands off
    // the bar's; the gauges answer the same pair for the same reason, including
    // WHICH box: the container while it is painted, the marker's own slot while
    // it is not. See StatusIcons for why the answer is the fill's alpha.
    readonly property bool boxed: fill.color.a > 0
    readonly property real sideGap: (width - (root.boxed ? fill.width : Appearance.sizes.traySlot)) / 2
    readonly property real overhang: root.boxed ? Appearance.padding.small : 0

    // The same quiet container the gauges get, so the two groups read as two
    // groups of the same kind of thing, and pinned to the column for the same
    // reason: the item is the width of the band now, and a container filling it
    // would be a stripe across the top of the bar rather than a pill around the
    // icons.
    G2Rect {
        id: fill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: column.top
        anchors.bottom: column.bottom
        anchors.topMargin: -root.overhang
        anchors.bottomMargin: -root.overhang
        width: Appearance.sizes.traySlot + Appearance.padding.small * 2
        radius: Appearance.rounding.normal
        // ON TRIAL WITH THE GAUGES': the container drawn in nothing, so the one
        // lit shape in the group is the marker under the cursor. Two boxes at
        // once - a permanent container and a hover fill inside it - is two
        // highlights, and only one of them is answering anything.
        color: "transparent"
    }

    // THE MARKER: the hover fill, as ONE shape that travels between the items.
    // Declared before the column so it sits under the icons. The gauges' marker
    // carries the whole argument; this is the same thing on the same pitch.
    G2Rect {
        x: column.x + (column.width - width) / 2
        y: column.y + slide.value
        width: Appearance.sizes.traySlot
        height: Appearance.sizes.traySlot
        radius: Appearance.rounding.normal
        color: Appearance.colour.fillStrong
        opacity: lit.value
    }

    // FULL WIDTH, so the delegates in it have a full width to take. Nothing in
    // here is what you see: each delegate draws a slot-wide square centred on
    // the same line the old one-slot column stood on.
    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.sizes.trayGap

        Repeater {
            id: repeater

            // A ScriptModel, NOT the array: `Tray.items` is rebuilt whenever any
            // item changes anything about itself, including a title that moves
            // with the track that is playing, and a plain-array Repeater would
            // throw away every icon and build it again each time, taking the
            // hover it was under with it.
            model: ScriptModel {
                values: root.shown
            }

            delegate: TrayIcon {
                id: icon

                required property var modelData

                readonly property string key: root.keyFor(icon.modelData)

                // A Column positions its children and never resizes them, so a
                // delegate left to itself would be one slot wide inside a
                // full-width column and the dead lanes would still be there.
                width: column.width

                item: icon.modelData

                // A deliberate request goes straight up; an incidental one is
                // laundered through `hoveredKey` so that sliding from one icon
                // to the next cannot have the leave undo the enter. See the
                // handler on `hoveredKey` for why the deliberate one must not
                // take the same road.
                onRequested: deliberate => {
                    if (deliberate)
                        root.requested(icon.key, true);
                    else
                        root.hoveredKey = icon.key;
                }
                onHoveredChanged: if (!icon.hovered && root.hoveredKey === icon.key)
                    root.hoveredKey = ""

                // The one thing up here that says a name out loud, for the beat
                // before the menu arrives and for the icons whose artwork is a
                // coloured square that could be anything.
                //
                // IT POINTS AT THE PICTURE, not at the item, and those parted
                // company when the item grew to the width of the band. A tooltip
                // is placed beside the far edge of whatever it names, so aimed
                // at the item it would sit a finger's width out into the desktop
                // with a gap between it and the icon it is about.
                HoverTip {
                    text: Tray.nameOf(icon.modelData)
                    host: icon.drawn
                    asked: icon.hovered
                }
            }
        }
    }

    Component {
        id: trayMenu

        TrayMenu {
            Component.onCompleted: item = root.openItem
        }
    }
}
