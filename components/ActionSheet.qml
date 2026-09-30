pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var actions: []
    property bool open: false

    property int selected: 0

    property int worn: -1

    property real atX: 0
    property real atY: 0

    signal closed

    function popup(x: real, y: real, list: var, start: int): void {
        root.actions = list ?? [];
        if (!root.actions.length)
            return;
        root.atX = x;
        root.atY = y;
        root.worn = start >= 0 ? start : -1;
        root.selected = Math.max(0, Math.min(root.actions.length - 1, start >= 0 ? start : 0));

        marker.snap();
        root.open = true;
    }

    function close(): void {
        if (!root.open)
            return;
        root.open = false;
        root.closed();
    }

    function choose(index: int): void {
        if (index >= 0 && index < root.actions.length)
            root.selected = index;
    }

    function move(delta: int): void {
        root.choose(Math.max(0, Math.min(root.actions.length - 1, root.selected + delta)));
    }

    function activate(index: int): void {
        const action = root.actions[index];
        root.close();
        if (action?.run)
            action.run();
    }

    readonly property real gap: Appearance.padding.small
    readonly property real inset: Appearance.padding.normal

    readonly property real rowHeight: Math.max(Appearance.sizes.rowHeight, Appearance.font.iconSize + root.inset * 2)
    readonly property real step: root.rowHeight + root.gap

    readonly property real rowWidth: Math.min(root.width - root.edge * 2 - root.gap * 2, root.inset * 3 + Appearance.font.iconSize + measure.childrenRect.width)

    readonly property real cellRadius: Appearance.rounding.normal
    readonly property real groupRadius: root.cellRadius + root.gap

    readonly property real edge: Appearance.padding.normal
    readonly property real fullWidth: root.rowWidth + root.gap * 2
    readonly property real fullHeight: root.actions.length * root.step - root.gap + root.gap * 2

    readonly property bool flipX: root.atX + root.fullWidth > root.width - root.edge
    readonly property bool flipY: root.atY + root.fullHeight > root.height - root.edge
    readonly property real originX: Math.max(root.edge, Math.min(root.flipX ? root.atX - root.fullWidth : root.atX, root.width - root.edge - root.fullWidth))
    readonly property real originY: Math.max(root.edge, Math.min(root.flipY ? root.atY - root.fullHeight : root.atY, root.height - root.edge - root.fullHeight))

    Follow {
        id: unroll

        target: root.open ? 1 : 0
        speed: Appearance.anim.revealSpeed
        epsilon: 0.001
    }

    Follow {
        id: marker

        speed: Appearance.anim.trackSpeed
        target: root.selected * root.step
    }

    visible: unroll.value > 0.001

    onOpenChanged: if (root.open)
        root.forceActiveFocus()

    Keys.onEscapePressed: root.close()

    MouseArea {
        anchors.fill: parent
        enabled: root.open

        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onPressed: root.close()
    }

    Column {
        id: measure

        visible: false

        Repeater {
            model: root.actions

            StyledText {
                required property var modelData

                text: modelData.label
            }
        }
    }

    Item {
        id: sheet

        width: root.fullWidth
        height: root.fullHeight * unroll.value

        x: root.originX + (root.flipX ? root.fullWidth - width : 0)
        y: root.originY + (root.flipY ? root.fullHeight - height : 0)

        clip: true

        SquircleRect {
            anchors.fill: parent
            radius: root.groupRadius
            color: Appearance.colour.surfaceSolid
            stroke: Appearance.colour.separator
            strokeWidth: Appearance.font.stem
        }

        SquircleRect {
            x: root.gap
            y: root.gap + marker.value
            width: root.rowWidth
            height: root.rowHeight
            radius: root.cellRadius
            color: Appearance.colour.fillStronger
        }

        Column {
            x: root.gap
            y: root.gap
            spacing: root.gap

            Repeater {
                model: root.actions

                delegate: Item {
                    id: cell

                    required property var modelData
                    required property int index

                    readonly property bool chosen: root.selected === cell.index
                    readonly property bool worn: root.worn === cell.index

                    width: root.rowWidth
                    height: root.rowHeight

                    Icon {
                        id: mark

                        opacity: cell.worn ? 0 : 1

                        x: root.inset
                        anchors.verticalCenter: parent.verticalCenter

                        name: cell.modelData.icon
                        size: Appearance.font.iconSize
                        color: cell.chosen ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.normal
                            }
                        }
                    }

                    Rectangle {
                        visible: cell.worn

                        anchors.centerIn: mark

                        width: mark.width
                        height: width
                        radius: width / 2
                        color: Appearance.colour.accent
                    }

                    StyledText {
                        anchors.left: mark.right
                        anchors.leftMargin: root.inset
                        anchors.verticalCenter: parent.verticalCenter

                        text: cell.modelData.label

                        color: cell.worn || cell.chosen ? Appearance.colour.text : Appearance.colour.textDim

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.anim.normal
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor

                        onEntered: root.choose(cell.index)
                        onClicked: {
                            root.choose(cell.index);
                            root.activate(cell.index);
                        }
                    }
                }
            }
        }
    }
}
