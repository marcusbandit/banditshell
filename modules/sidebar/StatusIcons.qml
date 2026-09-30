pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content

Item {
    id: root

    signal requested(string key, bool deliberate)
    signal released

    property string hoveredKey: ""

    property bool menusShown: false

    onHoveredKeyChanged: {
        root.markGauge(root.hoveredKey);

        if (root.hoveredKey) {
            if (root.menusShown)
                root.requested(root.hoveredKey, false);
        } else
            root.released();
    }

    property int markedIndex: 0

    readonly property real pitch: Appearance.sizes.statusSlot + Appearance.sizes.statusGap

    function markGauge(key: string): void {
        const i = root.gauges.findIndex(g => g.key === key);
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

    readonly property var gauges: [
        {
            key: "audio",
            title: "Sound",
            icon: Audio.icon(Audio.volume, Audio.muted),
            active: !Audio.muted && Audio.volume > 0,

            alert: Audio.sourceMuted,
            body: soundMenu
        },
        {
            key: "network",
            title: "Network",
            icon: Network.icon(),

            mark: Network.carrier === "wifi" ? signalMark : null,
            active: Network.linked,

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

        {
            key: "battery",
            title: "Battery",
            icon: Battery.icon(),

            mark: batteryMark,
            active: Battery.charging,

            alarm: Battery.low,

            present: Battery.available,
            body: batteryMenu
        }
    ].filter(g => g.present ?? true)

    readonly property var items: root.gauges.filter(g => g.body !== undefined)

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

    implicitWidth: Appearance.sizes.statusSlot
    implicitHeight: column.implicitHeight

    readonly property bool boxed: fill.color.a > 0
    readonly property real sideGap: (width - (root.boxed ? fill.width : Appearance.sizes.statusSlot)) / 2
    readonly property real overhang: root.boxed ? Appearance.padding.small : 0

    G2Rect {
        id: fill

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: column.top
        anchors.bottom: column.bottom
        anchors.topMargin: -root.overhang
        anchors.bottomMargin: -root.overhang
        width: Appearance.sizes.statusSlot + Appearance.padding.small * 2
        radius: Appearance.rounding.normal

        color: "transparent"
    }

    G2Rect {
        x: column.x + (column.width - width) / 2
        y: column.y + slide.value
        width: Appearance.sizes.statusSlot
        height: Appearance.sizes.statusSlot
        radius: Appearance.rounding.normal
        color: Appearance.colour.fillStrong
        opacity: lit.value
    }

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

                readonly property bool hasMenu: modelData.body !== undefined

                width: column.width

                icon: modelData.icon
                mark: modelData.mark ?? null
                active: modelData.active ?? false
                alert: modelData.alert ?? false
                alarm: modelData.alarm ?? false
                available: modelData.available ?? true

                onHoveredChanged: {
                    if (hovered) {
                        if (hasMenu)
                            root.hoveredKey = key;
                    } else if (root.hoveredKey === key) {
                        root.hoveredKey = "";
                    }
                }

                onActivated: root.requested(key, true)

                HoverTip {
                    text: hasMenu ? "" : modelData.title
                    asked: hovered
                }
            }
        }
    }

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
