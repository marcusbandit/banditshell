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

    property bool selected: false
    // Something is being dragged and it is over THIS tile, which only means
    // anything for a directory: a file dropped on a file has nowhere to go.
    property bool receiving: false

    readonly property bool droppable: root.entry.kind === "dir" && root.entry.open
    readonly property bool isImage: root.entry.class === "image" && !root.entry.broken

    signal clicked
    signal activated
    signal lifted(point position)
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
        color: root.receiving ? Appearance.colour.accentFill : root.selected ? Appearance.colour.fillStrong : hover.hovered ? Appearance.colour.fill : "transparent"

        // A DROP TARGET IS OUTLINED, not filled harder. The tile under the
        // pointer has to say "this one" while the thing being dropped is
        // floating over it and partly covering it, and an outline survives being
        // covered in a way a fill does not.
        stroke: root.receiving ? Appearance.colour.accent : "transparent"
        strokeWidth: root.receiving ? Appearance.font.stem : 0

        Behavior on color {
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    HoverHandler {
        id: hover
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - Appearance.padding.small * 2
        spacing: Appearance.padding.small

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
            height: root.height * 0.56

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
                size: Math.min(parent.height, root.width * 0.5)
            }
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter

            text: root.entry.name
            // TWO LINES, then elide. One line elides half the names in a
            // directory of anything real; three makes the tiles different
            // heights, and a grid whose rows do not line up is a grid you cannot
            // read down.
            maximumLineCount: 2
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
        }
    }

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

        onActiveChanged: {
            if (active)
                root.lifted(drag.centroid.scenePosition);
            else
                root.dropped(drag.centroid.scenePosition);
        }

        onCentroidChanged: if (active)
            root.dragged(drag.centroid.scenePosition)
    }

    TapHandler {
        // SINGLE CLICK SELECTS, DOUBLE OPENS. The other convention - one click
        // opens - is unusable next to a drag: every attempt to pick a file up
        // that fell short of the threshold would open it instead.
        onSingleTapped: root.clicked()
        onDoubleTapped: root.activated()
    }
}
