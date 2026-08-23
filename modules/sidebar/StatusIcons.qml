pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

// The system status section, and the menus behind it.
//
// Rendered FROM DATA: adding an indicator is a row in `gauges`, and connecting
// one is filling in that row's bindings.
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

    // THE DRAWN COLUMN, top to bottom. An entry that carries a `body` has a
    // menu; the registry of menus below is derived from that, so the column
    // and the registry cannot drift apart.
    readonly property var gauges: [
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
            // A METER ONLY WHILE THE RADIO IS THE THING CARRYING. Signal
            // strength is a property of a wireless link and of nothing else: on
            // a cabled machine there is no level to draw, and drawing the idle
            // radio's level instead would meter the one part of the network
            // that is not in use. The glyph covers every state that is not a
            // level, which now includes the wire.
            mark: Network.carrier === "wifi" ? signalMark : null,
            active: Network.linked,
            // The radio being switched off is worth saying, right up until
            // something else is carrying: a desktop on a cable with its wifi
            // deliberately off is not a machine with a problem, and a bar that
            // lights an accent over it is crying wolf about a choice.
            alert: (Network.available && !Network.enabled && !Network.wiredConnected) || Network.stranded,
            available: Network.available || Network.wiredAvailable,
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
        // THERE IS NO SETTINGS GAUGE HERE, AND THERE MUST NOT BE ONE AGAIN.
        //
        // It was removed on purpose, and the reason is what the four remaining
        // gauges have in common: each answers a GLANCE. How loud, which
        // network, is it connected, how much charge, all of it a menu's worth
        // of state that a hover can hold open and a look can finish. What lived
        // behind the settings gauge grew into PAGES of the settings panel, and
        // a place is not a glance: it is somewhere you go and stay. A door
        // standing in a row of gauges reads as a fifth gauge, so a hand goes to
        // it expecting the same kind of answer and gets a whole panel instead.
        //
        // Settings has three ways in that are all better than a slot in this
        // column: the bottom-right corner (its own place, and the page grows
        // out of exactly the point you pressed), `banditshell settings`, and
        // therefore any keybind. Nothing was lost by taking the slot back; the
        // bar got shorter, which is the point of a bar that shows nothing at a
        // glance.
        {
            key: "battery",
            title: "Battery",
            icon: Battery.icon(),
            // Drawn, so the level is the level rather than the nearest of six
            // names the font happens to have, and so charging can be shown as
            // motion instead of as one more static picture.
            mark: batteryMark,
            active: Battery.charging,
            // Alarm, not alert, and the only one in the column: every other
            // gauge reports something you can put right when you notice it.
            alarm: Battery.low,
            // NOT DIMMED ON A DESKTOP: GONE. See `present` below.
            present: Battery.available,
            body: batteryMenu
        }
    ].filter(g => g.present ?? true)

    // WHAT `present` MEANS, AND WHY IT IS NOT `available`.
    //
    // `available` is a gauge that this machine could have and this machine's
    // copy of is not there: no bluetooth adapter, no wifi card. It stays in the
    // column, drawn faint, because the absence is news. Pointing at it opens a
    // menu that says what is missing and, for most of them, offers the switch
    // that would bring it back.
    //
    // A desktop's battery is not that. It is not missing, it was never a
    // question: the machine runs on mains and it will still be running on mains
    // tomorrow. A gauge for it was a slot in the bar, a hover target, a menu
    // page, a key in the CLI and a page kept warm in memory, all spent saying
    // "there is no battery" to somebody who has known that since they bought
    // the thing. So the row is filtered out of the list entirely, and because
    // the menu registry, the sidebar's item list and the IPC keys are all
    // derived from this same array, every one of those disappears with it
    // rather than needing to be told separately.


    // THE MENU REGISTRY: what the sidebar folds into menuItems, what the CLI
    // lists, and the only keys openMenu can resolve. DERIVED, not written out
    // a second time: an entry is a menu entry exactly when it has a menu, so
    // the settings gauge falls out of here by the same fact that makes its
    // hover silent, and adding a gauge can never update one list and forget
    // the other.
    readonly property var items: root.gauges.filter(g => g.body !== undefined)

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

            model: root.gauges

            delegate: StatusIcon {
                required property var modelData

                readonly property string key: modelData.key


                // Whether anything answers a hover here. Every gauge in the
                // column says yes today, the one that did not having been
                // removed, and this stays because it is a fact about the
                // ENTRY's shape rather than about the list's current contents:
                // an entry is a menu entry exactly when it has a menu, and the
                // registry above is filtered by the same test. A gauge added
                // tomorrow without a body is silent on hover by construction
                // rather than by somebody remembering.
                readonly property bool hasMenu: modelData.body !== undefined

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
                alarm: modelData.alarm ?? false
                available: modelData.available ?? true

                // Hover IS the request. Clicking is the same intent, and matters
                // for touch and for keyboard-driven opens later.
                //
                // Only for a gauge with a menu to hold: a bodyless entry never
                // enters `hoveredKey` at all, rather than entering it and
                // having the request fail downstream, because `hoveredKey`
                // means "the icon whose menu the pointer is holding open" and
                // a key that can never resolve to a menu would make that a
                // lie. Leaving is unguarded on purpose; it can only clear a
                // key this gauge set.
                onHoveredChanged: {
                    if (hovered) {
                        if (hasMenu)
                            root.hoveredKey = key;
                    } else if (root.hoveredKey === key) {
                        root.hoveredKey = "";
                    }
                }

                // A PRESS IS DELIBERATE, and on a touchscreen a press is all
                // there is: the hover above fires there too, because Qt
                // synthesises a mouse from the touch, but it is gone the instant
                // the finger lifts and it was never holding anything. This is
                // the one that says the menu was actually asked for.
                onActivated: root.requested(key, true)

                // The gauges refuse a tooltip (StatusIcon's closing note):
                // hovering one opens a menu whose first line is its name, so a
                // label would say the same word twice. That argument needs the
                // menu, so it is asked of the entry rather than assumed: a
                // bodyless gauge opens nothing on hover, which makes it a bare
                // mark, and a bare mark has to say its own name somehow.
                HoverTip {
                    text: hasMenu ? "" : modelData.title
                    asked: hovered
                }
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
            // The colour arrives through `colour` like every mark's does; this
            // is the cue to wear it on the well and breathe. See BatteryMeter.
            low: Battery.low
        }
    }

    Component {
        id: soundMenu

        SoundMenu {}
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
