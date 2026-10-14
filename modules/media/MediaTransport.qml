pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Item {
    id: root

    property real zoom: 1.0

    property bool extended: false

    readonly property real glyph: Appearance.font.iconSize * root.zoom
    readonly property real ring: (Appearance.font.iconSize + Appearance.padding.normal * 2) * root.zoom

    readonly property var core: [
        {
            icon: "skip_previous",
            action: "previous",
            enabled: !!Media.active?.canGoPrevious,
            tip: "previous"
        },
        {
            icon: Media.playing ? "pause" : "play_arrow",
            action: "toggle",
            enabled: !!Media.active?.canTogglePlaying || !!Media.active?.canPlay || !!Media.active?.canPause,
            primary: true,
            tip: Media.playing ? "pause" : "play"
        },
        {
            icon: "skip_next",
            action: "next",
            enabled: !!Media.active?.canGoNext,
            tip: "next"
        }
    ]

    readonly property var shuffleButton: ({
            icon: "shuffle",
            action: "shuffle",
            enabled: Media.canShuffle,
            lit: Media.shuffle,
            small: true,
            tip: Media.shuffle ? "shuffle is on" : "shuffle is off"
        })

    readonly property var loopButton: ({
            icon: Media.loop === MprisLoopState.Track ? "repeat_one" : "repeat",
            action: "loop",
            enabled: Media.canLoop,
            lit: Media.loop !== MprisLoopState.None,
            small: true,
            tip: Media.loop === MprisLoopState.Track ? "repeating this track" : Media.loop === MprisLoopState.Playlist ? "repeating the queue" : "not repeating"
        })

    readonly property var buttons: root.extended && (Media.canShuffle || Media.canLoop) ? [root.shuffleButton].concat(root.core, [root.loopButton]) : root.core

    implicitWidth: row.implicitWidth
    implicitHeight: root.ring

    function run(action: string): void {
        switch (action) {
        case "toggle":
            Media.toggle();
            break;
        case "next":
            Media.next();
            break;
        case "previous":
            Media.previous();
            break;
        case "shuffle":
            Media.toggleShuffle();
            break;
        case "loop":
            Media.cycleLoop();
            break;
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Appearance.padding.large * root.zoom * (root.extended ? 0.75 : 1)

        Repeater {
            model: root.buttons

            delegate: Item {
                id: button

                required property var modelData

                readonly property bool small: !!button.modelData.small
                readonly property real size: button.small ? root.ring * 0.72 : root.ring

                width: button.size
                height: root.ring

                scale: press.pressed ? Appearance.press.ring : press.containsMouse ? Appearance.press.ringHover : 1

                Behavior on scale {
                    NumberAnimation {
                        duration: Appearance.animation.fast
                        easing.type: Easing.OutCubic
                    }
                }

                SquircleRect {
                    anchors.centerIn: parent
                    width: button.size
                    height: button.size
                    visible: !!button.modelData.primary
                    radius: width / 2
                    color: "transparent"
                    stroke: Appearance.colour.text
                    strokeWidth: Appearance.font.stem
                }

                Icon {
                    id: glyph

                    anchors.centerIn: parent
                    size: button.small ? root.glyph * 0.8 : root.glyph
                    name: button.modelData.icon
                    fill: button.modelData.primary ? 1 : 0
                    color: !button.modelData.enabled ? Appearance.colour.textGhost : button.small && !button.modelData.lit ? Appearance.colour.textFaint : Appearance.colour.text
                }

                SquircleRect {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: glyph.bottom
                    anchors.topMargin: -Appearance.padding.small / 2
                    width: Appearance.font.stem * 3
                    height: width
                    radius: width / 2
                    visible: button.small && !!button.modelData.lit && !!button.modelData.enabled
                    color: Appearance.colour.text
                }

                MouseArea {
                    id: press

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: button.modelData.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.run(button.modelData.action)
                }

                HoverTip {
                    text: root.extended && press.containsMouse ? button.modelData.tip : ""
                }
            }
        }
    }
}
