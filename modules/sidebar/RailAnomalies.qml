pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import "anomalies.js" as Anomalies

Item {
    id: root

    property string modeIcon: ""

    readonly property var wanted: Anomalies.list({
        battery: Battery.available && Config.values.sidebar.status.battery,
        batteryPercent: Battery.percent,
        charging: Battery.charging,
        batteryIcon: Battery.icon(),
        micShown: Config.values.sidebar.status.sound,
        micStreams: Audio.recording.some(n => (n.properties?.["media.class"] ?? "").includes("Audio")),
        micMuted: Audio.sourceMuted,
        recording: ScreenRecorder.recording,
        vpn: Tunnels.anyOn,
        wifiAvailable: Network.available,
        wifiOn: Network.enabled,
        bluetoothAvailable: Bluetooth.available,
        bluetoothOn: Bluetooth.enabled,
        modeIcon: root.modeIcon,
        quiet: Notifications.quieted,
        update: Update.state,
        updateMode: Config.values.sidebar.update,
        diverged: Update.diverged
    })

    property var held: []

    onWantedChanged: root.held = Anomalies.merge(root.held, root.wanted)

    Component.onCompleted: root.held = Anomalies.merge([], root.wanted)

    function entryOf(key: string): var {
        return root.held.find(e => e.key === key) ?? null;
    }

    function toneColour(tone: string): color {
        return tone === "alarm" ? Appearance.colour.alarm : tone === "accent" ? Appearance.colour.accent : Appearance.colour.textDim;
    }

    implicitHeight: column.implicitHeight

    Column {
        id: column

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        spacing: 0

        Repeater {
            model: ScriptModel {
                values: root.held
                objectProp: "key"
            }

            delegate: Item {
                id: mark

                required property var modelData

                readonly property var entry: root.entryOf(mark.modelData.key)
                readonly property bool present: mark.entry?.present ?? false

                width: column.width
                height: Math.round((Appearance.sizes.statusSlot + Appearance.sizes.statusGap) * grow.value)
                opacity: grow.value

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(Appearance.sizes.statusGap / 2)
                    height: Appearance.sizes.statusSlot
                    name: mark.entry?.icon ?? mark.modelData.icon
                    fill: 1
                    color: root.toneColour(mark.entry?.tone ?? mark.modelData.tone)
                }

                Follow {
                    id: grow

                    target: mark.present ? 1 : 0
                    speed: Appearance.animation.revealSpeed
                    epsilon: 0.005
                }

                Connections {
                    target: grow

                    function onSettledChanged(): void {
                        if (grow.settled && !mark.present)
                            root.held = Anomalies.without(root.held, mark.modelData.key);
                    }
                }
            }
        }
    }
}
