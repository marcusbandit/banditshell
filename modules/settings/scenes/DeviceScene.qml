pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings
import "keyframes.js" as Frames

Item {
    id: root

    readonly property var connected: Bluetooth.connectedDevices
    readonly property var near: Bluetooth.strangers.slice(0, 4)
    readonly property real stageHeight: Math.max(220, list.implicitHeight + Appearance.padding.large * 2)

    SceneClock {
        id: clock

        duration: 2200
        still: 0
    }

    readonly property var ping: [[0, {
                s: 0.6,
                o: 0.9
            }], [100, {
                s: 1.9,
                o: 0
            }]]

    Icon {
        anchors.centerIn: parent
        visible: !Bluetooth.enabled
        name: "bluetooth_disabled"
        size: Appearance.icon.hero
        color: Appearance.colour.textGhost
    }

    Column {
        id: list

        visible: Bluetooth.enabled
        x: Appearance.padding.large
        width: parent.width - Appearance.padding.large * 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.normal

        Repeater {
            model: root.connected

            delegate: Item {
                required property var modelData

                width: list.width
                height: Appearance.font.line.small

                Row {
                    spacing: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    Icon {
                        name: Bluetooth.icon(modelData)
                    }

                    StyledText {
                        text: modelData.name || modelData.address
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    text: modelData.batteryAvailable ? `${Math.round(modelData.battery * 100)}%` : ""
                    color: Appearance.colour.textFaint
                }
            }
        }

        Repeater {
            model: root.near

            delegate: Item {
                id: near

                required property var modelData
                required property int index

                width: list.width
                height: Appearance.font.line.small

                Row {
                    spacing: Appearance.padding.normal
                    anchors.verticalCenter: parent.verticalCenter

                    Item {
                        width: Appearance.font.iconSize
                        height: Appearance.font.iconSize

                        Repeater {
                            model: 2

                            delegate: SquircleRect {
                                required property int index

                                readonly property var f: Frames.at(root.ping, Frames.pulse(clock.value * 2.2, (near ? near.index : 0) * 0.5 + index * 1.1, 2.2), Frames.EASE_OUT)

                                anchors.centerIn: parent
                                width: Appearance.icon.normal + Appearance.padding.normal
                                height: width
                                radius: width / 2
                                cornerPower: 2
                                color: "transparent"
                                stroke: Appearance.colour.accent
                                strokeWidth: Appearance.stroke.ring
                                scale: f.s
                                opacity: clock.moving ? f.o : 0
                            }
                        }

                        Icon {
                            anchors.centerIn: parent
                            name: Bluetooth.icon(near.modelData)
                            color: Appearance.colour.textDim
                        }
                    }

                    StyledText {
                        text: near.modelData.name || near.modelData.address
                        color: Appearance.colour.textDim
                    }
                }

                StyledText {
                    anchors.right: parent.right
                    text: "nearby"
                    color: Appearance.colour.textFaint
                }
            }
        }

        StyledText {
            visible: root.connected.length === 0 && root.near.length === 0
            width: list.width
            horizontalAlignment: Text.AlignHCenter
            text: "nothing around"
            color: Appearance.colour.textFaint
        }
    }
}
