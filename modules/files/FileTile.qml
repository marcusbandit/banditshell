pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "urls.js" as Urls
import "tile-names.js" as TileNames
import "../../services/files-find.js" as Find

Item {
    id: root

    required property var entry
    required property int index

    readonly property string path: Files.pathOf(root.entry)
    readonly property string place: root.entry.trash ? Files.originPlace(root.entry) : root.entry.dir ? Find.place(root.entry.dir, Files.home) : FilesFind.active ? Find.place(Files.cwd, Files.home) : ""

    function fitted(width: real): string {
        return Find.fitPlace(root.place, Math.max(1, Math.floor(width / Math.max(1, digit.advanceWidth))));
    }

    TextMetrics {
        id: digit

        font.family: Appearance.font.family
        font.pixelSize: Files.zoomed(Appearance.font.size.small)
        text: "0"
    }

    property bool picked: false
    property bool focused: false
    property bool previewed: false
    property bool keyed: false

    property bool row: false

    property bool receiving: false

    readonly property bool droppable: root.entry.kind === "dir" && root.entry.open
    readonly property bool isImage: root.entry.class === "image" && !root.entry.broken

    signal clicked(int modifiers)
    signal activated
    signal menuRequested(point position)
    signal lifted
    signal dragged(point position)
    signal dropped(point position)

    SquircleRect {
        anchors.fill: parent
        anchors.leftMargin: mark.reach
        anchors.rightMargin: mark.reach
        anchors.topMargin: root.row ? 0 : mark.reach
        anchors.bottomMargin: root.row ? 0 : mark.reach

        radius: Appearance.rounding.normal
        color: root.receiving || root.picked ? Appearance.colour.accentFill : hover.hovered && !root.keyed ? Appearance.colour.fill : "transparent"

        stroke: root.receiving ? Appearance.colour.accent : "transparent"
        strokeWidth: root.receiving ? Appearance.stroke.ring : 0

        FocusMark {
            id: mark

            shown: root.focused
        }

        SquircleRect {
            anchors.left: parent.left
            anchors.leftMargin: Appearance.padding.hair
            anchors.verticalCenter: parent.verticalCenter
            visible: root.previewed && root.row

            width: Appearance.padding.hair
            height: parent.height - Appearance.padding.hair * 2

            pill: "object"
            color: Appearance.colour.accent
        }

        SquircleRect {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.previewed && !root.row

            width: parent.width - Appearance.rounding.normal * 2
            height: Appearance.padding.hair

            pill: "object"
            color: Appearance.colour.accent
        }
    }

    HoverHandler {
        id: hover
    }

    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -Appearance.padding.hair
        width: parent.width - mark.reach * 2 - Appearance.padding.small
        spacing: Appearance.padding.hair
        visible: !root.row

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: root.height * 0.52

            SquircleImage {
                id: thumb

                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height - Appearance.padding.hair * 2
                visible: root.isImage && status !== Image.Error

                source: root.isImage ? Urls.freshUrl(root.path, root.entry.mtime, root.entry.size) : ""
                radius: Appearance.rounding.small
                decodeWidth: Appearance.sizes.filesThumbnail
                decodeHeight: Appearance.sizes.filesThumbnail
            }

            FileMark {
                anchors.centerIn: thumb
                visible: !thumb.visible || thumb.status !== Image.Ready

                fileClass: root.entry.class
                path: root.path
                name: root.entry.name
                link: root.entry.link
                broken: root.entry.broken
                readable: root.entry.read
                writable: root.entry.write
                owned: root.entry.mine
                rooted: root.entry.root
                worldWritable: root.entry.world
                size: Math.min(thumb.height, root.width * 0.46)
            }
        }

        StyledText {
            id: label

            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignTop

            function fitted(name: string, most: int, width: real, font: font): string {
                ink.font = font;
                return TileNames.lines(name, most, s => ink.advanceWidth(s) <= width).join("\n");
            }

            text: label.fitted(root.entry.name, label.maximumLineCount, label.width, label.font)
            color: root.picked ? Appearance.colour.accent : Appearance.colour.text

            font.pixelSize: Files.zoomed(Appearance.font.size.small)

            maximumLineCount: root.place ? 1 : 2

            height: label.lineHeight * (root.place ? 1 : 2)

            FontMetrics {
                id: ink
            }
        }

        StyledText {
            id: tilePlace

            width: parent.width
            visible: root.place !== ""
            horizontalAlignment: Text.AlignHCenter

            text: root.fitted(tilePlace.width)
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textDim
        }
    }

    Item {
        id: rowLayout

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.small + Appearance.padding.hair * 2
        anchors.rightMargin: Appearance.padding.small
        visible: root.row

        readonly property bool stacked: FilesFind.active && !root.entry.trash
        readonly property real dateWidth: rowLayout.stacked ? digit.advanceWidth * 13 : Files.zoomed(Appearance.font.size.small) * 7
        readonly property real sizeWidth: Files.zoomed(Appearance.font.size.small) * 5
        readonly property real gap: Appearance.padding.normal
        readonly property real nameLeast: rowMark.width + Appearance.padding.small + digit.advanceWidth * Files.nameLeast
        readonly property bool showsDate: rowLayout.width - rowLayout.nameLeast >= (rowLayout.stacked ? Math.max(rowLayout.dateWidth, rowLayout.sizeWidth) + rowLayout.gap : rowLayout.dateWidth + rowLayout.sizeWidth + rowLayout.gap * 2)
        readonly property bool showsSize: rowLayout.stacked ? rowLayout.showsDate : rowLayout.width - rowLayout.nameLeast >= rowLayout.sizeWidth + rowLayout.gap

        function textStart(item: Item): real {
            return item.x + item.width - item.contentWidth;
        }

        FileMark {
            id: rowMark

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            fileClass: root.entry.class
            path: root.path
            name: root.entry.name
            link: root.entry.link
            broken: root.entry.broken
            readable: root.entry.read
            writable: root.entry.write
            owned: root.entry.mine
            rooted: root.entry.root
            worldWritable: root.entry.world
            size: Files.zoomed(Appearance.font.iconSize)
        }

        StyledText {
            id: rowName

            anchors.left: rowMark.right
            anchors.leftMargin: Appearance.padding.small
            anchors.verticalCenter: parent.stacked ? undefined : parent.verticalCenter
            anchors.bottom: parent.stacked ? parent.verticalCenter : undefined
            readonly property real limit: {
                if (parent.stacked)
                    return parent.showsDate ? parent.textStart(rowDate) : parent.width + parent.gap;
                if (root.place !== "")
                    return (parent.showsSize ? rowSize.x : parent.width) - parent.gap;
                if (rowSize.contentWidth > 0)
                    return parent.textStart(rowSize);
                return parent.showsDate ? parent.textStart(rowDate) : parent.width + parent.gap;
            }
            readonly property real room: rowName.limit - rowName.x - parent.gap
            visible: rowName.room > 0
            width: Math.max(0, Math.min(rowName.implicitWidth, rowName.room))

            text: rowName.room > 0 ? TileNames.lines(root.entry.name, 1, line => rowInk.advanceWidth(line) <= rowName.room)[0] : ""
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            elide: Text.ElideRight
            color: root.picked ? Appearance.colour.accent : root.focused || parent.stacked ? Appearance.colour.text : Appearance.colour.textDim

            FontMetrics {
                id: rowInk

                font: rowName.font
            }
        }

        StyledText {
            id: rowPlace

            anchors.left: parent.stacked ? rowName.left : rowName.right
            anchors.leftMargin: parent.stacked ? 0 : Appearance.padding.normal
            anchors.right: parent.stacked ? rowDate.left : rowSize.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.stacked ? undefined : parent.verticalCenter
            anchors.top: parent.stacked ? parent.verticalCenter : undefined
            visible: root.place !== "" && rowPlace.width >= digit.advanceWidth * 4

            text: parent.stacked ? Find.fitTail(root.place, Math.max(1, Math.floor(rowPlace.width / Math.max(1, digit.advanceWidth)))) : root.fitted(rowPlace.width)
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: parent.stacked ? Appearance.colour.text : Appearance.colour.textDim
        }

        StyledText {
            id: rowSize

            anchors.right: parent.stacked ? parent.right : rowDate.left
            anchors.rightMargin: parent.stacked || !parent.showsDate ? 0 : parent.gap
            anchors.verticalCenter: parent.stacked ? undefined : parent.verticalCenter
            anchors.top: parent.stacked ? parent.verticalCenter : undefined
            width: parent.showsSize ? parent.sizeWidth : 0
            visible: parent.showsSize

            horizontalAlignment: Text.AlignRight

            text: !parent.showsSize || root.entry.kind === "dir" ? "" : Files.humanSize(root.entry.size)
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint
        }

        StyledText {
            id: rowDate

            anchors.right: parent.right
            anchors.verticalCenter: parent.stacked ? undefined : parent.verticalCenter
            anchors.bottom: parent.stacked ? parent.verticalCenter : undefined
            width: parent.showsDate ? parent.dateWidth : 0
            visible: parent.showsDate

            horizontalAlignment: Text.AlignRight
            text: !parent.showsDate ? "" : parent.stacked ? Files.changedTime(root.entry.mtime) : Files.humanTime(root.entry.trashed ?? root.entry.mtime)
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: parent.stacked ? Appearance.colour.textDim : Appearance.colour.textFaint
        }
    }

    readonly property point pointer: Qt.point(drag.centroid.pressPosition.x + drag.activeTranslation.x, drag.centroid.pressPosition.y + drag.activeTranslation.y)

    DragHandler {
        id: drag

        target: null

        dragThreshold: Config.values.control.dragThreshold

        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

        onActiveChanged: {
            if (active)
                root.lifted();
            else
                root.dropped(root.pointer);
        }

        onActiveTranslationChanged: if (drag.active)
            root.dragged(root.pointer)
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.menuRequested(Qt.point(mouse.x, mouse.y));
                return;
            }
            root.clicked(mouse.modifiers);
        }

        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.activated();
        }
    }
}
