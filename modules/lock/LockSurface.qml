pragma ComponentBehavior: Bound

import Quickshell.Wayland

WlSessionLockSurface {
    id: surface

    required property WlSessionLock lock

    color: "black"

    LockFace {
        anchors.fill: parent

        active: surface.visible

        output: surface.screen?.name ?? ""
    }
}
