pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import "urls.js" as Urls
import "tile-names.js" as TileNames

Item {
    id: root

    required property var modelData
    required property int index

    readonly property var entry: root.modelData
    readonly property string path: Files.join(Files.cwd, root.entry.name)

    property bool picked: false
    property bool focused: false
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
    }

    HoverHandler {
        id: hover
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - mark.reach * 2 - Appearance.padding.small
        spacing: Appearance.padding.hair
        visible: !root.row

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: root.height * 0.52

            SquircleImage {
                id: thumb

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                visible: root.isImage && status !== Image.Error

                source: root.isImage ? Urls.fileUrl(root.path) : ""
                radius: Appearance.rounding.small
                decodeWidth: Appearance.sizes.filesThumbnail
                decodeHeight: Appearance.sizes.filesThumbnail
            }

            FileMark {
                anchors.centerIn: parent
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
                size: Math.min(parent.height, root.width * 0.46)
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

            maximumLineCount: 2

            height: label.lineHeight * 2

            FontMetrics {
                id: ink
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.small
        anchors.rightMargin: Appearance.padding.small
        visible: root.row

        readonly property real dateWidth: Files.zoomed(Appearance.font.size.small) * 7
        readonly property real sizeWidth: Files.zoomed(Appearance.font.size.small) * 5

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
            anchors.left: rowMark.right
            anchors.leftMargin: Appearance.padding.small
            anchors.right: rowSize.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            text: root.entry.name
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            elide: Text.ElideMiddle
            color: root.picked ? Appearance.colour.accent : root.focused ? Appearance.colour.text : Appearance.colour.textDim
        }

        StyledText {
            id: rowSize

            anchors.right: rowDate.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            width: parent.sizeWidth

            horizontalAlignment: Text.AlignRight

            text: root.entry.kind === "dir" ? "" : Files.humanSize(root.entry.size)
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint
        }

        StyledText {
            id: rowDate

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.dateWidth

            horizontalAlignment: Text.AlignRight
            text: Files.humanTime(root.entry.mtime)
            font.pixelSize: Files.zoomed(Appearance.font.size.small)
            color: Appearance.colour.textFaint
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
