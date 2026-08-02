import QtQuick
import qs.config

// Which workspace indicator the sidebar is wearing.
//
// The styles are alternatives, not settings that combine: each is a whole answer
// to "what should a column of workspaces look like", and they share their layout
// and their motion (WorkspaceModel) so only the drawing is written more than
// once. Switch live with `banditshell set sidebar.workspaces.style <name>`.
//
//   plates   index tabs hinged on the screen's edge, length as state, one mark
//            per window. The one that works. What the mark IS (the app's own
//            icon in our colour, the app's icon as shipped, or a category
//            glyph) is `sidebar.workspaces.iconMode`, not a style of its own.
//   map      no glyphs. Each window is a bar as long as the window is wide, so
//            the column shows the shape of the layout rather than its contents.
//   blocks   one square per window, one row per workspace, on the pixel grid.
//            The smallest the column can be and still say everything.
Item {
    id: root

    readonly property string style: Appearance.sizes.wsStyle

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

        WorkspacePlates {}
    }

    Component {
        id: map

        WorkspaceMap {}
    }

    Component {
        id: blocks

        WorkspaceBlocks {}
    }
}
