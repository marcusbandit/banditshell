pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var actions: []
    property int selected: 0
    property int worn: -1
    property int opened: -1
    property real sized: 1
    property real widest: 4000

    signal hovered(int index)
    signal clicked(int index)

    function snap(): void {
        marker.snap();
    }

    function headed(index: int): bool {
        const action = root.actions[index];
        return !!action && !!action.section && (index === 0 || root.actions[index - 1].section !== action.section);
    }

    function apart(index: int): bool {
        const action = root.actions[index];
        return index > 0 && !!action && (!!action.apart || !!action.alarm !== !!root.actions[index - 1].alarm);
    }

    function measureAt(scale: real): var {
        const gap = Math.round(Appearance.padding.small * scale);
        const inset = Math.round(Appearance.padding.normal * scale);
        const iconSize = Math.round(Appearance.font.iconSize * scale);
        const textSize = Math.round(Appearance.font.size.small * scale);
        const rowHeight = Math.max(Math.round(Appearance.sizes.rowHeight * scale), iconSize + inset * 2);
        return {
            gap: gap,
            inset: inset,
            iconSize: iconSize,
            textSize: textSize,
            rowHeight: rowHeight,
            step: rowHeight + gap,
            split: gap * 2 + 1,
            headRow: Math.round(textSize * 1.6) + gap
        };
    }

    function leadIn(index: int, size: var): real {
        return (root.apart(index) && !root.headed(index) ? size.split : 0) + (root.headed(index) ? size.headRow : 0);
    }

    function topIn(index: int, size: var): real {
        let total = index * size.step;
        for (let i = 0; i <= index && i < root.actions.length; i++)
            total += root.leadIn(i, size);
        return total;
    }

    function heightIn(size: var): real {
        return root.actions.length ? root.topIn(root.actions.length - 1, size) + size.rowHeight + size.gap * 2 : 0;
    }

    function lead(index: int): real {
        return root.leadIn(index, root.metrics);
    }

    function rowTop(index: int): real {
        return root.topIn(index, root.metrics);
    }

    readonly property var metrics: root.measureAt(root.sized)
    readonly property real plainHeight: root.heightIn(root.measureAt(1))

    readonly property real gap: root.metrics.gap
    readonly property real inset: root.metrics.inset
    readonly property int iconSize: root.metrics.iconSize
    readonly property int textSize: root.metrics.textSize

    readonly property real rowHeight: root.metrics.rowHeight
    readonly property real step: root.metrics.step
    readonly property real split: root.metrics.split
    readonly property real headRow: root.metrics.headRow

    readonly property real rowWidth: Math.min(root.widest - root.gap * 2, root.inset * 3 + root.iconSize + measure.childrenRect.width)

    readonly property real cellRadius: Math.round(Appearance.rounding.normal * root.sized)
    readonly property real groupRadius: root.cellRadius + root.gap

    implicitWidth: root.rowWidth + root.gap * 2
    implicitHeight: root.heightIn(root.metrics)

    Follow {
        id: marker

        speed: Appearance.animation.trackSpeed
        target: root.rowTop(root.selected)
    }

    Column {
        id: measure

        visible: false

        Repeater {
            model: root.actions

            Row {
                required property var modelData

                spacing: modelData.keys || modelData.children ? root.inset * 2 : 0

                StyledText {
                    text: parent.modelData.label
                    font.pixelSize: root.textSize
                }

                StyledText {
                    text: parent.modelData.keys ?? ""
                    font.pixelSize: root.textSize
                }

                Item {
                    width: parent.modelData.children ? root.iconSize : 0
                    height: 1
                }
            }
        }
    }

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
                readonly property bool nests: !!cell.modelData.children?.length

                readonly property real lead: root.lead(cell.index)
                readonly property bool headed: root.headed(cell.index)

                width: root.rowWidth
                height: root.rowHeight + cell.lead

                Separator {
                    visible: cell.lead > 0 && !cell.headed && cell.index > 0
                    width: parent.width
                    y: (cell.lead - root.gap - height) / 2
                }

                StyledText {
                    visible: cell.headed
                    x: root.inset
                    y: Math.round(root.gap / 2)
                    text: cell.modelData.section ?? ""
                    font.pixelSize: root.textSize
                    color: Appearance.colour.textFaint
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
                        id: keys

                        anchors.right: parent.right
                        anchors.rightMargin: root.inset
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: cell.nests ? "" : cell.modelData.keys ?? ""
                        font.pixelSize: root.textSize
                        color: Appearance.colour.textFaint
                    }

                    Icon {
                        id: nest

                        anchors.right: parent.right
                        anchors.rightMargin: root.inset
                        anchors.verticalCenter: parent.verticalCenter
                        visible: cell.nests
                        name: "chevron_right"
                        size: root.iconSize
                        color: cell.chosen || root.opened === cell.index ? Appearance.colour.text : Appearance.colour.textFaint
                    }

                    StyledText {
                        anchors.left: mark.right
                        anchors.leftMargin: root.inset
                        anchors.right: cell.nests ? nest.left : keys.visible ? keys.left : parent.right
                        anchors.rightMargin: keys.visible || cell.nests ? root.inset * 2 : root.inset
                        anchors.verticalCenter: parent.verticalCenter
                        elide: Text.ElideRight

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

                    onEntered: root.hovered(cell.index)
                    onClicked: root.clicked(cell.index)
                }
            }
        }
    }
}
