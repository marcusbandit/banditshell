pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls
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

        speed: Appearance.animation.trackSpeed
        target: root.markedIndex * root.pitch
    }

    Follow {
        id: lit

        speed: Appearance.animation.revealSpeed
        target: root.hoveredKey ? 1 : 0
        epsilon: 0.005
    }

    readonly property var gauges: [
        {
            key: "audio",
            title: "Sound",
            reading: sound,
            body: soundMenu
        },
        {
            key: "network",
            title: "Network",
            reading: network,
            body: networkMenu
        },
        {
            key: "bluetooth",
            title: "Bluetooth",
            reading: bluetooth,
            body: bluetoothMenu
        },
        {
            key: "battery",
            title: "Battery",
            reading: battery,
            present: Battery.available,
            body: batteryMenu
        }
    ].filter(g => g.present ?? true)

    QtObject {
        id: sound

        readonly property string icon: Audio.icon(Audio.volume, Audio.muted)
        readonly property bool active: !Audio.muted && Audio.volume > 0
        readonly property bool alert: Audio.sourceMuted
    }

    QtObject {
        id: network

        readonly property string icon: Network.icon()
        readonly property Component mark: Network.carrier === "wifi" ? signalMark : null
        readonly property bool active: Network.linked
        readonly property bool alert: (Network.available && !Network.enabled && !Network.wiredConnected) || Network.stranded
        readonly property bool available: Network.available || Network.wiredAvailable
    }

    QtObject {
        id: bluetooth

        readonly property string icon: Bluetooth.statusIcon()
        readonly property bool active: Bluetooth.anyConnected
        readonly property bool available: Bluetooth.available
    }

    QtObject {
        id: battery

        readonly property string icon: Battery.icon()
        readonly property Component mark: batteryMark
        readonly property bool active: Battery.charging
        readonly property bool alarm: Battery.low
    }

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

    SquircleRect {
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

    SquircleRect {
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

                icon: modelData.reading.icon
                mark: modelData.reading.mark ?? null
                active: modelData.reading.active ?? false
                alert: modelData.reading.alert ?? false
                alarm: modelData.reading.alarm ?? false
                available: modelData.reading.available ?? true

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
