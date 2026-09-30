pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var entries

    property point dragPoint: Qt.point(-1, -1)
    property bool dragging: false

    signal picked(int index, int modifiers)
    signal activated(int index)
    signal menuFor(int index, point position)
    signal menuForEmpty(point position)
    signal lifted(int index)
    signal dragged(point position)
    signal dropped(point position)

    readonly property bool list: Files.view === "list"

    readonly property int columns: root.list ? 1 : Math.max(1, Math.floor(width / Appearance.sizes.filesTile))
    readonly property real cell: width / root.columns
    readonly property real cellHeight: root.list ? Appearance.sizes.filesRow : root.cell * 1.18

    readonly property int target: root.dragging ? root.dropIndexAt(root.dragPoint) : -1

    function dropIndexAt(position: point): int {
        if (position.x < 0)
            return -1;
        return grid.indexAt(position.x + grid.contentX, position.y + grid.contentY);
    }

    function reveal(index: int): void {
        grid.positionViewAtIndex(index, GridView.Contain);
    }

    GridView {
        id: grid

        anchors.fill: parent
        clip: true

        cellWidth: root.cell

        cellHeight: root.cellHeight

        model: root.entries
        currentIndex: Files.cursor

        boundsBehavior: Flickable.StopAtBounds

        delegate: FileTile {
            id: tile

            width: grid.cellWidth
            height: grid.cellHeight

            row: root.list
            picked: Files.isPicked(modelData.name)
            cursored: index === Files.cursor
            receiving: root.dragging && root.target === index && droppable && !Files.isPicked(modelData.name)

            onClicked: modifiers => root.picked(index, modifiers)
            onActivated: root.activated(index)
            onMenuRequested: position => root.menuFor(index, root.mapFromItem(tile, position.x, position.y))

            onLifted: root.lifted(index)
            onDragged: position => root.dragged(root.mapFromItem(tile, position.x, position.y))
            onDropped: position => root.dropped(root.mapFromItem(tile, position.x, position.y))
        }
    }

    MouseArea {
        id: empty

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        property point from: Qt.point(0, 0)
        property point to: Qt.point(0, 0)
        property bool banding: false
        property bool adding: false

        onPressed: mouse => {
            if (root.dropIndexAt(Qt.point(mouse.x, mouse.y)) >= 0) {
                mouse.accepted = false;
                return;
            }

            if (mouse.button === Qt.RightButton)
                return;

            empty.from = Qt.point(mouse.x, mouse.y);
            empty.to = empty.from;

            empty.adding = (mouse.modifiers & Qt.ControlModifier) !== 0;
            empty.banding = true;
        }

        onPositionChanged: mouse => {
            if (empty.banding)
                empty.to = Qt.point(mouse.x, mouse.y);
        }

        onReleased: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.menuForEmpty(Qt.point(mouse.x, mouse.y));
                return;
            }

            if (!empty.banding)
                return;
            empty.banding = false;

            if (band.width < 3 && band.height < 3) {
                if (!empty.adding)
                    Files.clearPicked();
                return;
            }

            Files.pickRange(root.indicesIn(band.x, band.y, band.width, band.height), empty.adding);
        }
    }

    function indicesIn(x: real, y: real, w: real, h: real): var {
        const out = [];
        for (let i = 0; i < root.entries.length; i++) {
            const left = (i % root.columns) * root.cell - grid.contentX;
            const top = Math.floor(i / root.columns) * root.cellHeight - grid.contentY;
            if (left + root.cell > x && left < x + w && top + root.cellHeight > y && top < y + h)
                out.push(i);
        }
        return out;
    }

    SquircleRect {
        id: band

        visible: empty.banding

        x: Math.min(empty.from.x, empty.to.x)
        y: Math.min(empty.from.y, empty.to.y)
        width: Math.abs(empty.to.x - empty.from.x)
        height: Math.abs(empty.to.y - empty.from.y)

        radius: Appearance.rounding.small
        color: Appearance.colour.accentFill
        stroke: Appearance.colour.accent
        strokeWidth: Appearance.font.stem
    }

    Column {
        anchors.centerIn: parent
        spacing: Appearance.padding.normal
        visible: root.entries.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter

            name: Files.error ? "lock" : "folder_open"
            size: Appearance.font.iconSize * 2
            color: Files.error ? Appearance.colour.alarm : Appearance.colour.textGhost
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter

            text: Files.error ? Files.error : Files.search ? `nothing matching "${Files.search}"` : "empty"
            color: Appearance.colour.textFaint
        }
    }
}
