import QtQuick
import qs.config
import qs.components
import qs.modules.settings
import "../catalogue.js" as Catalogue

Item {
    id: root

    readonly property real stageHeight: 380
    readonly property bool fills: true

    readonly property string zone: Catalogue.zoneOf(SettingsView.hovered)
    readonly property real cw: copy.width
    readonly property real ch: Math.max(1, copy.height)
    readonly property rect area: root.zone ? (replica.zones[root.zone] ?? Qt.rect(0, 0, 0, 0)) : Qt.rect(0, 0, 0, 0)
    readonly property bool zoomed: root.zone !== "" && root.area.height > 0

    readonly property real wantScale: root.zoomed ? Math.min((root.height - 48) / Math.max(root.area.height, 60), (root.width - 48) / root.cw, 2.4) : Math.min((root.height - 32) / root.ch, (root.width - 32) / root.cw)
    readonly property real wantY: root.zoomed ? root.area.y + root.area.height / 2 : root.ch / 2

    Follow {
        id: zoom

        target: root.wantScale
        speed: Appearance.animation.revealSpeed
        epsilon: 0.001
    }

    Follow {
        id: focus

        target: root.wantY
        speed: Appearance.animation.revealSpeed
        epsilon: 0.1
    }

    Component.onCompleted: {
        zoom.snap();
        focus.snap();
    }

    Item {
        id: copy

        width: replica.width
        height: replica.naturalHeight
        x: root.width / 2 - root.cw / 2 * zoom.value
        y: root.height / 2 - focus.value * zoom.value
        transformOrigin: Item.TopLeft
        scale: zoom.value

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.surfaceSolid
            stroke: Appearance.colour.seam
            strokeWidth: 1
        }

        SidebarReplica {
            id: replica

            height: parent.height
            onPicked: key => SettingsView.focusRow(key)
        }
    }
}
