pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string screen

    readonly property int block: Appearance.sizes.wsBlock
    readonly property int step: block + Appearance.sizes.wsBlockGap

    readonly property int perRow: Math.max(1, Math.floor((root.width + Appearance.sizes.wsBlockGap) / root.step))

    property int hovered: -1

    implicitHeight: layout.total

    WorkspaceModel {
        id: layout

        screen: root.screen
        base: root.block

        pitch: root.step
        perRow: root.perRow
        gap: Appearance.sizes.wsBlockGap * 2
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
                y: (root.block - root.block / 2) / 2
                width: root.block / 2
                height: root.block / 2
                radius: 0
                color: slotItem.isActive ? Appearance.colour.accent : Appearance.colour.textGhost

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.fast
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: slotItem.info.marks
                }

                delegate: SquircleRect {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool focused: Hypr.isFocused(cell.modelData.client)

                    x: (cell.modelData.col ?? cell.index) * root.step
                    y: (cell.modelData.row ?? 0) * root.step
                    width: root.block
                    height: root.block
                    radius: 0

                    color: cell.focused ? Appearance.colour.accent : slotItem.isActive ? Appearance.colour.accentFill : mouse.containsMouse ? Appearance.colour.text : Appearance.colour.textFaint

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
                        onClicked: Hypr.focusClient(cell.modelData.client)
                    }
                }
            }

        }
    }
}
