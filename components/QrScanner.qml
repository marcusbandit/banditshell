pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.config

// A CAMERA, POINTED AT A SQUARE OF DOTS.
//
// The one thing in this shell that reads the outside world rather than the
// machine. It shows what the camera sees, takes a frame off it a couple of times
// a second, and hands whatever it finds in that frame to whoever asked.
//
// IT DOES NOT KNOW WHAT A WI-FI CODE IS, on purpose. It emits the string a
// barcode carried; deciding whether that string is a network, and what to do
// about it, belongs to the thing that opened the camera. That is the same split
// every other component here makes, and it is what keeps this reusable for the
// next code somebody wants to point at.
//
// NOTHING HERE EXISTS UNTIL IT IS ASKED FOR. Instantiate it behind a Loader:
// building it loads the QtMultimedia plugin and enumerates the video devices,
// which is not work a menu should do on the chance that somebody might scan
// something. The camera itself opens only while `active`.
//
// THE DECODER IS A PROCESS, and that is a considered exception rather than a
// habit. Quickshell has no barcode reader and Qt has none either; a QR decoder
// is a few thousand lines of Reed-Solomon and perspective correction that this
// shell is not going to grow in QML. zxing-cpp ships one as `ZXingReader`, it
// reads a file and prints a line of JSON, and that is the whole of the contract.
// This is not the wall NetworkMenu's header refuses to climb: that one is about
// driving NetworkManager through a CLI when there is a real API right there.
// Here there is no API at all.
//
// If the reader is missing the scanner says so rather than looking broken, which
// is the only reasonable thing to do about a dependency that is one package.
Item {
    id: root

    // Whether the camera is open. The lens is a shared, singular, physically
    // visible resource, so this is deliberately not derived from anything: the
    // caller says when, and says it once.
    property bool active: false

    // A line under the picture, for whoever owns the outcome of a scan. What is
    // wrong with the SCANNER itself is `trouble`, and it wins: a camera that
    // will not start is a more urgent sentence than anything about a network.
    property string note: ""

    readonly property string status: root.trouble || root.note || (root.reading ? "reading" : "point it at the code")

    property string trouble: ""

    signal decoded(string text)

    // HOW OFTEN A FRAME IS READ.
    //
    // A decode of a 1080p frame is about forty milliseconds of one core, so the
    // choice here is between a scanner that answers the instant a code is in
    // shot and one that can be left open without being felt. Twice a second is
    // faster than a hand can aim and steady a card, which is the actual limit on
    // how quickly this can ever succeed, and it leaves the core alone for the
    // other ninety percent of the time.
    property int beat: 500

    // WHERE THE FRAME GOES. The runtime directory, because a frame off the
    // camera is exactly the kind of thing that should not outlive the session
    // that took it, and it is a tmpfs so this never touches a disk. Per process,
    // so two shells cannot read each other's half-written frames.
    readonly property string framePath: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-qr-${Quickshell.processId}.jpg`

    // ONE FRAME IN FLIGHT AT A TIME. The capture writes to a fixed path and the
    // reader reads it, so a second capture arriving mid-read would rewrite the
    // file under the decoder and it would decode half of one frame and half of
    // another.
    readonly property bool reading: look.running

    // Where the decoder is, once the probe below has found it.
    property string decoder: ""

    implicitWidth: parent ? parent.width : 0
    implicitHeight: body.implicitHeight

    Component.onDestruction: Quickshell.execDetached(["rm", "-f", root.framePath])

    // WHERE THE DECODER IS, asked once rather than assumed. A missing binary
    // makes a Process fail in a way that is indistinguishable from a frame with
    // nothing in it, so the scanner would have sat there looking attentive and
    // never finding anything.
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
            // The one place the lens is actually opened, and it is one term:
            // what the caller asked for, and there being something to open.
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

    // NOTHING TO POINT, said plainly. A machine with no camera is a perfectly
    // ordinary machine, and a black rectangle is not an explanation.
    onActiveChanged: if (root.active && devices.videoInputs.length === 0)
        root.trouble = "no camera on this machine"

    // THE BEAT, and the two conditions that are asked in different places.
    //
    // Whether there is a lens open and something to decode with is a fact about
    // the session, and it starts and stops the timer. Whether the camera has a
    // frame to give and whether the last one has been read yet are facts about
    // this instant, and they are asked INSIDE the tick.
    //
    // Putting either of those in `running` was the first version and it captured
    // flat out: `readyForCapture` goes false for the length of a capture, which
    // stops the timer, and it coming back true restarts a timer that fires on
    // start. Every capture immediately asked for the next one, and the interval
    // was never once waited out.
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

        // -single stops at the first code, -fast skips lines during detection
        // and -formats confines it to QR: a frame of a room contains no
        // barcodes at all, and the whole cost of this is the search that fails.
        command: [root.decoder, "-json", "-single", "-fast", "-formats", "QRCode", root.framePath]

        stdout: StdioCollector {
            onStreamFinished: {
                // Empty is the normal answer: most frames have nothing in them.
                const line = text.trim();
                if (!line)
                    return;
                try {
                    const found = JSON.parse(line.split("\n")[0]);
                    if (found.Text)
                        root.decoded(found.Text);
                } catch (e) {
                    // A reader that printed something unparseable is a reader
                    // whose output format moved. Saying so beats a scanner that
                    // silently never finds anything.
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
            // FOUR BY THREE, which is what a webcam is, rather than whatever the
            // panel's width happens to make. The picture is cropped to fill, so
            // the aspect only decides how much of the sensor is thrown away; a
            // shape further from the camera's own throws away more of exactly
            // the space a code has to be found in.
            height: Math.round(width * 3 / 4)

            // Something under the picture for the second it takes a camera to
            // wake up, so the layer unrolls onto a plate rather than onto a hole.
            G2Rect {
                anchors.fill: parent
                radius: Appearance.rounding.normal
                color: Appearance.colour.fillStrong
            }

            // MASKED, NOT CLIPPED, for the reason G2Image exists: a texture
            // keeps its own square corners inside a rounded plate, and a square
            // corner a pixel inside a G2 one is the most visible way there is to
            // get a corner wrong. Same construction, different source.
            VideoOutput {
                id: preview

                anchors.fill: parent
                fillMode: VideoOutput.PreserveAspectCrop

                // MIRRORED, because the camera is on this side of the screen and
                // the thing being scanned is in your own hand. Unmirrored, moving
                // the card left moves the picture right, which is the same reason
                // nobody ships an unmirrored selfie preview. It costs the decode
                // nothing: that reads the FILE, which is never flipped, and a QR
                // code is readable mirrored anyway.
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
