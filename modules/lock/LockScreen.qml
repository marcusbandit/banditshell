pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Scope {
    id: root

    WlSessionLock {
        id: lock

        locked: Lock.active

        LockSurface {
            lock: lock
        }
    }
}
