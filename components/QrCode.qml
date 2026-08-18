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
// looks like: black, square, static, and unaware that it is being drawn on a G2
// shell. So it is asked for `-t ASCII`, which is the bits and nothing else, and
// everything below decides what bits look like.
//
// IT IS CUT INTO DIAGONALS, and that one decision buys three things at once.
// Each band is one path built once, so the wave that brings the code in is sixty
// opacities changing per frame rather than six hundred shapes being rebuilt; the
// same axis carries the colour ramp, so the sweep and the gradient agree by
// construction rather than by being tuned to match; and a band is exactly one
// module wide, so a wave travelling along it reads as the modules arriving one
// at a time, which is what it is.
Item {
    id: root

    // What the code carries. Anything; it is encoded as bytes.
    property string text: ""

    // Two lines on the card, under the code. A phone that has scanned it says
    // nothing back, and not everyone being handed a network is holding a camera:
    // whatever the code says in machine form, the card says in words.
    property string caption: ""
    property string detail: ""

    // WHICH FACE. Ink on paper is the polarity every decoder was written for;
    // the other is the same polarity said in the theme's own green, dark
    // modules on a light plate. Same code, same modules, same direction of
    // contrast, and that last part is the whole reason this can be the default
    // now: the first colour face was the saturated ramp on a near-black plate,
    // which is a code INVERTED, and a decoder that is handed one of those has
    // to be clever on purpose to read it.
    property bool colourful: true

    // Whether pressing the card turns it over. Off by default: a component that
    // silently eats clicks is a surprise, and not every card is a control.
    property bool flippable: false

    // What pressing it does, for the tooltip. A card that turns over has nothing
    // written on it saying so.
    property string tip: ""

    signal flipped

    // THE TWO ENDS OF THE GREEN, which is what the coloured face is made of.
    //
    // `spectrum` is the saturated ramp, quietest to brightest, so its top is
    // the lightest green the theme owns and is the plate. Its bottom is a
    // verdigris that is only about half as bright as that, which is nowhere
    // near the contrast a camera wants, so the modules are that same green
    // taken most of the way down to the ramp's dark end: still unmistakably
    // green, and dark enough that the card thresholds like ink on paper.
    readonly property color leaf: Appearance.colour.spectrum[Appearance.colour.spectrum.length - 1]
    readonly property color pine: Appearance.blend(Appearance.colour.spectrum[0], Appearance.colour.ink, 0.7)

    readonly property color plate: root.colourful ? root.leaf : Appearance.colour.paper
    readonly property color pen: root.colourful ? root.pine : Appearance.colour.ink

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

    // A CEILING ON THE WHOLE CARD, for a place with a fixed amount of room. Zero
    // means "as much as the width allows", which is what a card in open space
    // wants.
    property real maxHeight: 0

    implicitWidth: parent ? parent.width : 0
    implicitHeight: root.side + root.hem

    // THE PLATE'S SIDE, which is the width it was given or as much of it as the
    // ceiling leaves once the writing has been paid for.
    //
    // SOLVED, not iterated. The bottom margin is a FRACTION of the side, because
    // it is the quiet zone and the quiet zone is four of the symbol's own
    // modules, so `side * (1 + quiet/(span + 2*quiet)) + words = maxHeight` has
    // exactly one answer and there is no loop to converge.
    readonly property real gutter: root.span ? root.quiet / (root.span + root.quiet * 2) : 0

    readonly property real side: {
        if (root.maxHeight <= 0 || !root.ready)
            return root.width;
        const room = (root.maxHeight - words.implicitHeight) / (1 + root.gutter);
        return Math.max(0, Math.min(root.width, room));
    }

    // What the writing costs, including the bottom quiet zone it sits below.
    // That zone is the code's own margin said again, so the space around the
    // words matches the space around the code and the card has ONE margin
    // rather than two that nearly agree.
    readonly property real hem: root.ready && words.implicitHeight > 0 ? words.implicitHeight + root.quiet * root.module : 0

    // ONE MODULE, in pixels. The code and both quiet zones divide the plate, so
    // the whole card is sized from the symbol's own module count and nothing
    // here is a chosen number. A denser code just draws smaller.
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
    readonly property var figures: root.carve()

    function carve(): var {
        const n = root.span;
        const m = root.module;
        if (!n || m <= 0)
            return [];

        const r = m / 2;
        const smoothing = Appearance.rounding.smoothing;
        const grid = root.matrix;
        const edge = root.quiet * m;

        // THE HAIRLINE BETWEEN TWO MODULES THAT ARE SUPPOSED TO BE ONE BAR.
        //
        // Neighbours in the grid are neighbours on the SCREEN and strangers in
        // the scene: row + col differs by one across every shared edge, so any
        // two touching modules are always in different bands, drawn by
        // different Shapes and antialiased independently. Two coverages of
        // about a half at the same pixel do not add up to one, so the plate
        // showed through every join as a pale grid laid over the code, which is
        // the one thing a decoder is entitled to not find there.
        //
        // So a joined edge OVERLAPS rather than abutting. A fraction of a
        // module, because the module is the only length this card has; the
        // floor is there because the seam is about a pixel wide whatever the
        // code's density, and a dense code's fraction would fall under it.
        const bleed = Math.max(0.5, m * 0.05);

        // Off the matrix is light, which is what makes the symbol's own outer
        // corners round without a special case for the border.
        const dark = (row, col) => row >= 0 && row < n && col >= 0 && col < n && grid[row][col];

        // One entry per anti-diagonal: row + col is constant along it, and it
        // sweeps from the top-left corner to the bottom-right one.
        const out = new Array(n * 2 - 1).fill("");
        for (let row = 0; row < n; row++) {
            for (let col = 0; col < n; col++) {
                if (!grid[row][col])
                    continue;
                const up = dark(row - 1, col);
                const down = dark(row + 1, col);
                const left = dark(row, col - 1);
                const right = dark(row, col + 1);

                // ONLY THE JOINED SIDES GROW. An exposed edge is the symbol's
                // real edge, and moving that would be drawing a different code.
                const x = edge + col * m - (left ? bleed : 0);
                const y = edge + row * m - (up ? bleed : 0);
                const w = m + (left ? bleed : 0) + (right ? bleed : 0);
                const h = m + (up ? bleed : 0) + (down ? bleed : 0);

                out[row + col] += Squircle.path(w, h, up || left ? 0 : r, up || right ? 0 : r, down || right ? 0 : r, down || left ? 0 : r, smoothing, x, y);
            }
        }
        return out;
    }

    // THE WAVE, and the turn, which are the same shape of number and therefore
    // the same function.
    //
    // A band does not switch on when the front reaches it: it STARTS then, and
    // takes `spread` of the whole sweep to land. That is the difference between
    // a line crossing the code and a wave passing through it. Several bands are
    // always mid-arrival, so the front has a soft edge, and the last one lands
    // exactly as the sweep ends.
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

    // The code arrives once, when there is a code. A new string is a new arrival
    // and starts from nothing again, which is also what makes the card read as
    // having CHANGED rather than having been quietly edited in place.
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

    // Turning the card over travels along the SAME diagonal, so the two motions
    // this card has are one motion at two different times.
    Behavior on turn {
        NumberAnimation {
            duration: Appearance.anim.slow * 2
            easing.type: Easing.InOutSine
        }
    }

    // WHERE A BAND'S COLOUR COMES FROM. Ink at one end of the turn and a green
    // at the other, picked by how far down the diagonal the band sits, so the
    // gradient runs on the code's own geometry rather than in a direction
    // somebody chose.
    //
    // THE RAMP IS INSIDE THE DARK END now. It used to run the full saturated
    // spectrum, which is a beautiful gradient and half of it was brighter than
    // the plate it was drawn on: the modules at one corner of the code were
    // lighter than the background at the other, and no threshold can separate
    // that. So the sweep travels between two dark greens instead, a third of
    // the distance back up towards the verdigris and no further. The gradient
    // is quieter and the whole code stays on one side of the line.
    function hue(i: int): color {
        const n = root.figures.length;
        const at = n > 1 ? i / (n - 1) : 0;
        return Appearance.blend(Appearance.colour.ink, Appearance.blend(root.pine, Appearance.colour.spectrum[0], at / 3), root.phase(i, root.turn));
    }

    // The card itself, which is narrower than the item it is in whenever a
    // ceiling has shrunk it. Centred, so a card that had to give up width gives
    // up the same amount on both sides.
    Item {
        id: face

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        width: root.side
        height: root.side + root.hem

        // THE PLATE, and the one bright object in this menu on either face,
        // deliberately: it is held up to a camera, and a camera in a dim room
        // wants the light coming off the screen rather than out of the ceiling.
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

            // Straight under the square, so the gap above the writing IS the
            // bottom quiet zone. The sides take the same margin, which is the
            // code's own.
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
                // On the card rather than on the shell, so it takes the card's
                // own ink and not a label tier, which is translucent and would
                // let the plate through.
                color: root.pen
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideMiddle

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.anim.slow * 2
                    }
                }
            }

            // THE SECOND LINE IS FOR A PERSON, the first is what the card IS.
            // Quieter by exactly the amount the shell's own second tier is
            // quieter, which is the only reason `shade` exists.
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
