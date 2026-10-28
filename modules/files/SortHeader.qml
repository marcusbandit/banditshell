pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "row-columns.js" as RowColumns
import "../../services/files-order.js" as FilesOrder

Item {
    id: root

    readonly property bool list: Files.listed
    readonly property var heads: FilesOrder.headers(Files.sort, Files.reversed, Files.trashTop)
    readonly property real inset: Appearance.padding.small + Appearance.padding.hair * 2
    readonly property real end: width - Appearance.padding.small
    readonly property real gap: Appearance.padding.normal
    readonly property real spacing: Appearance.padding.large
    readonly property var columns: RowColumns.fit(root.end - root.inset, digit.advanceWidth, Files.zoomed(Appearance.font.size.small), Files.zoomed(Appearance.font.iconSize), Appearance.padding.small, root.gap, Files.nameLeast, FilesFind.active)

    readonly property bool fitsAll: root.inset + name.implicitWidth + kind.implicitWidth + size.implicitWidth + dated.implicitWidth + root.spacing * 3 <= root.end

    function shown(head: Item): bool {
        return root.fitsAll || head.head.active;
    }

    function after(head: Item): real {
        return head.visible ? head.x + head.width + root.spacing : head.x;
    }

    function pick(id: string): void {
        const next = FilesOrder.chosen(id, Files.sort, Files.reversed, Files.trashTop);
        Config.setMany([["files.sort", next.sort], ["files.reversed", next.reversed]]);
    }

    implicitHeight: Files.zoomed(Appearance.font.line.small) + Appearance.padding.small

    TextMetrics {
        id: digit

        font.family: Appearance.font.family
        font.pixelSize: Files.zoomed(Appearance.font.size.small)
        text: "0"
    }

    SortHead {
        id: name

        anchors.verticalCenter: parent.verticalCenter
        x: root.list ? root.inset + Files.zoomed(Appearance.font.iconSize) + Appearance.padding.small : root.inset
        visible: root.list ? name.head.active || name.x + name.width + root.spacing <= (size.visible ? size.x : dated.visible ? dated.x : root.end) : root.shown(name)
        head: root.heads[0]
        onChose: id => root.pick(id)
    }

    SortHead {
        id: kind

        anchors.verticalCenter: parent.verticalCenter
        x: root.after(name)
        visible: root.list ? kind.x + kind.width + root.spacing <= (size.visible ? size.x : dated.visible ? dated.x : root.end) : root.shown(kind)
        head: root.heads[1]
        onChose: id => root.pick(id)
    }

    SortHead {
        id: size

        readonly property real edge: {
            if (!dated.visible)
                return root.end;
            if (FilesFind.active)
                return dated.x - root.spacing;
            return Math.min(root.end - root.columns.dateWidth - root.gap, dated.x - root.spacing);
        }

        anchors.verticalCenter: parent.verticalCenter
        x: root.list ? size.edge - size.width : root.after(kind)
        visible: root.list ? root.columns.showsSize || size.head.active : root.shown(size)
        head: root.heads[2]
        onChose: id => root.pick(id)
    }

    SortHead {
        id: dated

        anchors.verticalCenter: parent.verticalCenter
        x: root.list ? root.end - dated.width : root.after(size)
        visible: root.list ? root.columns.showsDate || dated.head.active : root.shown(dated)
        head: root.heads[3]
        onChose: id => root.pick(id)
    }
}
