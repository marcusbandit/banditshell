pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Mpris
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Flow {
    id: root

    spacing: Appearance.padding.small

    Repeater {
        model: Media.players

        delegate: Item {
            id: chip

            required property MprisPlayer modelData

            readonly property bool current: chip.modelData === Media.active
            readonly property bool alone: Media.players.length < 2
            readonly property string name: chip.modelData.identity || "player"

            width: Math.max(height, content.implicitWidth + Appearance.padding.normal * 2)
            height: Math.max(Appearance.sizes.minTarget, content.implicitHeight + Appearance.padding.small)

            scale: pressScale.value

            Follow {
                id: pressScale

                target: press.pressed ? Appearance.press.plate : 1
                speed: Appearance.animation.revealSpeed
                epsilon: Appearance.animation.fadeEpsilon
                startsAtTarget: true
            }

            SquircleRect {
                anchors.fill: parent
                pill: "object"
                color: chip.current && !chip.alone ? Appearance.colour.fillStrong : press.containsMouse ? Appearance.colour.fill : "transparent"
                visible: !chip.alone || press.containsMouse
            }

            Row {
                id: content

                anchors.centerIn: parent
                spacing: Appearance.padding.small

                AppMark {
                    anchors.verticalCenter: parent.verticalCenter
                    size: Appearance.font.iconSize
                    spec: AppIcons.markFor(chip.modelData.desktopEntry || chip.name.toLowerCase(), "")
                    fallback: "music_note"
                    color: chip.current ? Appearance.colour.text : Appearance.colour.textDim
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.current
                    text: chip.name
                    color: Appearance.colour.text
                }

                Equalizer {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: chip.modelData.isPlaying
                    playing: chip.modelData.isPlaying
                    color: chip.current ? Appearance.colour.text : Appearance.colour.textDim
                }
            }

            MouseArea {
                id: press

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    if (chip.current && chip.modelData.canRaise)
                        chip.modelData.raise();
                    else
                        Media.choose(chip.modelData);
                }
            }

            HoverTip {
                text: press.containsMouse ? (chip.current ? (chip.modelData.canRaise ? `open ${chip.name}` : "") : `show ${chip.name}${chip.modelData.trackTitle ? `: ${chip.modelData.trackTitle}` : ""}`) : ""
            }
        }
    }
}
