pragma ComponentBehavior: Bound

import Quickshell.Wayland

WlSessionLockSurface {
    id: surface

    color: "transparent"

    LockFace {
        anchors.fill: parent

        active: surface.visible

        output: surface.screen?.name ?? ""
    }
}
