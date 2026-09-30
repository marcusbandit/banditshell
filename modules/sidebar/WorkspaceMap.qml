pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string screen

    readonly property int bar: Appearance.sizes.wsMapBar
    readonly property int pitch: bar + Appearance.sizes.wsMapGap
    readonly property real span: width - Appearance.sizes.band

    readonly property real floor: Appearance.sizes.wsEmptyReach

    property int hovered: -1

    implicitHeight: layout.total

    function reachOf(client: var, hovered: bool): real {
        const w = client?.lastIpcObject?.size?.[0] ?? 0;
        const screen = root.Screen.width || 1;
        const f = Math.max(root.floor, Math.min(1, w / screen)) + (hovered ? Appearance.sizes.wsHover : 0);
        return Math.round(root.span * f);
    }

    WorkspaceModel {
        id: layout

        screen: root.screen
        base: root.bar
        pitch: root.pitch
    }

    Repeater {
        model: layout.count

        delegate: Item {
            id: slotItem

            required property int index
            readonly property var info: layout.slots[index] ?? ({
                    id: layout.idAt(index),
                    windows: [],
                    marks: []
                })
            readonly property var geom: layout.at(index)

            readonly property bool isActive: layout.active === slotItem.info.id
            readonly property bool isOccupied: slotItem.info.windows.length > 0

            y: slotItem.geom.y
            width: root.width
            height: slotItem.geom.h

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: root.hovered = slotItem.index
                onExited: if (root.hovered === slotItem.index)
                    root.hovered = -1
                onClicked: Hypr.switchTo(slotItem.info.id)
            }

            SquircleRect {
                visible: !slotItem.isOccupied
                x: 0
                width: Math.round(root.span * root.floor)
                height: root.bar
                radius: root.bar / 2
                topLeftRadius: 0
                bottomLeftRadius: 0
                color: slotItem.isActive ? Appearance.colour.accent : Appearance.colour.textGhost

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: slotItem.info.windows
                }

                delegate: SquircleRect {
                    id: windowBar

                    required property var modelData
                    required property int index
                    readonly property bool focused: Hypr.isFocused(modelData)

                    x: 0
                    y: index * root.pitch
                    width: root.reachOf(modelData, root.hovered === slotItem.index)
                    height: root.bar

                    radius: root.bar / 2
                    topLeftRadius: 0
                    bottomLeftRadius: 0

                    color: windowBar.focused ? Appearance.colour.accent : slotItem.isActive ? Appearance.colour.accentFill : mouse.containsMouse ? Appearance.colour.text : Appearance.colour.textFaint

                    Behavior on width {
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.anim.fast
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.hovered = slotItem.index
                        onExited: if (root.hovered === slotItem.index)
                            root.hovered = -1
                        onClicked: Hypr.focusClient(windowBar.modelData)
                    }
                }
            }

        }
    }
}
