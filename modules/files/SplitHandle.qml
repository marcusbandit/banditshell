pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Item {
    id: root

    property bool vertical: true

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

        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

        onActiveChanged: if (!active)
            root.committed()

        onActiveTranslationChanged: if (drag.active)
            root.moved(root.vertical ? drag.activeTranslation.x : drag.activeTranslation.y)
    }
}
