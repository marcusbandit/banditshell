pragma ComponentBehavior: Bound

import QtQuick
import qs.config

// THE LINE BETWEEN TWO PANELS, and the way to move it.
//
// The same idea the terminal's top edge already uses, made into a component
// because the window has three of these now and three copies of a drag handle is
// three chances for one of them to feel different from the others.
//
// It is a SEPARATOR THAT TURNS OUT TO BE A CONTROL, rather than a control drawn
// on top of a separator: at rest it is the hairline that would have been there
// anyway, and it thickens and brightens under the pointer. The hit area is
// wider than the line, because a 2px target is a target you miss.
Item {
    id: root

    // Which way the line runs. A vertical line is dragged horizontally.
    property bool vertical: true

    // How far it has been dragged since the press, along its own axis.
    signal moved(real delta)
    signal committed

    implicitWidth: root.vertical ? Appearance.sizes.minTarget / 2 : 0
    implicitHeight: root.vertical ? 0 : Appearance.sizes.minTarget / 2

    Rectangle {
        anchors.centerIn: parent

        width: root.vertical ? (root.active ? Appearance.font.stem * 2 : Appearance.font.stem) : parent.width
        height: root.vertical ? parent.height : (root.active ? Appearance.font.stem * 2 : Appearance.font.stem)

        color: root.active ? Appearance.colour.text : Appearance.colour.separator
    }

    readonly property bool active: hover.hovered || drag.active

    HoverHandler {
        id: hover

        cursorShape: root.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
    }

    DragHandler {
        id: drag

        target: null
        xAxis.enabled: root.vertical
        yAxis.enabled: !root.vertical
        // The panels either side are Flickables; without this the first one to
        // decide the drag is its own takes it. See FileTile's note.
        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

        onActiveChanged: if (!active)
            root.committed()

        onActiveTranslationChanged: if (drag.active)
            root.moved(root.vertical ? drag.activeTranslation.x : drag.activeTranslation.y)
    }
}
