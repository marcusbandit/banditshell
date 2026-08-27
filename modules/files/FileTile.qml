pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// ONE THING IN THE GRID.
//
// A tile is a target, a picture, a name and a handle you can pick it up by, and
// the order of those matters: this shell's rule is drag before click (DESIGN.md
// section 15), so the drag is the primary gesture here and the click is what
// happens when you let go without having moved.
Item {
    id: root

    // The view fills these two by name, which is why they are the ones spelled
    // the view's way. Everything else about the tile is derived from them here
    // rather than passed in: a delegate that redeclares a required property its
    // own base class already declares is a delegate the view cannot build, and
    // the failure is silent except for one line in the log.
    required property var modelData
    required property int index

    readonly property var entry: root.modelData
    readonly property string path: Files.join(Files.cwd, root.entry.name)

    // WHAT AN ACTION WOULD ACT ON, and WHERE THE KEYBOARD IS. Two different
    // facts once there is a selection: five files can be picked while the cursor
    // sits on the third of them.
    property bool picked: false
    property bool cursored: false

    // ONE COMPONENT, TWO SHAPES. A row and a tile differ in how they lay out
    // four pieces of information; they are identical in every other respect -
    // the same fills, the same drag, the same clicks, the same menu. Two
    // components would be two copies of all of that, and the copy that was not
    // being looked at would be the one that quietly stopped matching.
    property bool row: false
    // Something is being dragged and it is over THIS tile, which only means
    // anything for a directory: a file dropped on a file has nowhere to go.
    property bool receiving: false

    readonly property bool droppable: root.entry.kind === "dir" && root.entry.open
    readonly property bool isImage: root.entry.class === "image" && !root.entry.broken

    signal clicked(int modifiers)
    signal activated
    signal menuRequested(point position)
    signal lifted
    signal dragged(point position)
    signal dropped(point position)

    // THE MATERIAL, and it is the shell's, never the file's. Everything that
    // says what this file IS is drawn in the colour of the mark; everything that
    // says what the POINTER is doing is drawn as one of the shell's own fills.
    // That separation is the reason a grid full of colour still reads as this
    // shell rather than as a folder of stickers.
    G2Rect {
        anchors.fill: parent

        radius: Appearance.rounding.normal
        color: root.receiving ? Appearance.colour.accentFill : root.picked ? Appearance.colour.fillStrong : hover.hovered ? Appearance.colour.fill : "transparent"

        // A DROP TARGET IS OUTLINED, not filled harder. The tile under the
        // pointer has to say "this one" while the thing being dropped is
        // floating over it and partly covering it, and an outline survives being
        // covered in a way a fill does not.
        //
        // The CURSOR is outlined too, at a quieter weight. A fill would be a
        // second kind of selection; a ring is "the keyboard is here", which is a
        // different statement and has to be readable on top of a filled tile.
        stroke: root.receiving ? Appearance.colour.accent : root.cursored ? Appearance.colour.textFaint : "transparent"
        strokeWidth: root.receiving || root.cursored ? Appearance.font.stem : 0

        // NO TRANSITION ON THE FILL. Hover and selection are answers to
        // something you just did, and an answer that fades in is an answer that
        // arrives after you have moved on. This is a tool: the feedback is the
        // point, and 100ms of it is 100ms of doubt about whether the click
        // landed.
    }

    HoverHandler {
        id: hover
    }

    // THE TILE: a picture with a name under it.
    Column {
        anchors.centerIn: parent
        width: parent.width - Appearance.padding.small
        spacing: Appearance.padding.small / 2
        visible: !root.row

        // THE PICTURE ITSELF, when there is one to draw. This is the whole
        // reason to open a file browser on a folder of photographs, so it is not
        // a preview of a thumbnail of an icon: it is the file, decoded at the
        // size it is drawn.
        //
        // G2Image decodes on a worker thread, which is what keeps a directory
        // of RAWs from freezing the window: the tile shows its mark until the
        // picture lands. `decodeWidth` is what keeps forty of them from being
        // held at full size in memory - see G2Image's own note.
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            height: root.height * 0.52

            G2Image {
                id: thumb

                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                visible: root.isImage && status !== Image.Error

                source: root.isImage ? `file://${root.path}` : ""
                radius: Appearance.rounding.small
                decodeWidth: Appearance.sizes.filesThumbnail
                decodeHeight: Appearance.sizes.filesThumbnail
            }

            FileMark {
                anchors.centerIn: parent
                visible: !thumb.visible || thumb.status !== Image.Ready

                fileClass: root.entry.class
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

            text: root.entry.name
            // THE WINDOW'S OWN BODY SIZE, smaller than the shell's `small`.
            // See Config's `files.text`.
            font.pixelSize: Appearance.sizes.filesText
            // TWO LINES, then elide. One line elides half the names in a
            // directory of anything real; three makes the tiles different
            // heights, and a grid whose rows do not line up is a grid you cannot
            // read down.
            maximumLineCount: 2
            wrapMode: Text.Wrap
            elide: Text.ElideRight

            // AND ALWAYS THE ROOM FOR TWO, whether or not the second is used.
            // Sized to the text instead, a one-word name makes a shorter tile,
            // the column centres its contents higher, and the icons along a row
            // sit at four different heights - which is exactly as untidy as it
            // sounds, and is not obvious from the code that causes it.
            height: label.lineHeight * 2
        }
    }

    // THE ROW: the same four facts, across instead of down, with the two that
    // are worth comparing between files given columns of their own.
    //
    // No thumbnail here on purpose. A row is 26px tall, a picture in it would be
    // 26px of picture, and the whole point of the list is that it fits three
    // times as many files on the screen. The mark says what kind of thing it is,
    // which at this size is all a picture could say anyway.
    Item {
        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.small
        anchors.rightMargin: Appearance.padding.small
        visible: root.row

        // The columns, from the right edge inward: both are fixed-width because
        // both are being compared DOWN the list rather than read across it, and
        // a column that moves with the longest value in it cannot be scanned.
        readonly property real dateWidth: Appearance.sizes.filesText * 7
        readonly property real sizeWidth: Appearance.sizes.filesText * 5

        FileMark {
            id: rowMark

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            fileClass: root.entry.class
            link: root.entry.link
            broken: root.entry.broken
            readable: root.entry.read
            writable: root.entry.write
            owned: root.entry.mine
            rooted: root.entry.root
            worldWritable: root.entry.world
            size: Appearance.sizes.filesText * 1.2
        }

        StyledText {
            anchors.left: rowMark.right
            anchors.leftMargin: Appearance.padding.small
            anchors.right: rowSize.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter

            text: root.entry.name
            font.pixelSize: Appearance.sizes.filesText
            elide: Text.ElideMiddle
            color: root.picked || root.cursored ? Appearance.colour.text : Appearance.colour.textDim
        }

        StyledText {
            id: rowSize

            anchors.right: rowDate.left
            anchors.rightMargin: Appearance.padding.normal
            anchors.verticalCenter: parent.verticalCenter
            width: parent.sizeWidth

            horizontalAlignment: Text.AlignRight
            // A FOLDER HAS NO SIZE WORTH PRINTING. The bytes of a directory
            // entry are a fact about the filesystem, not about the folder, and a
            // column of them reads as information while being none.
            text: root.entry.kind === "dir" ? "" : Files.humanSize(root.entry.size)
            font.pixelSize: Appearance.sizes.filesText
            color: Appearance.colour.textFaint
        }

        StyledText {
            id: rowDate

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: parent.dateWidth

            horizontalAlignment: Text.AlignRight
            text: Files.humanTime(root.entry.mtime)
            font.pixelSize: Appearance.sizes.filesText
            color: Appearance.colour.textFaint
        }
    }

    // WHERE THE POINTER IS, in this tile's own coordinates.
    //
    // Built from the PRESS plus the TRANSLATION, and not read off the centroid,
    // which is the obvious way and does not work. Three things were found by
    // logging it during a real drag:
    //
    //   `onCentroidChanged` is not a per-move signal. The centroid is a grouped
    //   property; the handler fires when the group is replaced, which is once,
    //   at activation.
    //   `centroid.position` at activation is (0, 0) - a corner nobody pressed.
    //   `centroid.position` after the first move is a large negative number,
    //   apparently in some other space once the grab has moved.
    //
    // `pressPosition` and `activeTranslation` are both stable and both in this
    // item's coordinates, and their sum is the answer. It is also what
    // components/CodeBlock.qml already drives its pan from, for the same reason.
    readonly property point pointer: Qt.point(drag.centroid.pressPosition.x + drag.activeTranslation.x, drag.centroid.pressPosition.y + drag.activeTranslation.y)

    // THE GESTURE. A drag that never moved is a click, which is why both live on
    // one handler rather than on a MouseArea plus a DragHandler racing for the
    // same press.
    DragHandler {
        id: drag

        // The tile itself must not move. What follows the pointer is a ghost
        // drawn by the face above (see FilesFace's drag layer), so the grid
        // underneath stays intact and can be dropped onto.
        target: null
        // A touchpad flick over a grid should scroll it, not throw a file
        // somewhere. Only a deliberate press-and-move picks something up.
        dragThreshold: Appearance.sizes.dragThreshold

        // AND THE GRID HAS TO LET GO OF IT. A GridView is a Flickable, and a
        // Flickable claims the grab the moment it decides a drag is its own -
        // which it decides about any drag that started inside it, meaning all of
        // them. Without this the press selects the file, the pointer moves, the
        // list quietly takes the gesture as a scroll, and nothing is ever picked
        // up. components/CodeBlock.qml hit the identical wall on the other axis.
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

    // CLICKS, WITH THEIR MODIFIERS. A MouseArea rather than a TapHandler,
    // because plain, Ctrl and Shift clicking are three different requests and a
    // handler that cannot tell them apart cannot select more than one file.
    //
    // It coexists with the drag: the DragHandler above is allowed to take the
    // grab from items (see grabPermissions), so a press that turns into a drag
    // leaves here and becomes a lift, and a press that does not is a click.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                root.menuRequested(Qt.point(mouse.x, mouse.y));
                return;
            }
            root.clicked(mouse.modifiers);
        }

        // SINGLE CLICK SELECTS, DOUBLE OPENS. The other convention - one click
        // opens - is unusable next to a drag: every attempt to pick a file up
        // that fell short of the threshold would open it instead.
        onDoubleClicked: mouse => {
            if (mouse.button === Qt.LeftButton)
                root.activated();
        }
    }
}
