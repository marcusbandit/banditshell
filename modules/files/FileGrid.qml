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

    // Where the pointer is during a drag, in this item's coordinates, or (-1,-1).
    property point dragPoint: Qt.point(-1, -1)
    property bool dragging: false

    signal picked(int index, int modifiers)
    signal activated(int index)
    signal menuFor(int index, point position)
    signal menuForEmpty(point position)
    signal lifted(int index)
    signal dragged(point position)
    signal dropped(point position)

    readonly property int columns: Math.max(1, Math.floor(width / Appearance.sizes.filesTile))
    readonly property real cell: width / root.columns
    readonly property real cellHeight: root.cell * 1.18

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
        //
        // Only just taller: at 1.24 the rows drifted far enough apart that the
        // grid read as a scatter of icons rather than as a grid, because the
        // drawn content of a tile is the picture plus two lines and everything
        // past that is space between rows.
        cellHeight: root.cellHeight

        model: root.entries
        currentIndex: Files.cursor

        boundsBehavior: Flickable.StopAtBounds

        delegate: FileTile {
            id: tile

            width: grid.cellWidth
            height: grid.cellHeight

            // TWO KINDS OF "THIS ONE", because with a selection they are not the
            // same thing: `picked` is what an action will act on, `cursored` is
            // where the keyboard is. Selecting five files and arrowing through
            // them has to show both at once or the next keystroke is a guess.
            picked: Files.isPicked(modelData.name)
            cursored: index === Files.cursor
            receiving: root.dragging && root.target === index && droppable && !Files.isPicked(modelData.name)

            onClicked: modifiers => root.picked(index, modifiers)
            onActivated: root.activated(index)
            onMenuRequested: position => root.menuFor(index, root.mapFromItem(tile, position.x, position.y))
            // MAPPED OUT OF THE TILE as it leaves, so what travels upward is
            // always a point in the coordinates of whoever is receiving it.
            // The tile reports in its own; nobody above has to know that.
            onLifted: root.lifted(index)
            onDragged: position => root.dragged(root.mapFromItem(tile, position.x, position.y))
            onDropped: position => root.dropped(root.mapFromItem(tile, position.x, position.y))
        }
    }

    // THE EMPTY SPACE, and what can be done in it: a rubber band, and a menu.
    //
    // It sits OVER the grid and steps aside when the press is on a tile - a
    // press it declines is delivered to whatever is underneath, which is the
    // delegate. That is the only way round: a bare item underneath would never
    // see a press at all, because the GridView is a Flickable and covers the
    // whole area whether or not there is a tile at that point.
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
            // Holding Ctrl adds to what is already selected instead of starting
            // over, the same as it does on a single tile.
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

            // A band that never moved is a click on nothing, which is how you
            // put a selection down.
            if (band.width < 3 && band.height < 3) {
                if (!empty.adding)
                    Files.clearPicked();
                return;
            }

            Files.pickRange(root.indicesIn(band.x, band.y, band.width, band.height), empty.adding);
        }
    }

    // WHICH TILES A RECTANGLE TOUCHES, worked out from the index rather than by
    // asking the view.
    //
    // A GridView only has items for the rows it has built, so hit-testing the
    // scene would silently miss everything scrolled off - and a band dragged
    // past the bottom edge is exactly the case that matters. The position of
    // index i is arithmetic on the column count, so this is right for all of
    // them whether they exist as items or not.
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

    G2Rect {
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
