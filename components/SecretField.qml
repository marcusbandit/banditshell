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
// creation, and it is wrong in a way that is invisible until you type. Measured,
// with a log in the delegate: a Repeater on an integer model DESTROYS AND
// REBUILDS EVERY DELEGATE when the number changes - typing the fourth character
// printed CREATE 0, 1, 2, 3, not CREATE 3 - so every mark on screen replayed its
// arrival on every keystroke and the field pulsed.
//
// So the marks are not a Repeater. They are made one at a time, at the moment a
// character first needs one, and then kept: a mark is told only whether it is
// currently STANDING, and typing flips exactly one of them. That is also the
// only construction with an honest cost. A fixed pool big enough to scroll
// through would be forty-odd shapes built into every field that exists, and
// modules/menu/content/NetworkMenu.qml builds one per wifi network in range; a
// field nobody has typed into now costs nothing at all.
//
// AND IT SCROLLS, which is the other thing the pool had to allow. A long secret
// runs past the end of the field, so the strip pans to keep the caret in view,
// the way any text field does. It used to clip, on the argument that a
// password's LENGTH should not be readable from across the room - that argument
// is still right about RESCALING the marks to fit, which is what it was actually
// against, and wrong about hiding the end of what somebody is typing from the
// person typing it.
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

    // The gap between marks, FROM the mark rather than from the padding scale.
    // It is the one measurement here that is about the marks' relationship to
    // each other rather than about the field's relationship to its contents, so
    // it has to move when they do: a fixed six pixels between ten-pixel marks is
    // an airy row, and between twenty-pixel marks it is a solid bar.
    readonly property real spacing: Math.round(root.markSize / 2.5)

    // One mark's worth of the strip. Every position below is this times an
    // index, so nothing is laid out by a positioner and nothing shuffles when a
    // mark in the middle of the strip changes.
    readonly property real pitch: root.markSize + root.spacing

    // THE FUSE. Not a limit on how long a secret may be - `text` takes whatever
    // is typed or pasted and every character of it is submitted - but a limit on
    // how many SHAPES this will build, so that a paste of a megabyte cannot ask
    // for a million of them. Past it the strip stops growing and the count goes
    // on climbing, which is a field that has stopped drawing the tail rather than
    // a field that has stopped listening.
    property int maxMarks: 64

    readonly property int shown: Math.min(root.count, root.maxMarks)

    // THE ROOM BEFORE THE FIRST MARK, which exists because the caret has to
    // stand somewhere when it is at the start. A caret sits in the gap BEFORE
    // the character it is in front of, and in front of the first character there
    // is no gap: drawn at the strip's own zero it lands at a negative x, which
    // inside a clipped strip means it is simply not there. Home on a long secret
    // panned all the way back and showed no caret at all.
    readonly property real lead: root.spacing

    // The strip's full width, with one gap's worth of air after the last mark so
    // that a secret exactly filling the field does not end flush against the
    // curve.
    readonly property real content: root.lead + root.shown * root.pitch

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

        // ARROWING IS A REASON TO PAN, and the only one the character count
        // cannot see. Home on a secret longer than the field has to bring the
        // start back, and a backspace from the middle moves the caret without
        // changing where the strip needs to be by any amount the count knows.
        onCursorPositionChanged: root.reveal()

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

    // ---- the strip ------------------------------------------------------

    // WHERE THE STRIP HAS BEEN PANNED TO, in pixels from its start, and the
    // rule that decides it: the caret stays in view and nothing else moves.
    //
    // Written as a function rather than as a binding because it is STATEFUL on
    // purpose. "Keep the caret in view" is not a formula from the caret to an
    // offset - it is a correction applied only when the caret would otherwise
    // leave - and a binding would have to pick some canonical position for the
    // caret instead, which means the whole strip lurches every time you arrow
    // one character to the left.
    property real offset: 0

    // Where the caret for a given cursor position stands within the strip: in
    // the gap before that mark, which is half a gap back from where the mark
    // itself begins.
    function caretAt(position: int): real {
        return root.lead + Math.min(position, root.maxMarks) * root.pitch - root.spacing / 2;
    }

    function reveal(): void {
        const view = marks.width;
        if (view <= 0 || root.content <= view) {
            root.offset = 0;
            return;
        }

        // Where the caret stands, in the strip's own coordinates. Clamped to the
        // fuse, because past it there are no marks to scroll to.
        const caret = root.caretAt(field.cursorPosition);

        // Pushed right enough that the caret is not off the end, then pulled
        // back enough that it is not off the start, then held inside the strip.
        // The pull-back leaves the caret a lead in from the left rather than
        // exactly on it, which is the same room it needs at position zero and is
        // why that term is `caret - lead` and not `caret`.
        let want = Math.max(root.offset, caret + root.pitch - view);
        want = Math.min(want, caret - root.lead);
        root.offset = Math.max(0, Math.min(want, root.content - view));
    }

    onCountChanged: root.reveal()
    onWidthChanged: root.reveal()

    // The strip's own smoothing. Exponential, like everything that moves in this
    // shell, so a caret walked off the edge drags the strip after it rather than
    // teleporting it. See ~/.claude/rules/animation-smoothing.md.
    Follow {
        id: pan

        speed: Appearance.anim.scrollSpeed
        target: root.offset
    }

    // ONE MARK, made when a character first needs one and kept for good.
    //
    // Its position is its INDEX times the pitch and never a positioner's idea of
    // where it goes: a Row leaves invisible children out, so a mark shrinking
    // away in the middle of a strip would drag every mark after it sideways, and
    // the one thing this whole file is about is that nothing moves except the
    // mark that changed.
    Component {
        id: markShape

        Shape {
            id: mark

            property int index: 0

            readonly property bool standing: mark.index < root.count

            // WHETHER IT HAS BEEN ALIVE FOR A FRAME, and the reason the mark
            // needs to know. Qt does not run a Behavior while its object is
            // still being created, so a mark made at the moment its character
            // was typed evaluates `standing` as true straight away, takes full
            // opacity as its INITIAL value, and simply appears - which is the
            // one thing this component exists to avoid. Flipped a tick later, so
            // the change from nothing to standing is a change, and the Behaviors
            // below have something to animate.
            property bool ready: false

            Component.onCompleted: Qt.callLater(() => mark.ready = true)

            x: root.lead + mark.index * root.pitch
            y: (strip.height - height) / 2
            width: root.markSize
            height: root.markSize
            // Qt 6.6+ curve renderer: proper antialiasing without a multisample
            // layer, and the same one G2Rect asks for.
            preferredRendererType: Shape.CurveRenderer

            visible: mark.opacity > 0.004

            // The arrival, and the departure. Scale rather than width, so a mark
            // grows in PLACE: nothing around it is laid out against it.
            opacity: mark.ready && mark.standing ? 1 : 0
            scale: mark.ready && mark.standing ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    // Overshoots a little and settles. The one place in this
                    // shell where a spring is right: it is a discrete arrival
                    // with a known start and end, not something tracking a
                    // moving target, and it is the machine ANSWERING a keystroke
                    // rather than reporting a state.
                    easing.type: Easing.OutBack
                    easing.overshoot: 2.2
                }
            }

            ShapePath {
                // COLOURED, and coloured from the THEME rather than from a
                // palette invented here: the three saturated stops the rest of
                // the shell draws its gauges and meters with, taken in turn. A
                // strip of marks in one flat grey is the same strip of identical
                // dots the shapes exist to get away from - the eye reads a
                // texture rather than a count.
                //
                // THE COLOUR COMES FROM THE POSITION, exactly as the shape does,
                // and for the same reason. lobes.js carries the argument:
                // anything about a mark that depended on the CHARACTER would be
                // the secret, written on the screen in a code anyone could read
                // off a photograph.
                //
                // A refusal overrides the lot. That is the one state where the
                // strip has something to say that matters more than being
                // pretty.
                fillColor: root.alarm ? Appearance.colour.alarm : Appearance.colour.spectrum[mark.index % Appearance.colour.spectrum.length]
                strokeWidth: 0
                strokeColor: "transparent"

                PathSvg {
                    // THE INDEX AND NOTHING ELSE decides the shape.
                    path: Lobes.path(mark.index, root.markSize)
                }
            }
        }
    }

    // The marks that have been made, in index order. Only ever appended to
    // while the field lives: a mark that has been on screen once is kept, so
    // backspacing and retyping reuses it instead of playing its arrival again
    // from nothing.
    property var made: []

    function grow(): void {
        while (root.made.length < root.shown && root.made.length < root.maxMarks)
            root.made.push(markShape.createObject(strip, {
                index: root.made.length
            }));
    }

    onShownChanged: root.grow()

    Item {
        id: marks

        anchors.fill: parent
        anchors.leftMargin: Appearance.padding.large
        anchors.rightMargin: Appearance.padding.large
        clip: true

        // WHAT PANS. An Item rather than anchors on the marks themselves, so
        // there is exactly one x in the whole strip and the marks go on being
        // positioned by their index alone. NOT `anchors.fill`, which would set
        // x and then quietly win the argument with the pan.
        Item {
            id: strip

            x: -pan.value
            y: 0
            width: parent.width
            height: parent.height
        }

        // THE CARET, which is the whole reason the panning above has a rule
        // rather than just sticking to the end.
        //
        // A field with no caret can still be edited - Home, the arrow keys, a
        // backspace from the middle - and every one of those is invisible
        // without one. Drawn on the mark grid rather than at the text's own
        // cursor, because the text is NoEcho and its cursor never leaves zero;
        // this is the position that means something to somebody looking at the
        // strip.
        //
        // Only while the field is focused, and only when there is a secret to
        // be in the middle of: an empty field has the placeholder in that spot
        // and a bar in front of the word "password" reads as a glyph.
        G2Rect {
            x: strip.x + root.caretAt(field.cursorPosition) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            // A SIXTH OF A MARK, not the seam's two pixels. The seam is a line
            // drawn along the edge of a shape, where two pixels is a hairline
            // catching light; this is a shape in its own right standing in a row
            // of other shapes, and at that width it read as a rendering artefact
            // when it read as anything at all.
            width: Math.max(2, Math.round(root.markSize / 6))
            height: root.markSize
            radius: width / 2
            color: root.alarm ? Appearance.colour.alarm : Appearance.colour.accent
            visible: field.activeFocus && !root.empty
        }
    }
}
