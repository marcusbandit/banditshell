pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property bool sleeping: false

    signal lockRequested

    function requestLock(): void {
        root.lockRequested();
    }
}
