pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")
    readonly property bool isNiri: !!Quickshell.env("NIRI_SOCKET")

    readonly property string name: isHyprland ? "hyprland" : isNiri ? "niri" : "unknown"

    property bool available: false

    property real rounding: 0

    property real roundingPower: 2
    property real gapsOut: 0
    property real gapsIn: 0
    property real borderSize: 0

    property bool naturalScrollMouse: false
    property bool naturalScrollTouchpad: false
}
