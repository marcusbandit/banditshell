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

    function popup(x: real, y: real, list: var, start: var): void {
        root.actions = list ?? [];
        if (!root.actions.length)
            return;
        const at = typeof start === "number" && start >= 0 ? start : -1;
        root.atX = x;
        root.atY = y;
        root.worn = at;
        root.selected = Math.max(0, Math.min(root.actions.length - 1, at));

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

    property real zoom: 1

    readonly property int breaks: {
        let count = 0;
        for (let i = 1; i < root.actions.length; i++)
            if (root.apart(i))
                count += 1;
        return count;
    }
    readonly property real plainRow: Math.max(Appearance.sizes.rowHeight, Appearance.font.iconSize + Appearance.padding.normal * 2)
    readonly property real plainHeight: root.actions.length * (root.plainRow + Appearance.padding.small) + root.breaks * (Appearance.padding.small * 2 + 1) + Appearance.padding.small
    readonly property real sized: Math.min(root.zoom, Math.max(1, (root.height - root.edge * 2) / Math.max(1, root.plainHeight)))

    readonly property real gap: Math.round(Appearance.padding.small * root.sized)
    readonly property real inset: Math.round(Appearance.padding.normal * root.sized)
    readonly property int iconSize: Math.round(Appearance.font.iconSize * root.sized)
    readonly property int textSize: Math.round(Appearance.font.size.small * root.sized)

    readonly property real rowHeight: Math.max(Math.round(Appearance.sizes.rowHeight * root.sized), root.iconSize + root.inset * 2)
    readonly property real step: root.rowHeight + root.gap
    readonly property real split: root.gap * 2 + 1

    function apart(index: int): bool {
        const action = root.actions[index];
        return index > 0 && !!action && (!!action.apart || !!action.alarm !== !!root.actions[index - 1].alarm);
    }

    function rowTop(index: int): real {
        let breaks = 0;
        for (let i = 1; i <= index && i < root.actions.length; i++)
            if (root.apart(i))
                breaks += 1;
        return index * root.step + breaks * root.split;
    }

    readonly property real rowWidth: Math.min(root.width - root.edge * 2 - root.gap * 2, root.inset * 3 + root.iconSize + measure.childrenRect.width)

    readonly property real cellRadius: Math.round(Appearance.rounding.normal * root.sized)
    readonly property real groupRadius: root.cellRadius + root.gap

    readonly property real edge: Appearance.padding.normal
    readonly property real fullWidth: root.rowWidth + root.gap * 2
    readonly property real fullHeight: root.rowTop(root.actions.length - 1) + root.rowHeight + root.gap * 2

    readonly property bool flipX: root.atX + root.fullWidth > root.width - root.edge
    readonly property bool flipY: root.atY + root.fullHeight > root.height - root.edge
    readonly property real originX: Math.max(root.edge, Math.min(root.flipX ? root.atX - root.fullWidth : root.atX, root.width - root.edge - root.fullWidth))
    readonly property real originY: Math.max(root.edge, Math.min(root.flipY ? root.atY - root.fullHeight : root.atY, root.height - root.edge - root.fullHeight))

    Follow {
        id: unroll

        target: root.open ? 1 : 0
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Follow {
        id: marker

        speed: Appearance.animation.trackSpeed
        target: root.rowTop(root.selected)
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
                font.pixelSize: root.textSize
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
            strokeWidth: Appearance.stroke.ring
        }

        SquircleRect {
            x: root.gap
            y: root.gap + marker.value
            width: root.rowWidth
            height: root.rowHeight
            radius: root.cellRadius
            color: Appearance.colour.fillStronger

            SquircleRect {
                anchors.fill: parent
                radius: root.cellRadius
                color: Appearance.colour.alarmFill
                opacity: alarmShown.value

                Follow {
                    id: alarmShown

                    target: root.actions[root.selected]?.alarm ? 1 : 0
                    speed: Appearance.animation.trackSpeed
                    epsilon: Appearance.animation.fadeEpsilon
                }
            }
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

                    readonly property real lead: root.apart(cell.index) ? root.split : 0

                    width: root.rowWidth
                    height: root.rowHeight + cell.lead

                    Separator {
                        visible: cell.lead > 0
                        width: parent.width
                        y: (cell.lead - root.gap - height) / 2
                    }

                    Item {
                        y: cell.lead
                        width: parent.width
                        height: root.rowHeight

                        Icon {
                            id: mark

                            opacity: cell.worn ? 0 : 1

                            x: root.inset
                            anchors.verticalCenter: parent.verticalCenter

                            name: cell.modelData.icon
                            size: root.iconSize
                            color: markTone.value

                            FollowColour {
                                id: markTone

                                target: cell.modelData.alarm ? Appearance.colour.alarm : cell.chosen ? Appearance.colour.text : Appearance.colour.textDim
                                speed: Appearance.animation.trackSpeed
                            }
                        }

                        SquircleRect {
                            visible: cell.worn

                            anchors.centerIn: mark

                            width: mark.width
                            height: width
                            pill: "object"
                            color: Appearance.colour.accent
                        }

                        StyledText {
                            anchors.left: mark.right
                            anchors.leftMargin: root.inset
                            anchors.verticalCenter: parent.verticalCenter

                            text: cell.modelData.label
                            font.pixelSize: root.textSize

                            color: labelTone.value

                            FollowColour {
                                id: labelTone

                                target: cell.modelData.alarm ? Appearance.colour.alarm : cell.worn || cell.chosen ? Appearance.colour.text : Appearance.colour.textDim
                                speed: Appearance.animation.trackSpeed
                            }
                        }
                    }

                    MouseArea {
                        y: cell.lead
                        width: parent.width
                        height: root.rowHeight
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
