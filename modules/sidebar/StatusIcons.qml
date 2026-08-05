pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

// The system status section, and the menus behind it.
//
// Rendered FROM DATA: adding an indicator is a row in `items`, and connecting one
// is filling in that row's bindings.
//
// What is NOT here matters as much as what is. This row is for the four things
// you reach for while doing something else: how loud, which network, which
// headphones, how much charge. Notifications have their own tray, and media,
// performance and power are going to the dashboard, where there is room to READ
// them instead of squinting at a 28px slot. A bar that carries everything is a
// bar you stop looking at.
//
// Sound and microphone are one gauge for the same reason: they are one question,
// which is whether you can hear and whether you can be heard. A muted microphone
// raises that gauge's alert rather than costing a slot of its own.
Item {
    id: root

    // WHICH MENU, and WHETHER IT WAS ASKED FOR.
    //
    // The second argument is the difference between an open that something is
    // holding and an open that has to hold itself. A hover is incidental: it
    // says the pointer is here right now, it will say so again next frame, and
    // the menu it opened is closed by the same input going away. A tap is
    // deliberate and it is an INSTANT: it says nothing at all about the frame
    // after it, so a menu opened by one has nothing continuous behind it and
    // needs the latch at the other end (Menus.pinned).
    //
    // Both still arrive on ONE signal rather than two. Which menu is wanted is
    // the same question either way, and the answer goes to the same place; the
    // flag is a fact ABOUT the request, not a different kind of request. A
    // second signal would mean every consumer wiring up both and getting the
    // ordering between them wrong on the tap, which fires both in one gesture.
    signal requested(string key, bool deliberate)
    signal released

    // Which icon the cursor is on, "" for none.
    //
    // This is ONE source of truth on purpose. Letting each icon fire its own
    // enter and leave means that sliding from one to the next produces both, in
    // an order Qt does not promise, and the leave can undo the open that the
    // enter just did. Tracking the state and reacting to it changing is immune
    // to that: a leave only clears the key if it is still that icon's.
    property string hoveredKey: ""

    // The pointer arriving on an icon is an INCIDENTAL open: it asks for the
    // menu and goes on holding it, so it must not latch.
    onHoveredKeyChanged: hoveredKey ? root.requested(hoveredKey, false) : root.released()

    readonly property var items: [
        {
            key: "audio",
            title: "Sound",
            icon: Audio.icon(Audio.volume, Audio.muted),
            active: !Audio.muted && Audio.volume > 0,
            // The one state in this pair worth interrupting you for: a muted
            // output you hear immediately, a muted input you find out about a
            // minute into talking to nobody.
            alert: Audio.sourceMuted,
            body: soundMenu
        },
        {
            key: "network",
            title: "Network",
            icon: Network.icon(),
            // A METER while there is a signal to meter, and a glyph for the two
            // states that are not a level at all: switched off, and on but
            // joined to nothing. Four dark bars would say both of those, and
            // they are not the same thing as each other or as a weak signal.
            mark: Network.connected ? signalMark : null,
            active: Network.connected,
            alert: (Network.available && !Network.enabled) || Network.stranded,
            available: Network.available,
            body: networkMenu
        },
        {
            key: "bluetooth",
            title: "Bluetooth",
            icon: Bluetooth.statusIcon(),
            active: Bluetooth.anyConnected,
            available: Bluetooth.available,
            body: bluetoothMenu
        },
        {
            key: "settings",
            title: "Settings",
            icon: "tune",
            body: settingsMenu
        },
        {
            key: "battery",
            title: "Battery",
            icon: Battery.icon(),
            // Drawn, so the level is the level rather than the nearest of six
            // names the font happens to have, and so charging can be shown as
            // motion instead of as one more static picture.
            mark: Battery.available ? batteryMark : null,
            active: Battery.charging,
            alert: Battery.low,
            available: Battery.available,
            body: batteryMenu
        }
    ]

    // The icon item for a key, so whoever positions a menu can ask where the
    // icon actually ended up rather than recomputing a layout only this file
    // knows.
    function iconFor(key: string): Item {
        for (let i = 0; i < repeater.count; i++) {
            const item = repeater.itemAt(i);
            if (item?.key === key)
                return item;
        }
        return null;
    }

    function entryFor(key: string): var {
        return root.items.find(i => i.key === key) ?? null;
    }

    // THE WIDTH IS GIVEN, the height is asked for. The sidebar hands this group
    // the whole band so that each gauge's target can span it (StatusIcon's
    // MouseArea is the whole of why), and taking `column.implicitWidth` instead
    // would put it back to one slot and leave seventeen dead pixels either side
    // of every gauge. Height is the group's own business: it is however tall the
    // column of gauges came out.
    implicitWidth: Appearance.sizes.statusSlot
    implicitHeight: column.implicitHeight

    // A quiet container, so the indicators read as one control rather than a
    // column of loose glyphs.
    //
    // AROUND THE GAUGES, not around the item, which are no longer the same
    // rectangle. Filling the item would draw this fill the full width of the
    // band, so the bar would wear a stripe down its bottom third instead of a
    // pill around a column of icons. Pinned to the column, it is exactly the
    // shape it always was: the drawn slot plus a small padding on every side.
    G2Rect {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: column.top
        anchors.bottom: column.bottom
        anchors.topMargin: -Appearance.padding.small
        anchors.bottomMargin: -Appearance.padding.small
        width: Appearance.sizes.statusSlot + Appearance.padding.small * 2
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
    }

    // FULL WIDTH, so that the delegates in it have a full width to take. The
    // column is not what you see: what you see is a slot-wide square inside each
    // delegate, drawn where it always was because this is centred on the same
    // line the old one-slot column stood on.
    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.sizes.statusGap

        Repeater {
            id: repeater

            model: root.items

            delegate: StatusIcon {
                required property var modelData

                readonly property string key: modelData.key

                // A Column positions its children and never resizes them, so a
                // delegate left to itself would be one slot wide inside a
                // full-width column and the dead lanes would still be there.
                // Taken from the column rather than from `parent` so the
                // reference is a typed one.
                width: column.width

                icon: modelData.icon
                mark: modelData.mark ?? null
                active: modelData.active ?? false
                alert: modelData.alert ?? false
                available: modelData.available ?? true

                // Hover IS the request. Clicking is the same intent, and matters
                // for touch and for keyboard-driven opens later.
                onHoveredChanged: {
                    if (hovered)
                        root.hoveredKey = key;
                    else if (root.hoveredKey === key)
                        root.hoveredKey = "";
                }

                // A PRESS IS DELIBERATE, and on a touchscreen a press is all
                // there is: the hover above fires there too, because Qt
                // synthesises a mouse from the touch, but it is gone the instant
                // the finger lifts and it was never holding anything. This is
                // the one that says the menu was actually asked for.
                onActivated: root.requested(key, true)
            }
        }
    }

    // The drawn marks. Each takes `colour` from the indicator it sits in, which
    // is the whole contract StatusIcon asks of a mark.
    Component {
        id: signalMark

        SignalBars {
            property color colour: Appearance.colour.text

            strength: Network.activeStrength
            activeColour: colour
        }
    }

    Component {
        id: batteryMark

        BatteryMeter {
            level: Battery.percentage
            charging: Battery.charging
        }
    }

    Component {
        id: soundMenu

        SoundMenu {}
    }

    Component {
        id: settingsMenu

        IconsMenu {}
    }

    Component {
        id: batteryMenu

        BatteryMenu {}
    }

    Component {
        id: networkMenu

        NetworkMenu {}
    }

    Component {
        id: bluetoothMenu

        BluetoothMenu {}
    }
}
