pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

// The system status section, and the menus behind it.
//
// Rendered FROM DATA: adding an indicator is a row in `items`, and connecting one
// is filling in that row's bindings. Sound and battery are live; the rest carry
// demo content, which is deliberate. A grey skeleton tells you the panel has the
// right SHAPE. Rows that look like the real thing tell you whether the DESIGN
// holds at the density the real thing will have, and that is the question worth
// answering before writing the service.
Item {
    id: root

    signal requested(string key)
    signal released

    // Which icon the cursor is on, "" for none.
    //
    // This is ONE source of truth on purpose. Letting each icon fire its own
    // enter and leave means that sliding from one to the next produces both, in
    // an order Qt does not promise, and the leave can undo the open that the
    // enter just did. Tracking the state and reacting to it changing is immune
    // to that: a leave only clears the key if it is still that icon's.
    property string hoveredKey: ""

    onHoveredKeyChanged: hoveredKey ? root.requested(hoveredKey) : root.released()

    readonly property var items: [
        {
            key: "audio",
            title: "Sound",
            icon: Audio.icon(Audio.volume, Audio.muted),
            active: !Audio.muted && Audio.volume > 0,
            body: soundMenu
        },
        {
            key: "mic",
            title: "Microphone",
            icon: Audio.sourceMuted ? "mic_off" : "mic",
            active: !Audio.sourceMuted,
            alert: Audio.sourceMuted,
            body: micMenu
        },
        {
            key: "network",
            title: "Network",
            icon: Network.icon(Network.activeStrength),
            active: Network.connected,
            alert: Network.available && !Network.enabled,
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
            key: "media",
            title: "Media",
            icon: Media.playing ? "play_arrow" : "music_note",
            active: Media.playing,
            available: Media.available,
            body: mediaMenu
        },
        {
            key: "system",
            title: "System",
            icon: "speed",
            alert: SysInfo.temperature >= 80,
            body: systemMenu
        },
        {
            key: "battery",
            title: "Battery",
            icon: Battery.icon(),
            active: Battery.charging,
            alert: Battery.low,
            available: Battery.available,
            body: batteryMenu
        },
        {
            key: "power",
            title: "Power",
            icon: "power_settings_new",
            body: powerMenu
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

    implicitWidth: column.implicitWidth
    implicitHeight: column.implicitHeight

    // A quiet container, so the indicators read as one control rather than a
    // column of loose glyphs.
    G2Rect {
        anchors.fill: parent
        anchors.margins: -Appearance.padding.small
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
    }

    Column {
        id: column

        anchors.centerIn: parent
        spacing: Appearance.sizes.statusGap

        Repeater {
            id: repeater

            model: root.items

            delegate: StatusIcon {
                required property var modelData

                readonly property string key: modelData.key

                icon: modelData.icon
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
                onActivated: root.requested(key)
            }
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
        id: micMenu

        DemoMenu {
            footer: "input routing is not wired up yet"
            rows: [
                {
                    icon: "graphic_eq",
                    label: "Noise suppression",
                    detail: "RNNoise",
                    toggle: true
                },
                {
                    icon: "hearing",
                    label: "Monitor input",
                    toggle: false
                },
                {
                    icon: "settings_voice",
                    label: "Built-in Microphone",
                    detail: "default",
                    selected: true
                }
            ]
        }
    }

    Component {
        id: networkMenu

        NetworkMenu {}
    }

    Component {
        id: bluetoothMenu

        BluetoothMenu {}
    }

    Component {
        id: mediaMenu

        MediaMenu {}
    }

    Component {
        id: systemMenu

        SystemMenu {}
    }

    Component {
        id: powerMenu

        PowerMenu {}
    }
}
