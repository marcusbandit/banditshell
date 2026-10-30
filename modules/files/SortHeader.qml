pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "row-columns.js" as RowColumns
import "../../services/files-order.js" as FilesOrder

Item {
    id: root

    clip: true

    readonly property bool list: Files.listed
    readonly property var heads: FilesOrder.headers(Files.sort, Files.reversed, Files.trashTop)
    readonly property real inset: RowColumns.inset(Appearance.padding.small, Appearance.padding.hair)
    readonly property real end: width - Appearance.padding.small
    readonly property real gap: Appearance.padding.normal
    readonly property real spacing: Appearance.padding.large
    readonly property var columns: RowColumns.fit(root.end - root.inset, digit.advanceWidth, Files.zoomed(Appearance.font.size.small), Files.zoomed(Appearance.font.iconSize), Appearance.padding.small, root.gap, Files.nameLeast, FilesFind.active)

    readonly property bool datedLeft: root.list && dated.head.active && !root.columns.showsDate && root.columns.showsSize
    readonly property real leftLimit: (size.visible ? size.x : dated.visible && !root.datedLeft ? dated.x : root.end) - (root.datedLeft ? dated.width + root.spacing : 0)

    readonly property real lineHeight: Files.zoomed(Appearance.font.line.small)
    readonly property var placed: RowColumns.flow([name.implicitWidth, kind.implicitWidth, size.implicitWidth, dated.implicitWidth], root.inset, root.end, root.spacing)
    readonly property int lines: root.list ? 1 : root.placed[root.placed.length - 1].line + 1

    function lineY(index: int): real {
        return Appearance.padding.small / 2 + (root.list ? 0 : root.placed[index].line * root.lineHeight);
    }

    function after(head: Item): real {
        return head.visible ? head.x + head.width + root.spacing : head.x;
    }

    function pick(id: string): void {
        const next = FilesOrder.chosen(id, Files.sort, Files.reversed, Files.trashTop);
        Config.setMany([["files.sort", next.sort], ["files.reversed", next.reversed]]);
    }

    implicitHeight: root.lineHeight * root.lines + Appearance.padding.small

    TextMetrics {
        id: digit

        font.family: Appearance.font.family
        font.pixelSize: Files.zoomed(Appearance.font.size.small)
        text: "0"
    }

    SortHead {
        id: name

        y: root.lineY(0)
        x: root.list ? root.inset + Files.zoomed(Appearance.font.iconSize) + Appearance.padding.small : root.placed[0].x
        visible: !root.list || name.head.active || name.x + name.width + root.spacing <= root.leftLimit
        head: root.heads[0]
        onChose: id => root.pick(id)
    }

    SortHead {
        id: kind

        y: root.lineY(1)
        x: root.list ? root.after(name) : root.placed[1].x
        visible: !root.list || kind.x + kind.width + root.spacing <= root.leftLimit
        head: root.heads[1]
        onChose: id => root.pick(id)
    }

    SortHead {
        id: size

        readonly property real edge: {
            if (!dated.visible || root.datedLeft)
                return root.end;
            if (FilesFind.active)
                return dated.x - root.spacing;
            return Math.min(root.end - root.columns.dateWidth - root.gap, dated.x - root.spacing);
        }

        y: root.lineY(2)
        x: root.list ? size.edge - size.width : root.placed[2].x
        visible: !root.list || size.head.active || root.columns.showsSize && (!FilesFind.active || size.x >= root.end - root.columns.dateWidth)
        head: root.heads[2]
        onChose: id => root.pick(id)
    }

    SortHead {
        id: dated

        y: root.lineY(3)
        x: root.list ? (root.datedLeft ? root.after(kind) : root.end - dated.width) : root.placed[3].x
        visible: !root.list || root.columns.showsDate || dated.head.active
        head: root.heads[3]
        onChose: id => root.pick(id)
    }
}
