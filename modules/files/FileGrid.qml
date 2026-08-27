pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// THE FILES, laid out.
//
// The column count is arithmetic on the width and one configured tile size, and
// there is no column setting anywhere: as many as fit, each one an equal share
// of what there is, so the grid reflows on a window drag with nothing to keep in
// step (~/.claude/rules/math-over-hardcoding.md).
//
// A GridView rather than a Flow in a Flickable, because a home directory has
// thousands of entries in it and a Flow builds every one of them. This is the
// one list in the shell that does not glide - GlideList is a ListView and the
// grid is not - which is a real loss and the wrong thing to fix by duplicating
// its guts here.
Item {
    id: root

    required property var entries
    property int selected: -1

    // Where the pointer is during a drag, in this item's coordinates, or null.
    // Held rather than passed through so the highlight and the drop use exactly
    // the same answer.
    property point dragPoint: Qt.point(-1, -1)
    property bool dragging: false

    signal picked(int index)
    signal activated(int index)
    signal lifted(int index)
    signal dragged(point position)
    signal dropped(point position)

    readonly property int columns: Math.max(1, Math.floor(width / Appearance.sizes.filesTile))
    readonly property real cell: width / root.columns

    // WHICH TILE THE POINTER IS OVER, as an index, while something is being
    // dragged. Computed from the pointer rather than from each tile's own hover,
    // because during a drag the ghost is under the cursor and takes the hover
    // with it.
    readonly property int target: root.dragging ? root.dropIndexAt(root.dragPoint) : -1

    // Which tile a point in this item lands on, or -1. Content coordinates, not
    // item ones: the grid scrolls, and asking at the raw position would answer
    // with whatever tile happened to be at that spot before it was scrolled
    // there.
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
        // TALLER THAN IT IS WIDE, because a tile is a picture with a name under
        // it and the name is two lines. The ratio is a proportion of the cell
        // rather than a second configured number, so both move together when the
        // tile size does.
        cellHeight: root.cell * 1.24

        model: root.entries
        currentIndex: root.selected

        boundsBehavior: Flickable.StopAtBounds

        delegate: FileTile {
            id: tile

            width: grid.cellWidth
            height: grid.cellHeight

            selected: index === root.selected
            receiving: root.dragging && root.target === index && droppable && root.selected !== index

            onClicked: root.picked(index)
            onActivated: root.activated(index)
            // MAPPED OUT OF THE TILE as it leaves, so what travels upward is
            // always a point in the coordinates of whoever is receiving it.
            // The tile reports in its own; nobody above has to know that.
            onLifted: root.lifted(index)
            onDragged: position => root.dragged(root.mapFromItem(tile, position.x, position.y))
            onDropped: position => root.dropped(root.mapFromItem(tile, position.x, position.y))
        }
    }

    // NOTHING HERE, said out loud. An empty directory and a directory that could
    // not be read look identical, and one of them is a mistake you would go
    // looking for in the wrong place.
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
