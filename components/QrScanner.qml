pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
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

    MediaDevices {
        id: devices
    }

    CaptureSession {
        id: session

        camera: Camera {
            id: cam

            cameraDevice: devices.defaultVideoInput

            active: root.active && devices.videoInputs.length > 0

            onErrorOccurred: (error, message) => root.trouble = message || "the camera would not start"
        }

        videoOutput: preview

        imageCapture: ImageCapture {
            id: shot

            onImageSaved: (id, path) => {
                if (root.decoder)
                    look.running = true;
            }
            onErrorOccurred: (id, error, message) => root.trouble = message || "could not read from the camera"
        }
    }

    onActiveChanged: if (root.active && devices.videoInputs.length === 0)
        root.trouble = "no camera on this machine"

    Timer {
        running: root.active && cam.active && !!root.decoder
        interval: root.beat
        repeat: true
        triggeredOnStart: true

        onTriggered: if (shot.readyForCapture && !root.reading)
            shot.captureToFile(root.framePath)
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

            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fillStrong
            }

            VideoOutput {
                id: preview

                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop

                transform: Scale {
                    origin.x: preview.width / 2
                    xScale: -1
                }

                layer.enabled: true
                visible: false
            }

            G2Rect {
                id: mask

                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: "white"
                layer.enabled: true
                visible: false
            }

            MultiEffect {
                anchors.fill: parent
                source: preview
                maskEnabled: true
                maskSource: mask
                visible: cam.active
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
