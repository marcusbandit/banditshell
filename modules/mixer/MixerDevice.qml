pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

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
            root.asks(picker, acts, 0, picker.height);
    }

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: root.selected ? Appearance.colour.fill : hover.hovered ? Appearance.colour.tile : "transparent"
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.picked()
    }

    readonly property bool picks: root.choices.length > 1

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.card
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(Appearance.font.iconSize * 1.5)
        name: root.muted ? (root.input ? "mic_off" : "no_sound") : root.node ? Audio.deviceIcon(root.node) : root.input ? "mic" : "speaker"
        size: Math.round(Appearance.font.iconSize * 1.2)
        color: root.muted ? Appearance.colour.alarm : Appearance.colour.textDim
    }

    Column {
        id: words

        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.large
        anchors.right: controls.left
        anchors.rightMargin: Appearance.padding.huge
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.hair

        Row {
            id: picker

            spacing: Appearance.padding.hair

            StyledText {
                width: Math.max(0, Math.min(implicitWidth, words.width - (chevron.visible ? chevron.width + picker.spacing : 0)))
                text: root.node ? Audio.deviceLabel(root.node) : root.input ? "No microphone" : "No output"
                color: Appearance.colour.text
                font.pixelSize: Appearance.font.size.normal
                elide: Text.ElideRight
            }

            Icon {
                id: chevron

                anchors.verticalCenter: parent.verticalCenter
                visible: root.picks
                name: "expand_more"
                size: Appearance.icon.small
                color: pickHover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
            }

            HoverHandler {
                id: pickHover

                enabled: root.picks
                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                enabled: root.picks
                onTapped: root.chooseDevice()
            }
        }

        StyledText {
            width: parent.width
            text: root.muted ? "Muted" : [root.input ? "Input" : "Output", root.node ? Audio.deviceTransport(root.node) : ""].filter(Boolean).join(", ")
            color: root.muted ? Appearance.colour.alarm : Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }

    MixerControls {
        id: controls

        span: root.width
        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.card
        anchors.verticalCenter: parent.verticalCenter

        enabled: !!root.node
        volume: root.volume
        most: root.input ? 1 : Audio.maxVolume
        muted: root.muted
        listening: root.input
        peak: root.peak
        onMoved: v => root.input ? Audio.setSourceVolume(v) : Audio.setVolume(v)
        onToggled: root.toggle()
    }
}
