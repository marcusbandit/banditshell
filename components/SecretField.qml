import QtQuick
import QtQuick.Shapes
import qs.config
import "lobes.js" as Lobes

// A FIELD YOU TYPE A SECRET INTO. The shell's one answer to that question.
//
// There are three places this shell asks for a password - the lock screen, the
// keyring's prompt, and any menu row that wants one - and every one of them had
// written its own field. This is the field; a caller places one and wires up two
// signals.
//
//     SecretField {
//         placeholder: "password"
//         busy: Lock.busy            // goes quiet while something is checking
//         alarm: Lock.failed         // the last answer was refused
//         onAccepted: secret => Something.submit(secret)
//         onCancelled: Something.refuse()
//     }
//
// THE SECRET LEAVES ONLY THROUGH `accepted`. There is no `text` property to read
// and none to write, which is the point rather than an omission: a caller that
// could read the field would be a caller that could hold the value, and the
// whole discipline this shell keeps around passwords (services/Lock.qml's note,
// services/Keyring.qml's) is that the window in which one exists is as short as
// the code can make it. What a caller CAN see is `count`, which is how many
// characters there are, because a submit button has to know whether there is
// anything to submit. Nothing here is ever logged; Quickshell writes its log to
// disk, so a console.log in this file would be a real leak.
//
// WHAT IT DRAWS, and why it is not a row of asterisks. A character echoed as `*`
// is a font's answer to this question, and it is the one part of a credential
// prompt somebody looks at the entire time they are typing. So the marks are
// drawn: one per character, each a different shape from a family of this shell's
// own (components/lobes.js), each growing into place on the frame it arrives.
// The acknowledgement is the only feedback a field like this can give.
//
// ONE MARK IN, ONE MARK OUT, and nothing else moves. The obvious construction is
// a Repeater over the character count with the delegate animating itself on
// creation, and it is wrong in a way that is invisible until you type: changing
// a Repeater's count rebuilds its delegates, so every mark on screen replayed
// its arrival on every keystroke and the field pulsed. The marks here are
// created ONCE, as many as fit, and each is told only whether it is currently
// standing. Typing flips exactly one of them, so exactly one moves; a backspace
// flips one back and it shrinks away rather than vanishing.
Item {
    id: root

    // ---- WHAT A CALLER SETS --------------------------------------------

    property string placeholder: ""

    // Something is checking the last answer. The field stops taking keys rather
    // than queueing them: a second Enter while the first is still being checked
    // is a second full attempt, and things that count attempts count it.
    property bool busy: false

    // The last answer was refused. Colours the marks and the indicator, and is
    // the caller's fact rather than this field's: only the thing that asked the
    // question knows what the answer did.
    property bool alarm: false

    // WHETHER TO TELL components/Prompts.qml. A field inside a menu has to, or
    // the surface it is drawn on never asks the compositor for the keyboard and
    // the caret blinks in a field that receives nothing. A field on a panel that
    // is already named in ShellWindow's keyboardFocus term must NOT, or it puts
    // a claim on the shell that Menus.needsKeyboard then reads. Off by default,
    // because the panel case is the one that cannot recover from getting it
    // wrong: a spurious claim is a menu quietly stealing the keyboard, while a
    // missing one is a field the caller notices immediately.
    property bool claims: false

    // How big a mark is: AS TALL AS A LETTER, and that relationship is the whole
    // definition rather than a number that happens to look right today. The
    // marks stand in for characters, so they are the size of one; change the
    // type scale and they follow it.
    //
    // It is NOT the lock screen's `lockDot`, which is half an icon and comes out
    // at ten pixels. Ten pixels is enough for a dot and not enough for a SHAPE:
    // the whole point of components/lobes.js is that a mark has a silhouette you
    // can tell from its neighbour's, and at ten pixels the six of them collapse
    // into the same grey smudge, which is the row of identical circles this
    // component exists to not be.
    property real markSize: Appearance.font.size.small

    // ---- WHAT A CALLER READS -------------------------------------------

    // How many characters have been typed, and NOT what they are.
    readonly property int count: field.length

    readonly property bool empty: root.count === 0

    signal accepted(string secret)
    signal cancelled

    // ---- WHAT A CALLER CALLS -------------------------------------------

    // Empty it, and take the keyboard back. Called when a fresh question
    // arrives: a caller that leaves the last answer in the field is a caller
    // offering somebody a rejected password to press Enter on again.
    function clear(): void {
        field.text = "";
        if (root.visible)
            field.forceActiveFocus();
    }

    // Hand over what is there, and wipe it on the same line. The only route out.
    function submit(): void {
        if (root.busy || !field.length)
            return;
        const secret = field.text;
        field.text = "";
        root.accepted(secret);
    }

    implicitHeight: Math.round(em.height * 3)
    implicitWidth: Appearance.sizes.lockDot * 12

    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "M"
    }

    // HOW MANY MARKS THERE CAN BE, from the room rather than from a number
    // somebody picked. One more than fits would be one drawn where it cannot be
    // seen; one fewer is a mark missing from a password that had room for it.
    // Anything typed past this is clipped, which is the honest thing for it to
    // do: rescaling the marks to fit would turn the LENGTH of what was typed
    // into something readable from across the room.
    readonly property int capacity: Math.max(1, Math.floor((marks.width + spacing) / (root.markSize + spacing)))

    // The gap between marks, FROM the mark rather than from the padding scale.
    // It is the one measurement here that is about the marks' relationship to
    // each other rather than about the field's relationship to its contents, so
    // it has to move when they do: a fixed six pixels between ten-pixel marks is
    // an airy row, and between twenty-pixel marks it is a solid bar.
    readonly property real spacing: Math.round(root.markSize / 2.5)

    Follow {
        id: focusIn

        speed: Appearance.anim.revealSpeed
        target: field.activeFocus ? 1 : 0
        epsilon: 0.005
    }

    // THE TROUGH, and the whole of the focus state with it.
    //
    // It was Material's filled variant for a while: rounded at the top, SQUARE
    // at the bottom, sitting on a flat rule that thickened and took colour on
    // focus. That is Material's shape and it is not this shell's. Nothing in
    // banditshell is a flat rule and nothing has a corner that is a right angle
    // because a component underneath it needed somewhere to draw a line; every
    // shape here is one closed G2 contour, and a field is a shape like any
    // other. See ~/.claude/rules/g2-corners.md.
    //
    // So the indicator went into the trough's OWN outline. It is the seam at
    // rest, the same hairline the chassis draws along its inner edge; it takes
    // the accent and thickens as the field is focused, and the alarm colour
    // while the last answer stands refused. One shape saying one thing, and the
    // ring reads as the field lighting up rather than as a rule underneath it.
    G2Rect {
        anchors.fill: parent

        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        stroke: root.alarm ? Appearance.colour.alarm : field.activeFocus ? Appearance.colour.accent : Appearance.colour.seam
        // The seam's width at rest, and twice it once there is something to say.
        strokeWidth: Appearance.sizes.seam * (1 + focusIn.value)
        opacity: root.busy ? 0.5 : 1
    }

    // WHERE THE KEYS GO, and it paints nothing at all.
    //
    // NoEcho rather than Password, so there is no glyph to hide and no
    // passwordCharacter to choose; `text` still holds the real thing, so this
    // changes only what is drawn. The cursor goes with it, through a delegate
    // that draws nothing rather than through `cursorVisible`, which Qt sets back
    // to true whenever the item takes focus - measured, as a hairline sitting at
    // the left of the field that no amount of clearing would remove.
    TextInput {
        id: field

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large

        enabled: !root.busy
        echoMode: TextInput.NoEcho
        cursorDelegate: Item {}
        activeFocusOnTab: true

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        renderType: Text.NativeRendering
        color: "transparent"

        onAccepted: root.submit()
        Keys.onEscapePressed: root.cancelled()

        // ASKING FOR THE KEYBOARD AND HAVING IT ARE A ROUND TRIP APART. A layer
        // surface is handed no key events until its window asks the compositor,
        // and the compositor answers a frame or more later. Focus taken before
        // that lands is focus in a surface with no keys to give, so it is taken
        // again the moment the surface actually becomes active. A field that
        // silently swallows the first few characters of a password is the worst
        // thing this component could do.
        readonly property bool surfaceActive: field.Window.active
        onSurfaceActiveChanged: if (field.surfaceActive && root.visible)
            field.forceActiveFocus()
    }

    // The claim, when the caller wants one. Idempotent both ways and given back
    // on destruction, because a menu closing destroys its rows outright without
    // them ever passing through invisible. See components/Prompts.qml.
    function stake(): void {
        if (root.claims && root.visible) {
            Prompts.request(root);
            field.forceActiveFocus();
        } else {
            Prompts.release(root);
        }
    }

    // A FIELD THAT IS ON SCREEN HOLDS THE CARET. A caller should not have to
    // remember to focus this, and the panels that show one all show it in answer
    // to something: there is nothing else on a keyring card or a lock screen
    // that a keystroke could sensibly mean.
    //
    // `visible` in QML is the EFFECTIVE one - false while any ancestor is - so
    // this fires when the card carrying the field actually arrives, which is a
    // frame or more after the field itself was built. That is the case a
    // Component.onCompleted focus misses entirely: the field is complete while
    // the panel around it is still at zero opacity, and focus taken there goes
    // to an item nobody can see and is not held.
    function land(): void {
        root.stake();
        if (root.visible)
            field.forceActiveFocus();
    }

    // Both: onVisibleChanged does not fire for an item CREATED already visible,
    // which is how a field in a rebuilt row appears.
    onVisibleChanged: root.land()
    onClaimsChanged: root.land()
    Component.onCompleted: root.land()
    Component.onDestruction: Prompts.release(root)

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter

        text: root.placeholder
        color: Appearance.colour.textGhost
        // Faded rather than switched, so a field that empties does not blink its
        // label back on. Nothing else is smoothing this, so a Behavior is right
        // here and wrong almost everywhere else in this shell.
        opacity: root.empty ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        id: marks

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        clip: true

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.spacing

            Repeater {
                // THE ROOM, not the character count. This model never changes
                // while somebody types, which is the whole fix: the delegates
                // are built once and typing only moves one of them.
                model: root.capacity

                delegate: Shape {
                    id: mark

                    required property int index

                    readonly property bool standing: mark.index < root.count

                    width: root.markSize
                    height: root.markSize
                    // Qt 6.6+ curve renderer: proper antialiasing without a
                    // multisample layer, and the same one G2Rect asks for.
                    preferredRendererType: Shape.CurveRenderer

                    // Out of the layout entirely until it is wanted, so the row
                    // is exactly as wide as what has been typed. A Row leaves
                    // invisible children out, and the marks fill from the left,
                    // so what is visible is always a prefix and nothing ever
                    // has to shuffle along.
                    visible: mark.opacity > 0.004

                    // The arrival, and the departure. Scale rather than width,
                    // so a mark grows in PLACE instead of shoving the row: the
                    // new one is always last, and a backspace should not make
                    // the survivors slide.
                    opacity: mark.standing ? 1 : 0
                    scale: mark.standing ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Appearance.anim.normal
                            // Overshoots a little and settles. The one place in
                            // this shell where a spring is right: it is a
                            // discrete arrival with a known start and end, not
                            // something tracking a moving target, and it is the
                            // machine ANSWERING a keystroke rather than
                            // reporting a state.
                            easing.type: Easing.OutBack
                            easing.overshoot: 2.2
                        }
                    }

                    ShapePath {
                        // COLOURED, and coloured from the THEME rather than from
                        // a palette invented here: the three saturated stops the
                        // rest of the shell draws its gauges and meters with,
                        // taken in turn. A row of marks in one flat grey is the
                        // same row of identical dots the shapes exist to get away
                        // from - the eye reads a texture rather than a count -
                        // and cycling the colour on a different period from the
                        // shape means two neighbours are almost never the same
                        // mark twice over.
                        //
                        // THE COLOUR COMES FROM THE POSITION, exactly as the
                        // shape does, and for the same reason. lobes.js carries
                        // the argument: anything about a mark that depended on
                        // the CHARACTER would be the password, written on the
                        // screen in a code anyone could read off a photograph.
                        //
                        // A refusal overrides the lot. That is the one state
                        // where the row has something to say that matters more
                        // than being pretty.
                        fillColor: root.alarm ? Appearance.colour.alarm : Appearance.colour.spectrum[mark.index % Appearance.colour.spectrum.length]
                        strokeWidth: 0
                        strokeColor: "transparent"

                        PathSvg {
                            // THE INDEX AND NOTHING ELSE decides the shape. See
                            // the note at the top of lobes.js: a shape that
                            // depended on the character would be the password,
                            // written on the screen in a code anyone could read
                            // off a photograph.
                            path: Lobes.path(mark.index, root.markSize)
                        }
                    }
                }
            }
        }
    }
}
