pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property string screen

    readonly property real mark: Math.max(3, Math.round(Appearance.sizes.railWidth * 0.27))

    implicitHeight: layout.total

    function slotAt(y: real): int {
        for (let i = 0; i < layout.count; i++) {
            const g = layout.at(i);
            if (y >= g.y - layout.gap / 2 && y <= g.y + g.h + layout.gap / 2)
                return i;
        }
        return -1;
    }

    WorkspaceModel {
        id: layout

        screen: root.screen
        base: root.mark
        pitch: Math.round(root.mark * 0.8)
        gap: root.mark
    }

    MouseArea {
        id: backstop

        anchors.left: parent.left
        anchors.right: parent.right
        height: layout.total
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: layout.scrubbing

        onPressed: mouse => {
            const p = backstop.mapToItem(null, mouse.x, mouse.y);
            layout.scrubPress(p.x, p.y);
        }

        onPositionChanged: mouse => {
            if (!backstop.pressed)
                return;
            const p = backstop.mapToItem(null, mouse.x, mouse.y);
            layout.scrubMove(p.x, p.y);
        }

        onReleased: mouse => {
            if (layout.scrubRelease())
                return;
            const i = root.slotAt(mouse.y);
            if (i >= 0)
                Hypr.switchTo(layout.idAt(i));
        }

        onCanceled: layout.scrubCancel()

        onWheel: wheel => layout.scrubWheel(wheel)
    }

    Repeater {
        model: layout.count

        delegate: SquircleRect {
            id: pip

            required property int index

            readonly property var geom: layout.at(pip.index)
            readonly property var info: layout.slots[pip.index]
            readonly property bool isActive: layout.active === layout.idAt(pip.index)
            readonly property bool isOccupied: (pip.info?.windows?.length ?? 0) > 0

            x: Math.round((root.width - width) / 2)
            y: pip.geom.y
            width: Math.round(root.mark * (1 + lit.value))
            height: Math.max(0, pip.geom.h)
            radius: Math.min(Appearance.rounding.small, Math.min(width, height) / 2)

            color: pip.isOccupied ? Appearance.colour.textDim : Appearance.colour.textGhost

            SquircleRect {
                anchors.fill: parent
                radius: pip.radius
                color: Appearance.colour.accent
                opacity: lit.value
            }

            Follow {
                id: lit

                target: pip.isActive ? 1 : 0
                speed: Appearance.animation.trackSpeed
                epsilon: 0.005
            }

            Component.onCompleted: lit.snap()
        }
    }
}
