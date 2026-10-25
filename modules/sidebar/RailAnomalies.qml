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

    property bool batteryWanted: false

    property bool awake: false

    signal awakeEnded

    readonly property BatteryGlance battery: BatteryGlance {}

    readonly property var wanted: Anomalies.list({
        battery: root.batteryWanted && root.battery.shown,
        batteryPercent: root.battery.percent,
        charging: root.battery.charging,
        batteryIcon: root.battery.icon,
        micShown: Config.values.sidebar.status.sound,
        micStreams: root.micFresh || (Audio.sourceMuted && root.micIds.length > 0),
        micMuted: Audio.sourceMuted,
        recording: ScreenRecorder.recording,
        vpn: Tunnels.anyOn,
        awake: root.awake,
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

    readonly property var micIds: Audio.recording.filter(n => (n.properties?.["media.class"] ?? "").includes("Audio")).map(n => n.id)

    property var heardIds: []

    property bool micFresh: false

    onMicIdsChanged: {
        const news = root.micIds.some(id => !root.heardIds.includes(id));
        root.heardIds = root.micIds.slice();
        if (news) {
            root.micFresh = true;
            micMoment.restart();
        } else if (root.micIds.length === 0) {
            root.micFresh = false;
            micMoment.stop();
        }
    }

    Timer {
        id: micMoment

        interval: Math.max(1, Config.values.island.glanceSeconds) * 1000
        onTriggered: root.micFresh = false
    }

    readonly property var presses: ({
            awake: () => root.awakeEnded()
        })

    property string pointedKey: ""

    readonly property bool pointing: root.held.some(e => e.key === root.pointedKey && e.present)

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

                MouseArea {
                    anchors.fill: parent
                    enabled: mark.present && !!root.presses[mark.modelData.key]
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onContainsMouseChanged: {
                        if (containsMouse)
                            root.pointedKey = mark.modelData.key;
                        else if (root.pointedKey === mark.modelData.key)
                            root.pointedKey = "";
                    }
                    onClicked: root.presses[mark.modelData.key]()
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
