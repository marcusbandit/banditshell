import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.modules.lock

ShellRoot {
    id: root

    property int step: 0

    readonly property var script: [
        [1200, () => face.awake = false],
        [1800, () => {
                face.awake = true;
                face.typed = 1;
            }],
        [140, () => face.typed = 2],
        [140, () => face.typed = 3],
        [140, () => face.typed = 4],
        [140, () => face.typed = 5],
        [140, () => face.typed = 6],
        [1500, () => {
                face.typed = 0;
                face.send(6);
            }],
        [60, () => {
                face.failed = true;
                face.status = "wrong password";
                face.refuse();
            }],
        [900, () => {
                face.status = "";
                face.typed = 1;
            }],
        [140, () => face.typed = 2],
        [140, () => face.typed = 3],
        [140, () => face.typed = 4],
        [140, () => face.typed = 5],
        [140, () => face.typed = 6],
        [140, () => face.typed = 7],
        [500, () => {
                face.typed = 0;
                face.send(7);
                face.opening = true;
            }]
    ]

    Timer {
        running: root.step < root.script.length
        interval: root.script[Math.min(root.step, root.script.length - 1)][0]
        onTriggered: {
            root.script[root.step][1]();
            root.step++;
        }
    }

    PanelWindow {
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "banditshell-lockpreview"

        mask: Region {
            width: 0
            height: 0
        }

        LockFace {
            id: face

            anchors.fill: parent
            active: true

            typed: 0
            opening: false
            failed: false
            status: ""
            bloom: true
            awake: true
        }
    }
}
