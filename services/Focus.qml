pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property string focusedScreen: ""

    property bool offStagePinned: false
    property string pinnedScreen: ""

    readonly property string offStageScreen: root.offStagePinned ? root.pinnedScreen : root.focusedScreen
}
