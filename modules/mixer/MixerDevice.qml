pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/mixer.js" as Logic

Item {
    id: root

    property bool input: false
    property bool selected: false

    signal picked
    signal asks(Item item, var actions, real x, real y)

    readonly property var node: root.input ? Audio.source : Audio.sink
    readonly property bool muted: root.input ? Audio.sourceMuted : Audio.muted
    readonly property real volume: root.input ? Audio.sourceVolume : Audio.volume
    readonly property real peak: Mixer.watching ? Mixer.watchOf(root.node)?.monitor.peak ?? 0 : 0
    readonly property var choices: root.input ? Audio.sources : Audio.sinks

    implicitHeight: Math.max(Appearance.sizes.rowHeight, words.implicitHeight) + Appearance.padding.normal * 2

    function toggle(): void {
        if (root.input)
            Audio.toggleSourceMute();
        else
            Audio.toggleMute();
    }

    function nudge(steps: int): void {
        const v = root.volume + steps * Config.values.volume.step / 100;
        if (root.input)
            Audio.setSourceVolume(v);
        else
            Audio.setVolume(v);
    }

    readonly property string name: root.node ? Audio.deviceLabel(root.node) : ""

    function deviceActions(): var {
        return root.choices.map(n => ({
                    icon: n === root.node ? "check" : Audio.deviceIcon(n),
                    label: Audio.deviceLabel(n),
                    run: () => root.input ? Audio.setSource(n) : Audio.setSink(n)
                }));
    }

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
                label: root.input ? "Listen with" : "Play on",
                children: devices
            });
        return acts;
    }

    function chooseDevice(): void {
        const acts = root.deviceActions();
        if (acts.length > 1)
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

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.card
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(Appearance.font.iconSize * 1.6)
        name: root.muted ? (root.input ? "mic_off" : "no_sound") : root.node ? Audio.deviceIcon(root.node) : root.input ? "mic" : "speaker"
        size: Math.round(Appearance.font.iconSize * 1.3)
        color: root.muted ? Appearance.colour.alarm : Appearance.colour.text
    }

    Column {
        id: words

        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.large
        anchors.right: level.left
        anchors.rightMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.hair

        StyledText {
            width: parent.width
            text: root.node ? Audio.deviceLabel(root.node) : root.input ? "No microphone" : "No output"
            color: Appearance.colour.text
            font.pixelSize: Appearance.font.size.normal
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: [root.input ? "Input" : "Output", root.muted ? "muted" : root.node ? Audio.deviceTransport(root.node) : ""].filter(Boolean).join(" · ")
            color: root.muted ? Appearance.colour.alarm : Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
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

            enabled: !!root.node
            value: root.volume
            to: Math.max(root.input ? 1 : Audio.maxVolume, root.volume)
            warnAbove: 1
            step: Config.values.volume.step / 100
            dimmed: root.muted
            onMoved: v => root.input ? Audio.setSourceVolume(v) : Audio.setVolume(v)
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
            color: root.input ? Appearance.colour.warning : Appearance.colour.accent
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

        style: "bare"
        icon: "swap_horiz"
        interactive: root.choices.length > 1
        opacity: root.choices.length > 1 ? 1 : 0
        onClicked: root.chooseDevice()
    }

    Button {
        id: muteButton

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.card
        anchors.verticalCenter: parent.verticalCenter

        style: root.muted ? "plate" : "bare"
        alarm: root.muted
        enabled: !!root.node
        icon: root.input ? (root.muted ? "mic_off" : "mic") : root.muted ? "volume_off" : "volume_up"
        onClicked: root.toggle()
    }
}
