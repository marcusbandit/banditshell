pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// Arithmetic, on a surface with no keyboard.
//
// A KEYPAD RATHER THAN A FIELD, and that is not a stylistic choice. A layer
// surface is handed no key events at all until its window asks the compositor
// for them (ClockMenu's Field and PasswordField both say so), and asking means
// every key in the shell stops reaching the desktop for as long as the panel is
// up. A calculator is a thing you reach for WHILE doing something else, which is
// exactly the case that must not take the keyboard away from what you were
// doing. So every input here is a target, the way every input in SoundMenu and
// ClockMenu is, and the arithmetic never has to be parsed out of a string.
//
// THE RESULT STAYS. This is the one behaviour worth writing down, because it is
// the difference between a calculator and a form with a Submit button: after an
// equals the answer is still the number on the line, so pressing an operator
// continues from it (2, then + 3 =, is 5) and pressing a digit starts over from
// it (2, then 2 + 2 =, is 4). Both are the same rule stated once, in `typed`
// below: the line holds a value nobody has typed into yet, so an operator takes
// it as the left operand and a digit replaces it.
//
// AND IT IS EDITABLE, which most calculators refuse. Backspace chops the last
// character off whatever is on the line, INCLUDING a carried result: a mistyped
// digit costs one press rather than starting the sum again, and a result you
// wanted three digits of is three presses from being one. That is why backspace
// gets the double-width target and Clear gets a single one, which is the reverse
// of the usual hierarchy and right for the reason ClockMenu's Stop and Snooze
// are sized the way they are: the cost of a mis-hit is asymmetric, so the
// recoverable action gets the easy target and the destructive one has to be
// aimed at.
//
// THE COLUMN IS DATA. `keys` below is a list of rows of key descriptions and
// nothing else in this file knows how many of either there are: the column count
// is the widest row's own total, a unit is the width divided by that, and a key
// two units wide is two units plus the gap it swallowed
// (~/.claude/rules/math-over-hardcoding.md). Adding a row of scientific keys
// later is a line of data, not a layout.
//
// FOUR OPERATIONS, and the glyphs are the real ones: Monocraft carries U+00D7,
// U+00F7 and U+2212, so the panel says times, divide and minus rather than
// borrowing an asterisk, a slash and a hyphen from a programming language. The
// same characters are what `compute` switches on, so the label a key draws IS
// the operation it performs and there is no second table to keep in step.
Column {
    id: root

    spacing: Appearance.padding.normal

    // ------------------------------------------------------------------
    // WHAT THE PANEL IS HOLDING.
    //
    // All of it dies with the body, which is torn down every time the menu
    // closes. A calculator that remembered an abandoned half-sum across an open
    // would be answering a question nobody is still asking.

    // THE LINE ITSELF, as text rather than as a number, because what is on it is
    // frequently not a number yet: "5." is a decimal point somebody has pressed
    // and not filled in, and "0" is a leading zero waiting to be replaced. A
    // real stored behind it and formatted on the way out would lose both.
    property string entry: "0"

    // Whether the line holds something SOMEBODY TYPED, as opposed to something
    // the panel put there. This one flag is the whole of the carry rule in the
    // header: false means the next digit replaces the line instead of extending
    // it, and it is false after an equals, after an operator, and at rest.
    property bool typed: false

    // The left operand, held while `op` is pending. A real, not text: it has
    // already been through the line and out the other side, so there is nothing
    // half-typed left in it to preserve.
    property real acc: 0

    // The pending operation, as its own glyph, and "" for none.
    property string op: ""

    // The newest completed calculation, whole: both operands, the operation and
    // the answer. Drawn under the line rather than over it because the answer is
    // what the panel is about and the working is what it is about only until you
    // have read it.
    property string history: ""

    // ------------------------------------------------------------------
    // TOKENS AND UNITS.

    // How much of a float to believe. Binary floating point cannot hold 0.1, so
    // 0.1 + 0.2 is 0.30000000000000004 and a calculator that prints it is a
    // calculator nobody trusts. Rounding to twelve significant figures throws
    // that tail away and keeps every digit anybody typed, since a double carries
    // between fifteen and seventeen and no hand enters twelve.
    readonly property int precision: 12

    // The gap between keys, and the same gap between rows: a keypad is a grid,
    // and a grid whose two axes disagree reads as two grids.
    readonly property real gap: Appearance.padding.small

    // HOW WIDE THE GRID IS, in units, taken from the widest row rather than
    // written down. Every key declares how many units it spans, so this is the
    // count the rest of the arithmetic divides by and the one number that has to
    // change when the keypad does, which is to say none.
    readonly property int columns: Math.max(...root.keys.map(row => row.reduce((n, k) => n + (k.span ?? 1), 0)))

    // One column, less its share of the gaps. Everything horizontal is this
    // times a span.
    readonly property real unit: (root.width - root.gap * (root.columns - 1)) / root.columns

    // A key's height: one line of the label tier in its own box, floored at the
    // minimum target so a key is never smaller than anything else you are asked
    // to hit. Derived rather than set, so the keypad rescales with the type the
    // way every other control in the shell does.
    readonly property real keyHeight: Math.max(Appearance.sizes.minTarget, Math.round(Appearance.font.size.normal * 4 / 3) + Appearance.padding.normal * 2)

    // ------------------------------------------------------------------
    // THE KEYPAD, AS DATA.
    //
    // Read down column four and it is the operations, in the order a keypad has
    // put them since the desk calculator: divide, times, minus, plus, equals.
    // Read the first row and it is the two ways out of a mistake, sized by what
    // they cost (see the header).
    readonly property var keys: [
        [
            {
                tag: "back",
                icon: "backspace",
                span: 2
            },
            {
                tag: "clear",
                label: "C"
            },
            {
                tag: "op",
                label: "÷"
            }
        ],
        [
            {
                tag: "digit",
                label: "7"
            },
            {
                tag: "digit",
                label: "8"
            },
            {
                tag: "digit",
                label: "9"
            },
            {
                tag: "op",
                label: "×"
            }
        ],
        [
            {
                tag: "digit",
                label: "4"
            },
            {
                tag: "digit",
                label: "5"
            },
            {
                tag: "digit",
                label: "6"
            },
            {
                tag: "op",
                label: "−"
            }
        ],
        [
            {
                tag: "digit",
                label: "1"
            },
            {
                tag: "digit",
                label: "2"
            },
            {
                tag: "digit",
                label: "3"
            },
            {
                tag: "op",
                label: "+"
            }
        ],
        [
            {
                tag: "digit",
                label: "0",
                span: 2
            },
            {
                tag: "dot",
                label: "."
            },
            {
                tag: "equals",
                label: "="
            }
        ]
    ]

    // ------------------------------------------------------------------
    // ARITHMETIC.

    // A NUMBER, WRITTEN THE WAY A PERSON WOULD. Trailing zeros go, because
    // toPrecision keeps them and "4.00000000000" is not an answer; the round trip
    // through parseFloat is what drops them without a regular expression that
    // would also eat the zeros in 4000.
    //
    // The two non-numbers get a glyph each rather than the engine's own words:
    // "Infinity" is eight characters wide on a line that holds fourteen, and
    // "NaN" tells you which language the shell is written in rather than what
    // went wrong.
    function format(n: real): string {
        if (isNaN(n))
            return "?";
        if (!isFinite(n))
            return n > 0 ? "∞" : "-∞";
        return parseFloat(n.toPrecision(root.precision)).toString();
    }

    // The line, back as a number. The two glyphs above are read back so a sum
    // continued off an infinity stays honest rather than silently becoming zero;
    // anything else unparseable is a "?" the user is about to type over anyway.
    function value(): real {
        if (root.entry === "∞")
            return Infinity;
        if (root.entry === "-∞")
            return -Infinity;
        const v = parseFloat(root.entry);
        return isNaN(v) ? 0 : v;
    }

    // The whole of what this calculator does. Switched on the glyph the key
    // draws, so there is no operation the keypad can name that this cannot
    // perform (see the header).
    function compute(a: real, o: string, b: real): real {
        switch (o) {
        case "+":
            return a + b;
        case "−":
            return a - b;
        case "×":
            return a * b;
        case "÷":
            return a / b;
        }
        return b;
    }

    // ------------------------------------------------------------------
    // WHAT A KEY DOES.

    // STARTING TO TYPE OVER A LINE NOBODY TYPED retires the working underneath
    // it, and that is what keeps the two lines honest about each other. The line
    // below the answer describes the answer above it (see `working`); the moment
    // the answer stops being one, a sentence ending "= 150" is sitting under a
    // line reading 15. It is only ever the ANSWER's own sum that goes: a sum in
    // progress is not history and is drawn from the live state instead.
    function beginEntry(): void {
        if (root.op === "")
            root.history = "";
    }

    function digit(d: string): void {
        if (!root.typed) {
            root.beginEntry();
            root.entry = d;
            root.typed = true;
            return;
        }
        // A leading zero is a placeholder rather than a digit: it is what an
        // empty line looks like, so the first real digit takes its place instead
        // of standing next to it. "0.5" keeps its zero, because by then the line
        // is no longer just a placeholder.
        root.entry = root.entry === "0" ? d : root.entry + d;
    }

    function dot(): void {
        if (!root.typed) {
            root.beginEntry();
            // Never a bare ".", which parses to nothing. The zero is what makes
            // the line a number the whole time it is being typed.
            root.entry = "0.";
            root.typed = true;
            return;
        }
        if (!root.entry.includes("."))
            root.entry += ".";
    }

    // ONE CHARACTER OFF THE LINE, whatever put it there. Taking a result apart
    // is the point (see the header), so a line nobody typed into is simply
    // claimed as typed and then chopped like any other.
    //
    // Chopped to nothing it becomes the placeholder again rather than an empty
    // line: an empty line is not a number, and every function above would then
    // have to decide what to do about it.
    function back(): void {
        if (!root.typed)
            root.beginEntry();
        root.typed = true;
        root.entry = root.entry.slice(0, -1);
        if (root.entry === "" || root.entry === "-") {
            root.entry = "0";
            root.typed = false;
        }
    }

    // An operator FOLDS whatever is already pending before it starts the next
    // one, so 2 + 3 × 4 shows 5 the moment × is pressed and then multiplies
    // that. Left to right, with no precedence: this panel has no parentheses to
    // show precedence with, and an answer that quietly disagrees with the order
    // you pressed the keys in is worse than one that does not.
    //
    // Only when something was actually typed after the last operator, which is
    // what makes pressing + and then × mean "I meant times": there is no right
    // operand to fold, so the pending operation is replaced rather than
    // performed against a repeat of the left one.
    function operate(o: string): void {
        if (root.op !== "" && root.typed)
            root.settle();

        root.acc = root.value();
        root.op = o;
        // The line now holds the LEFT operand, which nobody has typed into since
        // it took that job: the next digit starts the right operand rather than
        // extending the left.
        root.typed = false;
    }

    // The pending operation, performed, with the working written down. Shared by
    // equals and by the fold above, because "compute it and say what you
    // computed" is one thing that happened twice, and two copies would be two
    // chances for the history line to disagree with the answer over it.
    function settle(): void {
        const a = root.acc;
        const o = root.op;
        const b = root.value();
        const r = root.compute(a, o, b);

        root.history = `${root.format(a)} ${o} ${root.format(b)} = ${root.format(r)}`;
        root.entry = root.format(r);
        root.acc = r;
        root.op = "";
        root.typed = false;
    }

    // Equals with nothing pending does NOTHING, deliberately. The other
    // convention is to repeat the last operation, which turns a stray press into
    // a silent change to the number you were reading; here the line is already
    // the answer, so the honest response to being asked for it again is to go on
    // showing it.
    function equals(): void {
        if (root.op !== "")
            root.settle();
    }

    function clear(): void {
        root.entry = "0";
        root.typed = false;
        root.acc = 0;
        root.op = "";
        root.history = "";
    }

    function press(spec: var): void {
        switch (spec.tag) {
        case "digit":
            root.digit(spec.label);
            break;
        case "dot":
            root.dot();
            break;
        case "op":
            root.operate(spec.label);
            break;
        case "equals":
            root.equals();
            break;
        case "back":
            root.back();
            break;
        case "clear":
            root.clear();
            break;
        }
    }

    // ------------------------------------------------------------------
    // THE LINE UNDER THE ANSWER.
    //
    // WHILE SOMETHING IS PENDING it is the sum in progress, so the operand that
    // has scrolled off the top of your attention is still on screen and the
    // operator you pressed is visible as text rather than only as a lit key.
    // OTHERWISE it is the last completed calculation, which is the thing the
    // request asked for: the answer, and immediately under it the sum that
    // produced it.
    //
    // The right operand joins the line only once it has been typed, because
    // until then the line's own big numerals ARE the left operand and repeating
    // them under itself would read as an operation on a number by itself.
    readonly property string working: {
        if (root.op === "")
            return root.history;
        const left = `${root.format(root.acc)} ${root.op}`;
        return root.typed ? `${left} ${root.entry}` : left;
    }

    // ------------------------------------------------------------------
    // A KEY.
    //
    // Built here rather than from components/Pill.qml, which is the shell's
    // pressable-label primitive and the obvious reuse. Pill is a pill: its radius
    // is half its height by construction, so a 60px key would be a lozenge, and
    // twenty lozenges in a grid read as twenty separate objects rather than as
    // one keypad. It also draws its label in the primary tier full stop, and
    // three of the tiers here are not primary. Same reason ClockMenu declares its
    // own StatePill: the component is right about pressing and wrong about the
    // shape, and this file does not own the component.
    component Key: Item {
        id: key

        required property var spec

        // WHICH OPERATION IS WAITING. The one piece of state on this panel that
        // is genuinely worth a colour: it is not decoration and not a label, it
        // is the answer to "what did I press", and it is the only thing between
        // an operator and its equals that says the calculator is mid-sum.
        // Everything else here is a fill (config/Appearance.qml's note on what
        // the accent is rationed for).
        readonly property bool lit: key.spec.tag === "op" && root.op === key.spec.label

        // Two units wide is two units plus the gap that used to be between them:
        // a spanning key swallows the gaps it crosses, or the grid would drift
        // wider by one gap per span.
        readonly property int span: key.spec.span ?? 1

        // The rest fill says what kind of key this is without a border, a second
        // colour or a label that explains itself: digits sit at the surface's own
        // hover weight, operators a step above them, and equals a step above
        // that, so the eye finds the operations before it finds the digits and
        // finds equals first of all.
        readonly property color rest: {
            switch (key.spec.tag) {
            case "op":
                return Appearance.colour.fillStrong;
            case "equals":
                return Appearance.colour.fillStronger;
            }
            return Appearance.colour.fill;
        }

        // One step further up the same ladder. Equals has no step left above it,
        // so it borrows the smallest amount of the shell's own ink instead of a
        // fourth fill tier that would exist for one key.
        readonly property color raised: {
            switch (key.spec.tag) {
            case "op":
                return Appearance.colour.fillStronger;
            case "equals":
                return Appearance.blend(Appearance.colour.fillStronger, Appearance.colour.text, 0.15);
            }
            return Appearance.colour.fillStrong;
        }

        // The two ways out of a mistake are drawn quieter than the arithmetic,
        // because they are not part of the sum: they are how you take one back.
        readonly property color ink: key.spec.tag === "back" || key.spec.tag === "clear" ? Appearance.colour.textDim : Appearance.colour.text

        implicitWidth: root.unit * key.span + root.gap * (key.span - 1)
        implicitHeight: root.keyHeight
        width: implicitWidth
        height: implicitHeight

        // Pressing it MOVES it, exactly as Pill and StatePill do: a key is the
        // one place somebody is certain they did something, so it is the
        // cheapest place in the shell to be wrong about it (DESIGN.md 2.3).
        scale: press.pressed ? 0.96 : 1

        Behavior on scale {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }

        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            // containsMouse covers both inputs: a hover for a cursor, and the
            // synthesised hover a touch press carries, so the key answers a
            // finger as well (DESIGN.md 2.3).
            color: key.lit ? Appearance.colour.accentFill : press.containsMouse || press.pressed ? key.raised : key.rest

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        // A GLYPH OR A LABEL, never both, and the glyph is only for the one key
        // whose name is a picture. Monocraft has no U+232B, so backspace comes
        // from the icon face like every other mark in the shell; the arithmetic
        // characters it does have, so those stay in the text face and sit on the
        // same pixel grid as the answer they operate on.
        Icon {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: inkOffsetX
            anchors.verticalCenterOffset: inkOffsetY

            visible: !!key.spec.icon
            name: key.spec.icon ?? ""
            // Sized to the LABEL tier rather than to Appearance's icon size,
            // which is the body tier's own icon and lands a mark noticeably
            // smaller than the digits beside it. A key drawn as a picture and a
            // key drawn as a character have to read as the same size key.
            size: Appearance.font.size.normal
            color: key.ink
        }

        StyledText {
            anchors.centerIn: parent
            anchors.horizontalCenterOffset: inkOffsetX
            anchors.verticalCenterOffset: inkOffsetY

            visible: !key.spec.icon
            text: key.spec.label ?? ""
            font.pixelSize: Appearance.font.size.normal
            color: key.lit ? Appearance.colour.accent : key.ink

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.press(key.spec)
        }
    }

    // ------------------------------------------------------------------
    // THE ANSWER, and under it the working.

    Item {
        id: readout

        width: parent.width
        height: answer.height + Appearance.padding.small + working.height

        // MEASURED AT THE LARGE TIER before it is drawn at one, because a number
        // is the one string in the shell that must not elide: the digits at the
        // end are the ones nobody can infer. Monocraft's advance is 2/3 of the
        // size, so fourteen characters fit here and the fifteenth would hang off
        // the panel.
        //
        // The answer to that is the tier below, which is a token rather than a
        // size invented here (~/.claude/rules/type-scale.md): the line stays
        // whole and simply gets quieter, and the row keeps the large tier's
        // height either way so the panel does not change size around a digit.
        TextMetrics {
            id: probe

            font.family: Appearance.font.family
            font.pixelSize: Appearance.font.size.large
            text: root.entry
        }

        StyledText {
            id: answer

            width: parent.width
            height: Math.round(Appearance.font.size.large * 4 / 3)

            text: root.entry
            font.pixelSize: probe.width <= readout.width ? Appearance.font.size.large : Appearance.font.size.normal
            // Right, because that is the end a number is read from and the end
            // the next digit arrives at: a left-aligned line would walk the digit
            // you just pressed further from the keypad every time you pressed
            // one.
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
        }

        StyledText {
            id: working

            anchors.top: answer.bottom
            anchors.topMargin: Appearance.padding.small

            width: parent.width
            height: Math.round(Appearance.font.size.small * 4 / 3)

            text: root.working
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            horizontalAlignment: Text.AlignRight
            verticalAlignment: Text.AlignVCenter
            // From the LEFT, uniquely in this shell. Everything else elides its
            // tail because a name is recognised from its start; a sum is read
            // towards its answer, so what has to survive here is the right-hand
            // end.
            elide: Text.ElideLeft
        }
    }

    Separator {
        width: parent.width
    }

    // ------------------------------------------------------------------
    // THE KEYS. Nothing below knows what is in them; see `keys` above.

    Column {
        id: pad

        width: parent.width
        spacing: root.gap

        Repeater {
            model: root.keys

            delegate: Row {
                id: line

                required property var modelData

                width: pad.width
                spacing: root.gap

                Repeater {
                    model: line.modelData

                    delegate: Key {
                        required property var modelData

                        spec: modelData
                    }
                }
            }
        }
    }
}
