pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import qs.config

Item {
    id: root

    property bool active: false

    property string framePath: ""

    readonly property int cameras: devices.videoInputs.length

    readonly property bool running: cam.active

    readonly property bool ready: shot.readyForCapture

    signal failed(string message)

    signal saved

    function capture(): void {
        shot.captureToFile(root.framePath);
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

            onErrorOccurred: (error, message) => root.failed(message || "the camera would not start")
        }

        videoOutput: preview

        imageCapture: ImageCapture {
            id: shot

            onImageSaved: (id, path) => root.saved()
            onErrorOccurred: (id, error, message) => root.failed(message || "could not read from the camera")
        }
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

    SquircleRect {
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
