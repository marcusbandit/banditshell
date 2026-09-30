pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import qs.config
import qs.components
import qs.modules
import qs.services

Item {
    id: root

    property bool active: true

    property string output: ""

    property int previewDots: 0

    readonly property int dots: root.previewDots > 0 ? root.previewDots : field.text.length

    Follow {
        id: reveal

        speed: Appearance.sizes.lockReveal
        target: root.active ? 1 : 0

        epsilon: 0.002
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Image {
        id: paper

        anchors.fill: parent

        source: Wallpaper.enabled ? Wallpaper.faceOf(Wallpaper.currentOn(root.output)) : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true

        sourceSize.width: Math.round(root.width * Screen.devicePixelRatio)
        sourceSize.height: Math.round(root.height * Screen.devicePixelRatio)
        visible: false
    }

    MultiEffect {
        anchors.fill: parent
        source: paper
        visible: paper.status === Image.Ready

        blurEnabled: true
        blurMax: 64
        blur: reveal.value * Appearance.sizes.lockBlur
        brightness: -reveal.value * Appearance.sizes.lockDim
        saturation: -reveal.value * Appearance.sizes.lockDesaturate
        autoPaddingEnabled: false
    }

    Chassis {
        id: chassis

        anchors.fill: parent
    }

    Icon {
        visible: chassis.sidebar
        x: (chassis.barWidth - width) / 2
        anchors.verticalCenter: parent.verticalCenter

        name: "lock"
        size: Appearance.font.iconSize
        color: Appearance.colour.textFaint
        opacity: reveal.value
    }

    Item {
        id: content

        x: chassis.holeX
        y: chassis.holeY
        width: chassis.holeWidth
        height: chassis.holeHeight

        opacity: reveal.value

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter

            anchors.verticalCenterOffset: (1 - reveal.value) * Appearance.padding.huge

            spacing: Appearance.padding.small

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "HH:mm")
                font.pixelSize: Appearance.font.size.large
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Qt.formatDateTime(clock.date, "dddd d MMMM").toUpperCase()
                font.pixelSize: Appearance.font.size.small
                color: Appearance.colour.textFaint
            }

            Item {
                width: 1
                height: Appearance.padding.huge
            }

            SquircleRect {
                anchors.horizontalCenter: parent.horizontalCenter

                width: Appearance.sizes.lockField
                height: Appearance.sizes.lockFieldHeight
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                stroke: Lock.failed ? Appearance.colour.accent : Appearance.colour.separator
                strokeWidth: Appearance.font.stem

                TextInput {
                    id: field

                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal

                    verticalAlignment: TextInput.AlignVCenter
                    horizontalAlignment: TextInput.AlignHCenter
                    echoMode: TextInput.NoEcho
                    cursorVisible: false
                    clip: true

                    enabled: !Lock.busy && !Lock.exhausted

                    font.family: Appearance.font.family
                    font.pixelSize: Appearance.font.size.small
                    renderType: Text.NativeRendering
                    color: Appearance.colour.text
                    selectionColor: Appearance.colour.accent
                    selectedTextColor: Appearance.colour.accentText

                    onAccepted: {
                        if (!field.text)
                            return;
                        Lock.submit(field.text);
                        field.text = "";
                    }

                    Component.onCompleted: Qt.callLater(field.forceActiveFocus)

                    Connections {
                        function onActiveChanged(): void {
                            if (root.active)
                                Qt.callLater(field.forceActiveFocus);
                        }

                        target: root
                    }

                    StyledText {
                        anchors.centerIn: parent

                        visible: root.dots === 0
                        text: Lock.user
                        color: Appearance.colour.textGhost
                        font.pixelSize: Appearance.font.size.small
                    }
                }

                Item {
                    anchors.fill: parent
                    anchors.leftMargin: Appearance.padding.normal
                    anchors.rightMargin: Appearance.padding.normal
                    clip: true

                    Row {
                        anchors.centerIn: parent
                        spacing: Appearance.padding.small

                        Repeater {
                            model: root.dots

                            delegate: Icon {
                                name: "circle"
                                size: Appearance.sizes.lockDot

                                fill: 1
                                color: Lock.failed ? Appearance.colour.accent : Appearance.colour.text

                                scale: 0
                                opacity: 0

                                Component.onCompleted: {
                                    scale = 1;
                                    opacity = 1;
                                }

                                Behavior on scale {
                                    NumberAnimation {
                                        duration: Appearance.anim.normal
                                        easing.type: Easing.OutCubic
                                    }
                                }

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.anim.normal
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter

                text: Lock.message
                font.pixelSize: Appearance.font.size.small
                color: Lock.failed ? Appearance.colour.accent : Appearance.colour.textFaint
                opacity: Lock.message ? 1 : 0
            }
        }
    }
}
