pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// STYLE: blocks. One square per window, one row per workspace, on the grid.
//
// The shell's face is a pixel font whose every metric sits on a 120-unit lattice,
// and this is that idea taken literally: no glyphs, no plates, no curves. A
// workspace is a row of blocks, a window is a block, and where you are is the row
// that is lit. It is the smallest the column can be and still say everything the
// other styles say.
//
// TRUE 90 DEGREE CORNERS, which is the one case where a square corner is right
// rather than lazy (see ~/.claude/rules/g2-corners.md): at 8px a radius is a
// rounding error with an opinion, and the whole point is the grid.
Item {
    id: root

    readonly property int block: Appearance.sizes.wsBlock
    readonly property int step: block + Appearance.sizes.wsBlockGap

    // Rows are a single line of blocks, so a slot is one block tall whatever it
    // holds: the count runs sideways, not down.
    property int hovered: -1

    implicitHeight: layout.total

    WorkspaceModel {
        id: layout

        base: root.block
        pitch: 0
        gap: Appearance.sizes.wsBlockGap * 2
    }

    Repeater {
        model: layout.count

        delegate: Item {
            id: slotItem

            required property int index
            readonly property var info: layout.slots[index] ?? ({
                    id: index + 1,
                    windows: [],
                    rest: 0
                })
            readonly property var geom: layout.at(index)
            readonly property bool isActive: Hypr.activeId === slotItem.info.id
            readonly property bool isOccupied: slotItem.info.windows.length > 0 || slotItem.info.rest > 0

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

            // An empty workspace: a quarter block, still on the grid, still in the
            // row it belongs to. A place you can go, said as quietly as the grid
            // allows.
            G2Rect {
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
                    values: slotItem.info.windows
                }

                delegate: G2Rect {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool focused: Hypr.isFocused(modelData)

                    x: index * root.step
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
                        onClicked: Hypr.focusClient(cell.modelData)
                    }
                }
            }

            // The ones past the cap: a half block after the last one, so an
            // overflowing workspace is capped rather than truncated silently.
            G2Rect {
                visible: slotItem.info.rest > 0
                x: slotItem.info.windows.length * root.step
                y: (root.block - root.block / 2) / 2
                width: root.block / 2
                height: root.block / 2
                radius: 0
                color: Appearance.colour.textFaint
            }
        }
    }
}
