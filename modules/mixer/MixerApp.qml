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
    readonly property bool metered: !root.listening || !root.device?.isSink
    readonly property var device: root.app ? Mixer.deviceOf(root.app) : null
    readonly property string title: root.app ? Mixer.titleOf(root.app) : ""

    readonly property string where: {
        if (!root.device)
            return "";
        if (root.listening)
            return `from ${Audio.deviceLabel(root.device)}`;
        return `on ${Audio.deviceLabel(root.device)}`;
    }

    readonly property color tone: root.sounding ? (root.listening ? Appearance.colour.warning : Appearance.colour.accent) : root.muted ? Appearance.colour.alarm : Appearance.colour.textFaint
    readonly property bool picks: !root.listening && Audio.sinks.length > 1
    readonly property bool showsWhere: root.listening || root.picks

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
        root.asks(whereLabel, acts, 0, whereLabel.height);
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
            size: Math.round(Appearance.font.iconSize * 1.5)
            spec: root.app ? Mixer.iconOf(root.app) : ""
            fallback: root.listening ? "mic" : "music_note"
            color: Appearance.colour.textDim
            opacity: root.sounding ? 1 : Appearance.opacity.disabled
        }

        Column {
            id: words

            anchors.left: mark.right
            anchors.leftMargin: Appearance.padding.large
            anchors.right: controls.left
            anchors.rightMargin: Appearance.padding.huge
            anchors.verticalCenter: parent.verticalCenter
            spacing: Appearance.padding.hair

            Item {
                width: parent.width
                height: nameText.implicitHeight

                StyledText {
                    id: nameText

                    width: Math.min(implicitWidth, parent.width)
                    text: root.name
                    color: root.sounding ? Appearance.colour.text : Appearance.colour.textDim
                    font.pixelSize: Appearance.font.size.normal
                    elide: Text.ElideRight
                }

                StyledText {
                    anchors.left: nameText.right
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.right: parent.right
                    anchors.baseline: nameText.baseline
                    visible: text !== "" && width > Appearance.padding.huge * 2
                    text: root.title
                    color: Appearance.colour.textFaint
                    font.pixelSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }
            }

            Row {
                width: parent.width
                spacing: Appearance.padding.normal

                StyledText {
                    id: stateText

                    text: Logic.label(root.state, root.listening)
                    color: root.tone
                    font.pixelSize: Appearance.font.size.small
                }

                Row {
                    id: whereLabel

                    visible: root.showsWhere && root.where !== ""
                    spacing: Appearance.padding.hair

                    StyledText {
                        width: Math.max(0, Math.min(implicitWidth, words.width - stateText.width - Appearance.padding.normal - (chevron.visible ? chevron.width + whereLabel.spacing : 0)))
                        text: root.where
                        color: whereHover.hovered && root.picks ? Appearance.colour.text : Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                        elide: Text.ElideRight
                    }

                    Icon {
                        id: chevron

                        anchors.verticalCenter: parent.verticalCenter
                        visible: root.picks
                        name: "expand_more"
                        size: Appearance.icon.small
                        color: whereHover.hovered ? Appearance.colour.text : Appearance.colour.textFaint
                    }

                    HoverHandler {
                        id: whereHover

                        enabled: root.picks
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        enabled: root.picks
                        onTapped: root.chooseDevice()
                    }
                }
            }
        }

        MixerControls {
            id: controls

            span: root.width
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            volume: root.volume
            muted: root.muted
            listening: root.listening
            peak: root.peak
            metered: root.metered
            onMoved: v => Mixer.setVolume(root.app, v)
            onToggled: root.toggle()
        }
    }
}
