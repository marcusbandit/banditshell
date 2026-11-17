import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.components
import qs.modules.mixer

ShellRoot {
    id: root

    readonly property string shot: Quickshell.env("BANDITSHELL_SHOTS") ?? ""
    readonly property int pick: Number(Quickshell.env("MIXER_PICK") ?? 0)

    PanelWindow {
        anchors.left: true
        anchors.top: true

        implicitWidth: stage.width
        implicitHeight: stage.height

        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-mixerpreview"

        Rectangle {
            id: stage

            width: Number(Quickshell.env("MIXER_WIDTH") ?? 0) || Math.round(Appearance.sizes.launcherWidth * 1.15)
            height: Number(Quickshell.env("MIXER_HEIGHT") ?? 0) || Math.round(Appearance.sizes.launcherWidth * 0.85)
            color: Appearance.colour.surfaceSolid

            MixerView {
                id: view

                anchors.fill: parent
                anchors.margins: Appearance.padding.large
                showsSelection: root.pick > 0
            }
        }
    }

    Timer {
        interval: 600
        running: root.pick > 0
        onTriggered: view.move(root.pick)
    }

    Timer {
        interval: Number(Quickshell.env("MIXER_SHOT_DELAY") ?? 0) || 5000
        running: root.shot !== ""
        onTriggered: stage.grabToImage(result => {
            result.saveToFile(root.shot);
            Qt.exit(0);
        })
    }
}
