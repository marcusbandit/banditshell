pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.config
import "squircle.js" as Squircle

Item {
    id: root

    property string text: ""

    property string caption: ""
    property string detail: ""

    property bool colourful: true

    property bool flippable: false

    property string tip: ""

    signal flipped

    readonly property color leaf: Appearance.colour.spectrum[Appearance.colour.spectrum.length - 1]
    readonly property color pine: Appearance.blend(Appearance.colour.spectrum[0], Appearance.colour.ink, 0.7)

    readonly property color plate: root.colourful ? root.leaf : Appearance.colour.paper
    readonly property color pen: root.colourful ? root.pine : Appearance.colour.ink

    readonly property int quiet: 4

    readonly property string level: "M"

    property var matrix: []

    readonly property int span: root.matrix.length
    readonly property bool ready: root.span > 0

    property string trouble: ""

    property string encoder: ""

    property real maxHeight: 0

    implicitWidth: parent ? parent.width : 0
    implicitHeight: root.side + root.hem

    readonly property real gutter: root.span ? root.quiet / (root.span + root.quiet * 2) : 0

    readonly property real side: {
        if (root.maxHeight <= 0 || !root.ready)
            return root.width;
        const room = (root.maxHeight - words.implicitHeight) / (1 + root.gutter);
        return Math.max(0, Math.min(root.width, room));
    }

    readonly property real hem: root.ready && words.implicitHeight > 0 ? words.implicitHeight + root.quiet * root.module : 0

    readonly property real module: root.span ? root.side / (root.span + root.quiet * 2) : 0

    Process {
        running: true
        command: ["sh", "-c", "command -v qrencode"]

        stdout: StdioCollector {
            onStreamFinished: root.encoder = text.trim()
        }

        onExited: code => {
            if (code !== 0)
                root.trouble = "no QR writer here; install qrencode";
        }
    }

    onTextChanged: root.encode()
    onEncoderChanged: root.encode()

    function encode(): void {
        write.running = false;
        root.matrix = [];
        if (!root.encoder || !root.text)
            return;

        write.command = [root.encoder, "-o", "-", "-t", "ASCII", "-m", "0", "-l", root.level, "--", root.text];
        write.running = true;
    }

    Process {
        id: write

        stdout: StdioCollector {
            onStreamFinished: {

                const lines = text.split("\n").filter(l => l.length > 0);
                const grid = lines.map(l => {
                    const row = [];
                    for (let i = 0; i + 1 < l.length; i += 2)
                        row.push(l[i] === "#");
                    return row;
                });
                if (!grid.length || grid.some(r => r.length !== grid.length)) {
                    root.trouble = "the QR writer said something unexpected";
                    return;
                }
                root.trouble = "";
                root.matrix = grid;
            }
        }
    }

    readonly property var figures: root.carve()

    function carve(): var {
        const n = root.span;
        const m = root.module;
        if (!n || m <= 0)
            return [];

        const r = m / 2;
        const power = Appearance.rounding.power;
        const grid = root.matrix;
        const edge = root.quiet * m;

        const bleed = Math.max(0.5, m * 0.05);

        const dark = (row, col) => row >= 0 && row < n && col >= 0 && col < n && grid[row][col];

        const out = new Array(n * 2 - 1).fill("");
        for (let row = 0; row < n; row++) {
            for (let col = 0; col < n; col++) {
                if (!grid[row][col])
                    continue;
                const up = dark(row - 1, col);
                const down = dark(row + 1, col);
                const left = dark(row, col - 1);
                const right = dark(row, col + 1);

                const x = edge + col * m - (left ? bleed : 0);
                const y = edge + row * m - (up ? bleed : 0);
                const w = m + (left ? bleed : 0) + (right ? bleed : 0);
                const h = m + (up ? bleed : 0) + (down ? bleed : 0);

                out[row + col] += Squircle.path(w, h, up || left ? 0 : r, up || right ? 0 : r, down || right ? 0 : r, down || left ? 0 : r, power, x, y);
            }
        }
        return out;
    }

    property real sweep: 0
    property real turn: root.colourful ? 1 : 0

    readonly property real spread: 0.25

    function phase(i: int, progress: real): real {
        const n = root.figures.length;
        if (n < 1)
            return 0;
        const start = (i / n) * (1 - root.spread);
        return Math.max(0, Math.min(1, (progress - start) / root.spread));
    }

    onFiguresChanged: {
        root.sweep = 0;
        if (root.figures.length)
            wave.restart();
    }

    NumberAnimation {
        id: wave

        target: root
        property: "sweep"
        from: 0
        to: 1
        duration: Appearance.anim.slow * 3
        easing.type: Easing.OutSine
    }

    Behavior on turn {
        NumberAnimation {
            duration: Appearance.anim.slow * 2
            easing.type: Easing.InOutSine
        }
    }

    function hue(i: int): color {
        const n = root.figures.length;
        const at = n > 1 ? i / (n - 1) : 0;
        return Appearance.blend(Appearance.colour.ink, Appearance.blend(root.pine, Appearance.colour.spectrum[0], at / 3), root.phase(i, root.turn));
    }

    Item {
        id: face

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: root.side
        height: root.side + root.hem

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.large
            color: root.plate
            opacity: root.ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.slow * 2
                }
            }
        }

        Repeater {
            model: root.figures

            delegate: Shape {
                id: band

                required property int index
                required property string modelData

                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                asynchronous: true

                opacity: root.phase(band.index, root.sweep)

                ShapePath {
                    fillColor: root.hue(band.index)
                    strokeColor: "transparent"
                    fillRule: ShapePath.WindingFill

                    PathSvg {
                        path: band.modelData
                    }
                }
            }
        }

        Column {
            id: words

            anchors.top: parent.top
            anchors.topMargin: root.side
            anchors.left: parent.left
            anchors.leftMargin: root.quiet * root.module
            anchors.right: parent.right
            anchors.rightMargin: root.quiet * root.module

            opacity: root.ready ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

            StyledText {
                width: parent.width
                visible: !!root.caption
                text: root.caption

                color: root.pen
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.slow * 2
                    }
                }
            }

            StyledText {
                width: parent.width
                visible: !!root.detail
                text: root.detail
                color: Appearance.shade(root.pen, 1)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.slow * 2
                    }
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.flippable && root.ready
            cursorShape: Qt.PointingHandCursor
            onClicked: root.flipped()
        }

        HoverTip {
            text: root.flippable && root.ready ? root.tip : ""
        }
    }
}
