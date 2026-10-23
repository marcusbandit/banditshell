pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Item {
    id: root

    property bool active: false

    property string note: ""

    readonly property string status: root.trouble || root.note || (root.reading ? "reading" : "point it at the code")

    property string trouble: ""

    signal decoded(string text)

    property int beat: 500

    readonly property string framePath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-qr-${Quickshell.processId}.jpg`

    readonly property bool reading: look.running

    property string decoder: ""

    readonly property var camera: lens.item

    implicitWidth: parent ? parent.width : 0
    implicitHeight: body.implicitHeight

    Component.onDestruction: Quickshell.execDetached(["rm", "-f", root.framePath])

    Process {
        id: reader

        running: true
        command: ["sh", "-c", "command -v ZXingReader"]

        stdout: StdioCollector {
            onStreamFinished: root.decoder = text.trim()
        }

        onExited: code => {
            if (code !== 0)
                root.trouble = "no QR reader here; install zxing-cpp";
        }
    }

    onActiveChanged: {
        if (!root.active)
            return;
        if (!root.camera)
            root.trouble = "reading a QR code needs qt6-multimedia";
        else if (root.camera.cameras === 0)
            root.trouble = "no camera on this machine";
    }

    Timer {
        running: root.active && (root.camera?.running ?? false) && !!root.decoder
        interval: root.beat
        repeat: true
        triggeredOnStart: true

        onTriggered: if (root.camera.ready && !root.reading)
            root.camera.capture()
    }

    Process {
        id: look

        command: [root.decoder, "-json", "-single", "-fast", "-formats", "QRCode", root.framePath]

        stdout: StdioCollector {
            onStreamFinished: {

                const line = text.trim();
                if (!line)
                    return;
                try {
                    const found = JSON.parse(line.split("\n")[0]);
                    if (found.Text)
                        root.decoded(found.Text);
                } catch (e) {

                    root.trouble = "the QR reader said something unexpected";
                }
            }
        }
    }

    Column {
        id: body

        width: root.width
        spacing: Appearance.padding.small

        Item {
            id: frame

            width: parent.width

            height: Math.round(width * 3 / 4)

            SquircleRect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fillStrong
            }

            Loader {
                id: lens

                anchors.fill: parent
                source: Qt.resolvedUrl("QrCamera.qml")

                onLoaded: {
                    lens.item.active = Qt.binding(() => root.active);
                    lens.item.framePath = Qt.binding(() => root.framePath);
                }
            }

            Connections {
                target: lens.item

                function onFailed(message: string): void {
                    root.trouble = message;
                }

                function onSaved(): void {
                    if (root.decoder)
                        look.running = true;
                }
            }
        }

        StyledText {
            width: parent.width
            leftPadding: Appearance.padding.normal
            text: root.status
            color: root.trouble ? Appearance.colour.accent : Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            wrapMode: Text.WordWrap
        }
    }
}
