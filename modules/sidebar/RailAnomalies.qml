pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "anomalies.js" as Anomalies

Item {
    id: root

    property string modeIcon: ""

    property bool batteryWanted: false

    property bool awake: false

    property real room: Infinity

    signal markPressed(var opens)

    readonly property BatteryGlance battery: BatteryGlance {}

    readonly property var reading: ({
        battery: root.batteryWanted && root.battery.shown,
        batteryPercent: root.battery.percent,
        batteryLow: root.battery.low,
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
        diverged: Update.diverged,
        layout: Keymap.several ? Keymap.layout : "",
        layoutAway: Keymap.index > 0,
        layoutName: Keymap.name
    })

    readonly property var split: Anomalies.split(root.reading, Anomalies.slotsIn(root.room, Appearance.sizes.statusSlot + Appearance.sizes.statusGap))

    readonly property var wanted: root.split.kept

    readonly property var dropped: root.split.dropped

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

    property string pointedKey: ""

    readonly property bool pointing: root.pointedKey !== ""

    property var held: []

    onWantedChanged: root.held = Anomalies.merge(root.held, root.wanted)

    Component.onCompleted: root.held = Anomalies.merge([], root.wanted)

    function entryOf(key: string): var {
        return root.held.find(e => e.key === key) ?? null;
    }

    function toneColour(tone: string): color {
        return tone === "alarm" ? Appearance.colour.alarm : tone === "warning" ? Appearance.colour.warning : tone === "notice" ? Appearance.colour.text : Appearance.colour.textDim;
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
                readonly property string text: mark.entry?.text ?? mark.modelData.text ?? ""

                width: column.width
                height: Math.round((Appearance.sizes.statusSlot + Appearance.sizes.statusGap) * grow.value)
                opacity: grow.value

                Icon {
                    id: glyph

                    readonly property bool dotted: mark.entry?.dot ?? mark.modelData.dot ?? false

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(Appearance.sizes.statusGap / 2)
                    height: Appearance.sizes.statusSlot
                    visible: !mark.text
                    name: mark.entry?.icon ?? mark.modelData.icon ?? ""
                    fill: glyph.dotted ? 0 : 1
                    color: root.toneColour(mark.entry?.tone ?? mark.modelData.tone)

                    SquircleRect {
                        visible: glyph.dotted
                        pill: "object"
                        width: Math.round(glyph.size * 0.26)
                        height: width
                        x: Math.round((glyph.width - width) / 2)
                        y: Math.round((glyph.height - height) / 2 - glyph.size * 0.09)
                        color: glyph.color
                    }
                }

                readonly property bool pointed: area.enabled && area.containsMouse

                onPointedChanged: {
                    if (mark.pointed)
                        root.pointedKey = mark.modelData.key;
                    else if (root.pointedKey === mark.modelData.key)
                        root.pointedKey = "";
                }

                Component.onDestruction: {
                    if (root.pointedKey === mark.modelData.key)
                        root.pointedKey = "";
                }

                MouseArea {
                    id: area

                    anchors.fill: parent
                    enabled: mark.present
                    hoverEnabled: true
                    cursorShape: area.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.markPressed(mark.entry.opens)

                    HoverTip {
                        text: area.enabled ? Anomalies.tip(mark.entry) : ""
                        host: mark
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: Math.round(Appearance.sizes.statusGap / 2)
                    height: Appearance.sizes.statusSlot
                    visible: !!mark.text
                    verticalAlignment: Text.AlignVCenter
                    text: mark.text
                    color: root.toneColour(mark.entry?.tone ?? mark.modelData.tone)
                    font.pixelSize: Appearance.font.size.small
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

        Item {
            id: more

            readonly property int live: root.dropped.length
            readonly property bool shown: more.live > 0

            property int count: 0

            onLiveChanged: if (more.live > 0)
                more.count = more.live

            Component.onCompleted: more.count = more.live

            width: column.width
            height: Math.round((Appearance.sizes.statusSlot + Appearance.sizes.statusGap) * swell.value)
            opacity: swell.value
            visible: swell.value > 0.005

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                text: "+" + more.count
                color: Appearance.colour.textDim
            }

            readonly property bool pointed: tip.hovered && more.shown && more.enabled

            onPointedChanged: {
                if (more.pointed)
                    root.pointedKey = "more";
                else if (root.pointedKey === "more")
                    root.pointedKey = "";
            }

            HoverTip {
                id: tip

                text: more.shown && more.enabled ? Anomalies.droppedTitle(root.dropped) : ""
                host: more
            }

            Follow {
                id: swell

                target: more.shown ? 1 : 0
                speed: Appearance.animation.revealSpeed
                epsilon: 0.005
            }
        }
    }
}
