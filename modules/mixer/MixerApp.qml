pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/mixer.js" as Logic

Item {
    id: root

    required property string appKey
    property bool listening: false
    property bool selected: false

    signal picked
    signal asks(Item item, var actions, real x, real y)

    readonly property var app: (root.listening ? Mixer.inputByKey : Mixer.outputByKey)[root.appKey] ?? null
    readonly property string state: root.app ? Mixer.stateOf(root.app) : "gone"
    readonly property bool sounding: root.state === "sound"
    readonly property bool muted: root.state === "muted"
    readonly property real volume: root.app ? Mixer.volumeOf(root.app) : 0
    readonly property real peak: root.app && Mixer.watching ? Mixer.peakOf(root.app) : 0
    readonly property var device: root.app ? Mixer.deviceOf(root.app) : null
    readonly property string title: root.app ? Mixer.titleOf(root.app) : ""

    readonly property string where: {
        if (!root.device)
            return "";
        if (root.listening)
            return root.device.isSink ? `Recording ${Audio.deviceLabel(root.device)}` : Audio.deviceLabel(root.device);
        return Audio.deviceLabel(root.device);
    }

    readonly property color tone: root.sounding ? (root.listening ? Appearance.colour.warning : Appearance.colour.accent) : root.muted ? Appearance.colour.alarm : Appearance.colour.textFaint

    implicitHeight: Math.max(Appearance.sizes.rowHeight, body.implicitHeight) + Appearance.padding.normal * 2

    function toggle(): void {
        if (root.app)
            Mixer.toggleMute(root.app);
    }

    function nudge(steps: int): void {
        if (root.app)
            Mixer.nudge(root.app, steps);
    }

    function deviceActions(): var {
        if (root.listening)
            return [];
        const follows = Audio.sink;
        const acts = Audio.sinks.map(sink => ({
                    icon: sink === root.device ? "check" : Audio.deviceIcon(sink),
                    label: sink === follows ? `${Audio.deviceLabel(sink)} · default` : Audio.deviceLabel(sink),
                    run: () => Mixer.route(root.app, sink === follows ? null : sink)
                }));
        return acts;
    }

    readonly property string name: root.app?.display ?? ""

    function actions(): var {
        const acts = [
            {
                icon: root.muted ? "volume_up" : "volume_off",
                label: root.muted ? `Unmute ${root.name}` : `Mute ${root.name}`,
                run: () => root.toggle()
            }
        ];
        const devices = root.deviceActions();
        if (devices.length > 1)
            acts.push({
                icon: "swap_horiz",
                label: "Play on",
                children: devices
            });
        return acts;
    }

    function chooseDevice(): void {
        const acts = root.deviceActions();
        if (!acts.length)
            return;
        root.asks(deviceButton, acts, 0, deviceButton.height);
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: root.selected ? Appearance.colour.fillStrong : hover.hovered ? Appearance.colour.fill : "transparent"
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.picked()
    }

    Item {
        id: body

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.card
        anchors.rightMargin: Appearance.padding.card
        implicitHeight: Math.max(mark.height, words.implicitHeight)

        AppMark {
            id: mark

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            size: Math.round(Appearance.font.iconSize * 1.6)
            spec: root.app ? Mixer.iconOf(root.app) : ""
            fallback: root.listening ? "mic" : "graphic_eq"
            color: Appearance.colour.textDim
            opacity: root.sounding || root.listening && !root.muted ? 1 : Appearance.opacity.disabled
        }

        Column {
            id: words

            anchors.left: mark.right
            anchors.leftMargin: Appearance.padding.large
            anchors.right: chip.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.hair

            StyledText {
                width: parent.width
                text: root.app?.display ?? ""
                color: root.sounding ? Appearance.colour.text : Appearance.colour.textDim
                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.title || root.where
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
                elide: Text.ElideRight
            }
        }

        SquircleRect {
            id: chip

            anchors.right: level.left
            anchors.rightMargin: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter

            width: chipRow.implicitWidth + Appearance.padding.normal * 2
            height: chipRow.implicitHeight + Appearance.padding.small * 2
            pill: "object"
            color: root.sounding ? (root.listening ? Appearance.colour.warningFill : Appearance.colour.accentFill) : root.muted ? Appearance.colour.alarmFill : Appearance.colour.fill

            Row {
                id: chipRow

                anchors.centerIn: parent
                spacing: Appearance.padding.small

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.sounding ? "graphic_eq" : root.muted ? (root.listening ? "mic_off" : "volume_off") : root.state === "paused" ? "pause" : root.listening ? "mic" : "volume_mute"
                    size: Appearance.icon.small
                    color: root.tone
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Logic.label(root.state, root.listening)
                    color: root.sounding || root.muted ? root.tone : Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.small
                }
            }
        }

        Item {
            id: level

            anchors.right: readout.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            width: Math.round(Math.max(Appearance.sizes.menuWidth * 0.4, root.width * 0.22))
            height: bar.implicitHeight

            Slider {
                id: bar

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter

                value: root.volume
                to: Audio.maxVolume
                warnAbove: 1
                step: Config.values.volume.step / 100
                dimmed: root.muted
                onMoved: v => Mixer.setVolume(root.app, v)
            }

            LevelMeter {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: bar.beadSize / 2
                anchors.rightMargin: bar.beadSize / 2
                anchors.top: bar.verticalCenter
                anchors.topMargin: bar.beadSize / 2 + Appearance.padding.hair
                peak: root.peak
                live: Mixer.watching && !root.muted
                color: root.listening ? Appearance.colour.warning : Appearance.colour.accent
            }
        }

        StyledText {
            id: readout

            anchors.right: deviceButton.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            width: metrics.width
            horizontalAlignment: Text.AlignRight
            text: Logic.percent(root.volume)
            color: root.muted ? Appearance.colour.textFaint : Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
        }

        TextMetrics {
            id: metrics

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.small
            text: "150%"
        }

        Button {
            id: deviceButton

            anchors.right: muteButton.left
            anchors.rightMargin: Appearance.padding.small
            anchors.verticalCenter: parent.verticalCenter

            interactive: !root.listening && Audio.sinks.length > 1
            opacity: interactive ? 1 : 0
            style: "bare"
            icon: root.device ? Audio.deviceIcon(root.device) : "speaker"
            onClicked: root.chooseDevice()
        }

        Button {
            id: muteButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            style: root.muted ? "plate" : "bare"
            alarm: root.muted
            icon: root.listening ? (root.muted ? "mic_off" : "mic") : root.muted ? "volume_off" : "volume_up"
            onClicked: root.toggle()
        }
    }
}
