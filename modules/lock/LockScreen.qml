pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Scope {
    id: root

    PersistentProperties {
        id: persisted

        reloadableId: "lockScreen"

        property bool held: false

        onReloaded: if (persisted.held)
            Lock.lock()
    }

    Connections {
        target: Lock

        function onActiveChanged(): void {
            persisted.held = Lock.active;
        }
    }

    WlSessionLock {
        id: session

        locked: Lock.active

        LockSurface {}
    }
}
