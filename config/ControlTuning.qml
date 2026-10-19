pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property var values: Config.values.control

    readonly property real wheelRows: root.values.wheelRows
    readonly property real wheelNotch: root.values.wheelNotch
    readonly property real pullSlack: root.values.pullSlack
    readonly property real pullCommit: root.values.pullCommit
    readonly property real pullReversal: root.values.pullReversal
    readonly property real pullAngleCorner: root.values.pullAngleCorner
    readonly property int signalBands: root.values.signalBands
    readonly property bool naturalScroll: Compositor.naturalScrollTouchpad
}
