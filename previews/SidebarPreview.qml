import QtQuick
import Quickshell
import qs.config
import qs.modules
import qs.modules.sidebar

ShellRoot {
    id: preview

    readonly property string shots: Quickshell.env("BANDITSHELL_SHOTS") ?? ""
    readonly property bool rail: Appearance.sizes.sidebarRail

    property bool forced: false
    property int step: 0

    function shoot(name: string): void {
        console.log(`SHOT ${name}`);
        if (preview.shots !== "")
            stage.grabToImage(r => r.saveToFile(`${preview.shots}/${name}.png`));
    }

    Timer {
        interval: 2200
        running: true
        repeat: true

        onTriggered: {
            if (preview.step === 0) {
                preview.shoot(preview.rail ? "rest" : "full");
                if (preview.rail) {
                    preview.forced = true;
                    preview.step = 1;
                    return;
                }
                preview.step = 2;
                return;
            }
            if (preview.step === 1) {
                preview.shoot("open");
                preview.step = 2;
                return;
            }
            Qt.exit(0);
        }
    }

    FloatingWindow {
        implicitWidth: 360
        implicitHeight: 720
        color: "transparent"

        Item {
            id: stage

            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                color: Appearance.colour.surface
            }

            Chassis {
                id: chassis

                anchors.fill: parent

                railWanted: sidebar.railWanted || preview.forced

                panels: sidebar.blobs
            }

            Sidebar {
                id: sidebar

                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.topMargin: chassis.band
                anchors.bottomMargin: chassis.band
                width: chassis.barWidth

                fullWidth: chassis.fullBarWidth
                expansion: chassis.railOpen

                modeIcon: Quickshell.env("BANDITSHELL_MODE_ICON") ?? ""
            }
        }
    }
}
