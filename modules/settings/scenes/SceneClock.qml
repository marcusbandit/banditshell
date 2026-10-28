import QtQuick
import qs.config
import qs.modules.settings

QtObject {
    id: root

    property int duration: 4800
    property bool live: true
    property bool seen: SettingsView.sceneSeen
    property real still: 1
    property int passes: 2
    property bool rested: false

    readonly property bool moving: root.live && root.seen && !root.rested && !SettingsView.reduceMotion && !Appearance.lessMotion

    property real t: 0

    readonly property real value: root.moving ? root.t : root.still

    readonly property Connections replay: Connections {
        target: SettingsView

        function onReplaysChanged(): void {
            root.rested = false;
            if (root.moving)
                root.rest.restart();
        }
    }

    readonly property NumberAnimation run: NumberAnimation {
        target: root
        property: "t"
        from: 0
        to: 1
        duration: root.duration
        loops: Animation.Infinite
        running: root.moving
    }

    readonly property Timer rest: Timer {
        interval: root.duration * root.passes
        running: root.moving
        onTriggered: root.rested = true
    }
}
