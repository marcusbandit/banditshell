import QtQuick
import qs.config
import qs.modules.settings

QtObject {
    id: root

    property int duration: 4800
    property bool live: true
    property real still: 1

    readonly property bool moving: root.live && SettingsView.sceneSeen && !SettingsView.reduceMotion && !Appearance.lessMotion

    property real t: 0

    readonly property real value: root.moving ? root.t : root.still

    readonly property NumberAnimation run: NumberAnimation {
        target: root
        property: "t"
        from: 0
        to: 1
        duration: root.duration
        loops: Animation.Infinite
        running: root.moving
    }
}
