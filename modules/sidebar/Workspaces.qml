pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// Which workspace indicator the sidebar is wearing.
//
// The styles are alternatives, not settings that combine: each is a whole answer
// to "what should a column of workspaces look like", and they share their layout
// and their motion (WorkspaceModel) so only the drawing is written more than
// once. Switch live with `banditshell set sidebar.workspaces.style <name>`.
// The model also owns the vertical scrub (run the column, step through
// workspaces), for a drag and for two fingers on a touchpad alike: a style
// wires each of its surfaces into scrubPress/scrubMove/scrubRelease and into
// scrubWheel, four lines, and gets both inputs with one recognition and one
// commit rather than an opinion of its own about what a swipe is. Today only
// `plates` does that, so the other two styles still switch by tap alone.
//
//   plates   floating G2 cells in the bar's own lane, one mark per window,
//            with ONE marker that travels to the workspace you are on and
//            another that travels to whatever the cursor is on. The one that
//            works. What the mark IS (the app's own icon in our colour, the
//            app's icon as shipped, or a category glyph) is
//            `sidebar.workspaces.iconMode`, not a style of its own.
//   map      no glyphs. Each window is a bar as long as the window is wide, so
//            the column shows the shape of the layout rather than its contents.
//   blocks   one square per window, one row per workspace, on the pixel grid.
//            The smallest the column can be and still say everything.
Item {
    id: root

    // WHICH SCREEN'S WORKSPACES, by output name, passed to whichever style is
    // loaded and no further business of this file.
    //
    // Every style needs it and none of them can find it for themselves without
    // each asking the surface the same question three files deep, so the
    // sidebar asks once and it comes down from there. This file spends it in
    // one place: whichever style the Loader ends up holding.
    required property string screen

    readonly property string style: Appearance.sizes.wsStyle

    // WHAT THE STYLE WANTS THE SHELL TO GROW, in this item's coordinates, passed
    // straight up (Sidebar.blobs). A blob is a shape handed to the chassis's
    // distance field rather than drawn: where one pokes out past the band the two
    // melt together instead of one being parked against the other, which is how
    // everything in this shell that leaves the body leaves it.
    //
    // Empty for a style that has nothing to add, which is two of the three. Asked
    // of the Loader's item rather than declared on each style, so a style that
    // never grows anything does not have to say so.
    readonly property var blobs: content.item?.blobs ?? []

    implicitHeight: content.item?.implicitHeight ?? 0

    Loader {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.implicitHeight

        sourceComponent: root.style === "map" ? map : root.style === "blocks" ? blocks : plates
    }

    Component {
        id: plates

        WorkspacePlates {
            screen: root.screen
        }
    }

    Component {
        id: map

        WorkspaceMap {
            screen: root.screen
        }
    }

    Component {
        id: blocks

        WorkspaceBlocks {
            screen: root.screen
        }
    }
}
