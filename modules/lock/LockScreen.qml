pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

Scope {
    id: root

    property bool settled: false

    function report(): void {
        if (root.settled)
            Lock.observe(session.locked, session.secure);
    }

    PersistentProperties {
        id: persisted

        reloadableId: "lockScreen"

        property bool held: false

        onReloaded: if (persisted.held)
            Lock.relock()
    }

    Connections {
        target: Lock

        function onActiveChanged(): void {
            persisted.held = Lock.active;
            Qt.callLater(root.report);
        }
    }

    WlSessionLock {
        id: session

        locked: Lock.active

        onLockedChanged: Qt.callLater(root.report)
        onSecureChanged: Qt.callLater(root.report)

        LockSurface {}
    }

    PersistentProperties {
        onLoaded: {
            root.settled = true;
            root.report();
        }
    }
}
