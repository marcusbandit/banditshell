pragma ComponentBehavior: Bound

import Quickshell
import qs.config
import qs.services

Scope {
    id: root

    required property ShellScreen screen

    readonly property var win: Shell.forScreen(root.screen?.name ?? "")

    readonly property int keyboard: root.win?.keyboard?.open && Tablet.docked ? root.win.keyboard.reserveHeight : 0

    readonly property bool bare: Appearance.bare
    readonly property var reserve: ({
            top: root.bare ? 0 : Appearance.sizes.border,
            right: root.bare ? 0 : Appearance.sizes.border,
            bottom: root.bare ? root.keyboard : Math.max(Appearance.sizes.border, root.keyboard),
            left: root.bare ? 0 : Appearance.sizes.border + (SidebarState.visibleOn(root.screen?.name ?? "") ? Appearance.sizes.sidebarWidth : 0)
        })

    Variants {
        model: ["top", "right", "bottom", "left"]

        PanelWindow {
            id: edge

            required property string modelData
            readonly property bool horizontal: modelData === "top" || modelData === "bottom"
            readonly property int size: root.reserve[modelData]

            screen: root.screen
            color: "transparent"

            anchors {
                top: edge.horizontal ? edge.modelData === "top" : true
                bottom: edge.horizontal ? edge.modelData === "bottom" : true
                left: edge.horizontal ? true : edge.modelData === "left"
                right: edge.horizontal ? true : edge.modelData === "right"
            }

            implicitWidth: edge.size
            implicitHeight: edge.size
            exclusiveZone: edge.size

            mask: Region {
                width: 0
                height: 0
            }
        }
    }
}
