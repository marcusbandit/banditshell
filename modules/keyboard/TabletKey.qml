pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

// ONE KEY ON THE TABLET BOARD.
//
// WHY THIS IS NOT modules/cheatsheet/KeyCap.qml, which draws a key already and
// which this deliberately echoes. The two look alike and answer opposite
// questions. A cheatsheet cap is a READING of the keyboard: it is told what is
// bound where, it never does anything, and a click on it is incidental. This one
// is the keyboard. The difference lands in three places that are not styling:
//
//   it fires on PRESS, not on click. A key that waited for the release would put
//   every character on screen a beat after the finger, which is the single
//   thing that makes an on-screen keyboard feel broken.
//   it REPEATS while held, because that is how a line gets deleted.
//   it is a TapHandler and not a MouseArea, which is the multitouch point below.
//
// So they share the primitive that actually must be shared, G2Rect, and the fill
// ladder, and nothing else. Two files, one rounded-rect primitive, which is what
// ~/.claude/rules/g2-corners.md asks for; forcing one file to be both would have
// meant a cap whose input semantics depended on who instantiated it.
//
// A TapHandler, AND THE REASON IS TWO THUMBS. Qt synthesises mouse events from
// the PRIMARY touch point only, so a board built out of MouseAreas can be
// pressed by exactly one finger at a time: the second thumb's key does not fire,
// and the faster you type the more it drops. Input handlers each take their own
// point, so N keys can be down at once. This is the whole reason a folded
// machine can be typed on rather than pecked at.
//
// NON-SQUARE ON PURPOSE. `pitch` is the horizontal unit and `rowPitch` the
// vertical one, and on a 16:10 panel a board wide enough to reach is not five
// rows tall. The cheatsheet's cap is square because it is a picture of a
// keyboard; this is a target, and the target's height is the panel's business.
Item {
    id: root

    // Width in units of the board's pitch. A key never knows a pixel size of its
    // own, so the whole board rescales from the panel's width.
    property real units: 1
    property real pitch: 0
    property real rowPitch: 0
    property real seam: 0

    // What it says. An `icon` wins if there is one: the Material Symbols name,
    // not a raw glyph, because these are all standard marks the icon face has.
    property string label: ""
    property string icon: ""

    // WHICH OF THE THREE WEIGHTS: "letter", "function" or "accent". Decided in
    // OnScreenKeyboard.toneOf, which derives it from what the key IS. See the
    // note there for what each one means and why the alphabet is the heavy one.
    property string tone: "letter"

    // A MODIFIER THAT IS HELD. The accent, as a fill rather than as a label,
    // which is Appearance's own test for state worth a hue: with no physical
    // keyboard in reach, "is shift on" is the one thing about this board you
    // must be able to answer without reading it.
    property bool latched: false

    // Whether holding it goes on sending. Backspace, delete and the arrows; not
    // the letters, because a finger resting on a key while you think should not
    // fill the line with it.
    property bool repeats: false

    signal fired

    readonly property bool down: touch.pressed

    // ROUNDER THAN THE REST OF THE SHELL'S SMALL PARTS, deliberately. A cap here
    // is four or five times the area of a cheatsheet's, and the same radius on a
    // much bigger rectangle reads as a square: the corner has to grow with the
    // shape for the family resemblance to survive. Still a token, and still the
    // one G2 primitive underneath (~/.claude/rules/g2-corners.md).
    readonly property real radius: Appearance.rounding.normal

    // THE LADDER, and it is a different ladder from the cheatsheet's on purpose.
    // There, most keys are dead and `plain` means "nothing is bound here". Here
    // every key does something, so the faint tier would be a lie told about the
    // whole board. The steps are the three tones at rest, then under a finger,
    // then held.
    //
    // A PRESS ALWAYS BRIGHTENS, which is why the pressed case is one step up
    // from wherever the tone started rather than one shared colour: a function
    // key jumping to the letters' resting weight would read as the key having
    // changed category rather than as having been hit.
    readonly property color resting: root.tone === "accent" ? Appearance.colour.accentFill : root.tone === "letter" ? Appearance.colour.fillStrong : Appearance.colour.fill

    readonly property color fill: root.latched ? Appearance.colour.accentFill : root.down ? (root.tone === "accent" ? Appearance.colour.accent : Appearance.colour.fillStronger) : root.resting

    readonly property color ink: Appearance.colour.text

    // The letters get the larger of the two type tiers and everything else the
    // smaller: on a board this size the alphabet should read first, and the
    // hierarchy is carried by weight and fill rather than by a third size
    // (~/.claude/rules/type-scale.md).
    readonly property int typeSize: root.tone === "letter" ? Appearance.font.size.normal : Appearance.font.size.small

    width: root.units * root.pitch - root.seam
    height: root.rowPitch - root.seam

    G2Rect {
        id: cap

        anchors.fill: parent

        topLeftRadius: root.radius
        topRightRadius: root.radius
        bottomLeftRadius: root.radius
        bottomRightRadius: root.radius

        color: root.fill

        // THE PRESS IS NOT ANIMATED, the release is. A fade on the way down
        // would put the confirmation after the character, which is the wrong way
        // round: the point of the flash is that it beats the glyph to the
        // screen. Coming back up it is a fade, so a fast run of keys leaves a
        // trail that shows what was hit rather than flickering.
        Behavior on color {
            enabled: !root.down
            ColorAnimation {
                duration: Appearance.anim.fast
            }
        }

        StyledText {
            anchors.fill: parent
            anchors.leftMargin: Appearance.padding.small
            anchors.rightMargin: Appearance.padding.small
            visible: !root.icon

            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight

            text: root.label
            color: root.ink
            font.pixelSize: root.typeSize
        }

        Icon {
            anchors.centerIn: parent
            visible: !!root.icon

            name: root.icon
            // Icons sit on function keys and on Return, never on a letter, so
            // they are sized off the icon token rather than off the tone.
            size: Appearance.font.iconSize
            color: root.ink
        }
    }

    TapHandler {
        id: touch

        // WithinBounds rather than the default drag threshold: a thumb landing
        // on a key rolls a few pixels as it flattens, and a handler that let go
        // of the grab on that movement would drop every firmly-pressed key. The
        // grab is only lost by leaving the cap, which is also how a mis-hit is
        // corrected: slide off before letting go and nothing was sent.
        gesturePolicy: TapHandler.WithinBounds

        // ON THE PRESS EDGE. `onTapped` fires at the release and would cost the
        // board a full press-to-release of latency per character.
        onPressedChanged: {
            if (touch.pressed) {
                root.fired();
                if (root.repeats)
                    delay.restart();
            } else {
                delay.stop();
                again.stop();
            }
        }
    }

    // TWO TIMERS AND NOT ONE, because a held key has two different rates: a long
    // wait so that an ordinary tap never repeats at all, then a fast steady one.
    // A single timer would have to pick between deleting a character you meant
    // to keep and taking a second to get going.
    Timer {
        id: delay

        interval: Config.values.tablet.repeatDelay
        onTriggered: again.start()
    }

    Timer {
        id: again

        interval: Config.values.tablet.repeatInterval
        repeat: true
        onTriggered: root.fired()
    }
}
