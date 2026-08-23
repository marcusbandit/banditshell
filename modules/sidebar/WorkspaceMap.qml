pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// STYLE: map. No glyphs at all. Each window is a bar as long as the window is
// wide.
//
// The layout scrolls sideways, so a workspace IS a row of windows of different
// widths, and that shape is information the icon styles throw away: a workspace
// holding one full-width editor and one holding four thirds look identical as a
// stack of glyphs, and nothing alike to work in. Here they look like what they
// are. Read down the column and you can see the shape of the machine.
//
// Bars are hinged on the screen's edge and run in, at the fraction of the display
// their window actually covers, clamped so a tiny floating window is still
// something you can see. Where you are is the accent; which window has the
// keyboard is the one at full weight.
Item {
    id: root

    // WHICH SCREEN THIS COLUMN IS ON, by output name, handed straight to the
    // model: a style draws what the model says, and which workspaces those are
    // is the model's question. See WorkspaceModel.screen.
    required property string screen

    readonly property int bar: Appearance.sizes.wsMapBar
    readonly property int pitch: bar + Appearance.sizes.wsMapGap
    readonly property real span: width - Appearance.sizes.band

    // Nothing smaller than this, whatever the window's real width. A bar has to
    // be findable before it can be proportional.
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
            // The MODEL'S active workspace, which is this screen's own rather
            // than the focused one's.
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

            // An empty workspace: one bar at the floor length, quiet enough to
            // read as a rule rather than as a window.
            G2Rect {
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

                delegate: G2Rect {
                    id: windowBar

                    required property var modelData
                    required property int index
                    readonly property bool focused: Hypr.isFocused(modelData)

                    x: 0
                    y: index * root.pitch
                    width: root.reachOf(modelData, root.hovered === slotItem.index)
                    height: root.bar

                    // A pill, squared off where it meets the edge it is hinged on.
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

            // THERE IS NO CAP ANY MORE, and so no short bar for the ones past
            // it. The model stopped truncating (see WorkspaceModel.slots), which
            // this style wanted most of the three: a map of a layout that stopped
            // after four windows was a map of part of the screen.
        }
    }
}
