pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import qs.config
import "squircle.js" as Squircle

// A SQUARE OF DOTS, POINTED OUTWARD.
//
// The other half of QrScanner. That one turns a picture into a string; this one
// turns a string into a picture, and like that one it DOES NOT KNOW WHAT A
// WI-FI CODE IS. It is handed text and it draws it. Deciding what the text
// means belongs to whoever asked, which is what keeps this reusable for the next
// thing somebody wants to hold up to a phone.
//
// THE ENCODER IS A PROCESS, the same considered exception QrScanner makes and
// for the same reason: Quickshell has no barcode writer and Qt has none either,
// and Reed-Solomon over GF(256) plus mask selection is not something this shell
// is going to grow in QML. `qrencode` writes one, it prints the matrix as
// characters, and that is the whole of the contract.
//
// BUT ONLY THE MATRIX COMES FROM IT. qrencode will happily write a PNG or an
// SVG, and every one of them would arrive as somebody else's idea of what a code
// looks like: black, square, and unaware that it is being drawn on a G2 shell.
// So it is asked for `-t ASCII`, which is the bits and nothing else, and the
// drawing happens here in the same primitive every other rounded thing in this
// shell is made of.
Item {
    id: root

    // What the code carries. Anything; it is encoded as bytes.
    property string text: ""

    // INK ON PAPER, and by default the most contrast the theme owns.
    //
    // A code is not read by a person, it is read by a camera that thresholds a
    // picture into two piles, so this is the one thing in the shell with no
    // business being translucent or tinted. See Appearance's note on the pair.
    property color ink: Appearance.colour.ink
    property color paper: Appearance.colour.paper

    // A line under the code, on the card, in ink. What the code is FOR: a phone
    // that has already scanned it shows nothing, and the person holding the
    // laptop should be able to see they are offering the right network.
    property string caption: ""

    // THE QUIET ZONE, which is part of the code rather than part of the design.
    //
    // The spec asks for four clear modules on every side and decoders genuinely
    // use them to find the symbol's edge. It is not padding and it does not get
    // tightened to taste; it is drawn as the plate's own margin, so the card is
    // correct by construction rather than by somebody remembering.
    readonly property int quiet: 4

    // Error correction. M recovers a quarter of the symbol, which is what pays
    // for the rounding below: a module drawn as a disc gives up the corners of
    // its cell, and a code with headroom does not care.
    readonly property string level: "M"

    // The matrix, one array of booleans per row, true where a module is dark.
    property var matrix: []

    readonly property int span: root.matrix.length
    readonly property bool ready: root.span > 0

    property string trouble: ""

    // Where the encoder is, asked once rather than assumed. See QrScanner: a
    // missing binary fails in a way that is indistinguishable from a code that
    // simply never appeared.
    property string encoder: ""

    implicitWidth: parent ? parent.width : 0
    // The code and its quiet zone are square and fill the plate's width; a
    // caption adds a band under them. That band is the quiet zone said again,
    // so the space around the writing matches the space around the code and the
    // card has one margin rather than two that nearly agree.
    implicitHeight: root.width + (root.caption && root.ready ? label.implicitHeight + root.quiet * root.module : 0)

    // ONE MODULE, in pixels. The code and both quiet zones divide the plate, so
    // the whole card is sized from the symbol's own module count and nothing
    // here is a chosen number. A denser code just draws smaller.
    readonly property real module: root.span ? root.width / (root.span + root.quiet * 2) : 0

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

    // RE-RUN WHENEVER THE STRING CHANGES, which is what the explicit restart is
    // for: `running` bound to a condition that is already true would not fire
    // again, and the card would keep showing the previous network's code.
    onTextChanged: root.encode()
    onEncoderChanged: root.encode()

    // THE COMMAND IS SET, NOT BOUND, which is the difference between one run per
    // string and a race. A bound `command` updates the instant `text` does,
    // which is not necessarily before the handler that stops the process reading
    // the old one, and the losing order rewrites the arguments of a running
    // encoder.
    function encode(): void {
        write.running = false;
        root.matrix = [];
        if (!root.encoder || !root.text)
            return;
        // `-m 0` because the quiet zone is the plate's own margin, and a margin
        // baked into the matrix would be four rows of nothing that the layout
        // then has to know about. `--` because a string beginning with a dash is
        // a perfectly ordinary string and not an option.
        write.command = [root.encoder, "-o", "-", "-t", "ASCII", "-m", "0", "-l", root.level, "--", root.text];
        write.running = true;
    }

    Process {
        id: write

        stdout: StdioCollector {
            onStreamFinished: {
                // Two characters per module, `##` dark and two spaces light, one
                // line per row. Anything that is not that square is not a matrix
                // and is better refused than half-drawn.
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

    // THE PLATE. The one bright object in this menu, and deliberately: it is
    // held up to a camera, and a camera in a dim room wants the light coming off
    // the screen rather than out of the ceiling.
    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.large
        color: root.paper
        opacity: root.ready ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.normal
            }
        }
    }

    // EVERY MODULE IS A G2 SQUIRCLE, AND ITS CORNERS ASK THEIR NEIGHBOURS.
    //
    // A code drawn as plain squares is the one shape in this shell with a hard
    // 90 degree corner on it, and rounding each module on its own is the usual
    // way that gets fixed and the wrong one: it turns every run of dark modules
    // into a string of separate beads, throws away the ink between them, and
    // gives the decoder less of the symbol than it was promised.
    //
    // So a corner is rounded only where BOTH of its edges are actually exposed.
    // A module with a dark neighbour above keeps its top two corners square and
    // the two of them read as one bar; a module alone in its cell spends its
    // whole budget on all four and reads as a disc. The ink is exactly the ink a
    // square code would have had, minus the corners that were touching nothing,
    // so it decodes like an ordinary code and looks like it belongs here.
    //
    // Radius is half a module, which is the point at which the corner budget is
    // fully spent (see Expander) and therefore the only radius that is not a
    // number somebody picked.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true

        ShapePath {
            fillColor: root.ink
            strokeColor: "transparent"
            fillRule: ShapePath.WindingFill

            PathSvg {
                path: root.figure
            }
        }
    }

    readonly property string figure: root.build()

    function build(): string {
        const n = root.span;
        const m = root.module;
        if (!n || m <= 0)
            return "";

        const r = m / 2;
        const smoothing = Appearance.rounding.smoothing;
        const grid = root.matrix;
        const edge = root.quiet * m;

        // Off the matrix is light, which is what makes the symbol's own outer
        // corners round without a special case for the border.
        const dark = (row, col) => row >= 0 && row < n && col >= 0 && col < n && grid[row][col];

        let out = "";
        for (let row = 0; row < n; row++) {
            for (let col = 0; col < n; col++) {
                if (!grid[row][col])
                    continue;
                const up = dark(row - 1, col);
                const down = dark(row + 1, col);
                const left = dark(row, col - 1);
                const right = dark(row, col + 1);
                out += Squircle.path(m, m, up || left ? 0 : r, up || right ? 0 : r, down || right ? 0 : r, down || left ? 0 : r, smoothing, edge + col * m, edge + row * m);
            }
        }
        return out;
    }

    StyledText {
        id: label

        // Straight under the square, so the gap above it IS the bottom quiet
        // zone. The sides take the same margin, which is the code's own.
        anchors.top: parent.top
        anchors.topMargin: root.width
        anchors.left: parent.left
        anchors.leftMargin: root.quiet * root.module
        anchors.right: parent.right
        anchors.rightMargin: root.quiet * root.module

        visible: !!root.caption && root.ready
        text: root.caption
        // On the card rather than on the shell, so it takes the card's ink and
        // not a label tier, which is translucent and would let the paper through.
        color: root.ink
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
    }
}
