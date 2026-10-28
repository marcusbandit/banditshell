pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "../../services/files-listing.js" as Listing

Item {
    id: root

    required property var entries

    property point dragPoint: Qt.point(-1, -1)
    property bool dragging: false
    property bool keyed: false
    property bool marked: false
    property bool previewing: false

    signal picked(int index, int modifiers)
    signal activated(int index)
    signal menuFor(int index, point position)
    signal menuForEmpty(point position)
    signal lifted(int index)
    signal dragged(point position)
    signal dropped(point position)

    readonly property bool list: Files.listed

    readonly property int columns: root.list ? 1 : Math.max(1, Math.floor(width / Appearance.sizes.filesTile))
    readonly property real cell: width / root.columns
    readonly property real cellHeight: root.list ? Appearance.sizes.filesRow + (FilesFind.active ? Files.zoomed(Appearance.font.line.small) : 0) : root.cell * 1.18

    readonly property int target: root.dragging ? root.dropIndexAt(root.dragPoint) : -1

    function dropIndexAt(position: point): int {
        if (position.x < 0)
            return -1;
        return grid.indexAt(position.x + grid.contentX, position.y + grid.contentY);
    }

    function reveal(index: int): void {
        grid.positionViewAtIndex(index, GridView.Contain);
        const top = Math.floor(index / root.columns) * root.cellHeight - grid.topMargin;
        const bottom = top + root.cellHeight + grid.topMargin + grid.bottomMargin;
        if (top < grid.contentY)
            grid.contentY = top;
        else if (bottom > grid.contentY + grid.height)
            grid.contentY = bottom - grid.height;
    }

    function warm(): void {
        grid.forceLayout();
    }

    property string shown: ""
    readonly property var held: ({
            entries: [],
            keys: [],
            index: Listing.table([])
        })
    property int revision: 0

    function entryOf(key: string, revision: int): var {
        return root.held.entries[root.held.index[":" + key]];
    }

    function show(): void {
        const view = [Files.cwd, Files.search, Config.values.files.sort, Config.values.files.reversed, Config.values.files.hidden].join("\n");
        const before = root.held.entries;
        const beforeKeys = root.held.keys;
        const had = root.held.index;
        const after = root.entries;
        const afterKeys = after.map(e => Files.keyOf(e));
        const wanted = Listing.table(afterKeys);
        const steps = view === root.shown && tiles.count === before.length ? Listing.steps(beforeKeys, afterKeys, had, wanted) : null;
        root.held.entries = after;
        root.held.keys = afterKeys;
        root.held.index = wanted;
        if (steps === null)
            root.rebuild(view === root.shown);
        else
            root.patch(steps, Listing.changed(before, after, had, afterKeys));
        grid.currentIndex = Qt.binding(() => Files.cursor);
        root.shown = view;
    }

    function rebuild(keepPlace: bool): void {
        const y = grid.contentY;
        tiles.clear();
        tiles.append(root.held.keys.map(key => ({
                    key: key,
                    revision: root.revision
                })));
        if (keepPlace)
            grid.contentY = Math.max(grid.originY, Math.min(y, grid.originY + grid.contentHeight - grid.height));
    }

    function patch(steps: var, changed: var): void {
        for (const step of steps) {
            if ("remove" in step)
                tiles.remove(step.remove, step.count);
            else if ("move" in step)
                tiles.move(step.move, step.to, 1);
            else
                for (let i = 0; i < step.count; i++)
                    tiles.insert(step.insert + i, {
                        key: root.held.keys[step.insert + i],
                        revision: root.revision
                    });
        }
        for (const i of changed)
            tiles.setProperty(i, "revision", ++root.revision);
    }

    onEntriesChanged: root.show()
    Component.onCompleted: root.show()

    ListModel {
        id: tiles
    }

    GridView {
        id: grid

        anchors.fill: parent
        clip: true

        cellWidth: root.cell

        cellHeight: root.cellHeight

        boundsBehavior: Flickable.StopAtBounds
        topMargin: Appearance.padding.hair
        bottomMargin: Appearance.padding.hair

        model: tiles

        WheelStep {
            flick: grid
        }

        delegate: FileTile {
            id: tile

            required property string key
            required property int revision
            property var last: null

            entry: root.entryOf(tile.key, tile.revision) ?? tile.last
            onEntryChanged: tile.last = tile.entry
            width: grid.cellWidth
            height: grid.cellHeight

            z: tile.focused ? 1 : 0
            row: root.list
            picked: Files.isPicked(Files.keyOf(tile.entry))
            focused: (root.keyed || root.marked) && tile.index === Files.cursor
            previewed: root.previewing && tile.index === Files.cursor
            keyed: root.keyed
            receiving: root.dragging && root.target === tile.index && tile.droppable && !Files.isPicked(Files.keyOf(tile.entry))

            onClicked: modifiers => root.picked(tile.index, modifiers)
            onActivated: root.activated(tile.index)
            onMenuRequested: position => root.menuFor(tile.index, root.mapFromItem(tile, position.x, position.y))

            onLifted: root.lifted(tile.index)
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
        strokeWidth: Appearance.stroke.ring
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Appearance.padding.large * 2
        spacing: Files.zoomed(Appearance.padding.normal)
        visible: root.entries.length === 0

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter

            name: Files.error ? "lock" : FilesFind.active ? "search" : "folder_open"
            size: Files.zoomed(Appearance.icon.huge)
            color: Files.error ? Appearance.colour.alarm : Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap

            text: Files.error ? Files.error : FilesFind.active && FilesFind.running ? "searching home…" : FilesFind.active ? `nothing matching "${Files.search}" in home` : Files.search ? `nothing matching "${Files.search}"` : "empty"
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            visible: FilesFind.active && !FilesFind.running && !Files.error

            text: FilesFind.everywhere || FilesFind.stopped || FilesFind.failed ? FilesFind.summary : `${FilesFind.summary}, caches and the Trash skipped`
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint
        }
    }
}
