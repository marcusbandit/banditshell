pragma ComponentBehavior: Bound

import Quickshell.Wayland
import qs.config

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
