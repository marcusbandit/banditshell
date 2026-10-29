pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string device: String(Config.values.pen.device ?? "")
    readonly property string lower: String(Config.values.pen.lowerButton ?? Config.defaults.pen.lowerButton)
    readonly property string upper: String(Config.values.pen.upperButton ?? Config.defaults.pen.upperButton)

    readonly property bool remapped: root.lower !== Config.defaults.pen.lowerButton || root.upper !== Config.defaults.pen.upperButton
    readonly property bool wanted: Config.ready && Config.values.pen.enabled === true && root.remapped && root.device !== ""
    readonly property string signature: `${root.device}|${root.lower}|${root.upper}`

    property string state: ""
    property string ranWith: ""

    function sync(): void {
        if (!root.wanted) {
            root.state = "";
            helper.running = false;
            return;
        }
        if (helper.running) {
            if (root.ranWith !== root.signature)
                helper.running = false;
            return;
        }
        root.ranWith = root.signature;
        helper.command = ["python3", Quickshell.shellPath("scripts/pen-buttons.py"), "--device", root.device, "--lower", root.lower, "--upper", root.upper];
        helper.running = true;
    }

    onSignatureChanged: root.sync()
    onWantedChanged: root.sync()

    Component.onCompleted: root.sync()

    Process {
        id: helper

        stdout: SplitParser {
            onRead: line => root.state = line.trim()
        }

        stderr: SplitParser {
            onRead: line => console.warn("PenButtons:", line)
        }

        onExited: {
            root.state = "";
            retry.restart();
        }
    }

    Timer {
        id: retry

        interval: 2000
        onTriggered: root.sync()
    }
}
