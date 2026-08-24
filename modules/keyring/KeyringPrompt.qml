pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// THE KEYRING'S QUESTION, drawn by the shell instead of by gcr.
//
// What used to happen here was a GTK dialog: gcr-prompter, activated by D-Bus,
// putting a grey box in Cantarell on whichever workspace it landed on, with no
// relationship to anything else on this screen. services/Keyring.qml takes that
// job off it; this is the card.
//
// A SUMMONED PANEL, and the odd one out among them: every other panel in this
// shell is opened by somebody reaching for it, and this one is opened by an
// application wanting a secret. That changes exactly one thing about its
// lifecycle, and it is worth being explicit about which: there is no gesture
// that summons it, so there is no gesture that reverses it, and the two ways
// out are Escape and the buttons. It is otherwise the power panel's shape - a
// catcher underneath, the keyboard taken outright, an arrival that rises rather
// than appearing.
//
// A CLICK OFF IT IS A NO, not a dismissal. This is the one panel here where
// closing and answering are the same act: something is BLOCKED waiting for this
// and a card that could be put away without answering would leave the
// application hanging on a question nobody can see any more. So the catcher
// refuses rather than hides, which is also what closing gcr's dialog did.
//
// THE CARD IS MODELLED ON installer/askpass.qml, which is this shell's other
// credential prompt, and deliberately so: a password question should look like
// the same object wherever this shell asks one. Material 3's structure, none of
// its skin - a filled field, an active indicator that takes colour on focus, a
// fixed slot for the error so the card does not resize when one appears, and
// one prominent action.
//
// IT DOES NOT USE components/PasswordField.qml, and that is not an oversight.
// That field registers a claim in components/Prompts.qml so that the WINDOW
// knows to ask the compositor for the keyboard on its behalf, which is the
// right answer for a field buried two levels down inside a menu's content. This
// panel is named directly in ShellWindow's keyboardFocus term, so it needs no
// claim; making one would put a Prompts entry on the shell for as long as a
// keyring question is up, and Menus.needsKeyboard reads that list.
Item {
    id: root

    // The content area, handed down rather than derived, so the card centres in
    // the space windows actually live in. See the note over CheatSheet, which
    // derives its own and says this is the honest fix.
    required property real holeX
    required property real holeY
    required property real holeWidth
    required property real holeHeight

    // WHICH SCREEN THIS SURFACE IS, asked of the window rather than threaded
    // down: the screen is a fact about the surface, not about the question.
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    // ON THE ONE SCREEN THE SERVICE LATCHED, and on no other. There is one of
    // these per monitor and exactly one may take the keyboard; two cards both
    // asking would be the "typing goes nowhere" failure ShellWindow's
    // keyboardFocus note spends eighty lines on.
    readonly property bool open: Keyring.active && Keyring.screenName === root.screenName

    // The whole screen while it is up, so a click anywhere off the card is an
    // answer. The power panel's catcher, with a different verb behind it.
    readonly property Item maskItem: catcher

    // Every key, while a question is up. Named in ShellWindow's exclusive term.
    readonly property bool needsKeyboard: root.open

    // Whether the answer needs typing, or is only a yes and a no.
    readonly property bool asksForSecret: Keyring.kind === "password"

    // The client's own words, with a fallback for a client that named neither.
    readonly property string goLabel: Keyring.continueLabel || (root.asksForSecret ? "unlock" : "continue")
    readonly property string stopLabel: Keyring.cancelLabel || "cancel"

    function answer(): void {
        if (root.asksForSecret) {
            if (field.text.length > 0)
                Keyring.submit(field.text);
            return;
        }
        Keyring.confirm();
    }

    // ONE value drives the arrival, the way the lock screen's does: exponential
    // smoothing, so it moves fast while it is far and settles rather than
    // stopping. Nothing drives an exit animation, because the answer has already
    // gone over the bus by the time this starts coming down and a card lingering
    // over a question that is finished is a card you can type into twice.
    Follow {
        id: reveal

        speed: Appearance.anim.revealSpeed
        target: root.open ? 1 : 0
        // A 0-to-1 fraction, not a pixel count: the default quarter-pixel
        // epsilon would leave a closed card permanently a quarter open.
        epsilon: 0.005
    }

    // THE CARD'S WIDTH, in characters rather than in pixels. The shell's face is
    // monospaced, so a column count is an exact width at any font size and
    // survives somebody changing the type scale; a number of pixels would be a
    // measurement of today's font. Bounded by the content area, so a narrow
    // screen gets a narrower card instead of one hanging off both edges.
    TextMetrics {
        id: em

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "M"
    }

    readonly property real cardWidth: Math.min(root.holeWidth - Appearance.padding.huge * 2, em.advanceWidth * 56)

    // WHAT IT SAYS, in the order somebody reads it. Empty lines are absent
    // rather than blank: gnome-keyring fills in different subsets of these
    // depending on what it is asking about, and a card with a hole in it where
    // an unset description would go reads as a broken card.
    Item {
        id: keys

        // Tested on `event.key` rather than through Keys.onEscapePressed, to
        // match the power panel and the hotkey sheet: the named handlers were
        // measured not firing on an item reached this way.
        Keys.onPressed: event => {
            if (event.key !== Qt.Key_Escape)
                return;
            Keyring.refuse();
            event.accepted = true;
        }
    }

    // DECLARED FIRST, so it sits under the card: declaration order is input
    // order. Anywhere that is not the card is a refusal.
    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.open
        visible: root.open

        onClicked: Keyring.refuse()
    }

    Item {
        id: card

        x: root.holeX + (root.holeWidth - root.cardWidth) / 2
        y: root.holeY + (root.holeHeight - height) / 2 + (1 - reveal.value) * Appearance.padding.huge
        width: root.cardWidth
        height: body.implicitHeight + Appearance.padding.huge * 2

        visible: reveal.value > 0.001
        enabled: root.open
        opacity: reveal.value

        G2Rect {
            anchors.fill: parent

            radius: Appearance.rounding.large
            color: Appearance.colour.surface

            // THE SEAM THE SHELL'S OWN EDGE HAS, on the card and on every piece
            // inside it. The chassis draws this line along its inner edge
            // (components/blob/BlobField.qml) and it is what makes the shell
            // read as machined rather than as a translucent sheet; a card
            // floating in the middle of the screen without it is visibly a
            // different material from the thing it is floating in front of. One
            // token, so the panel's line and the edge's cannot drift apart.
            stroke: Appearance.colour.seam
            strokeWidth: Appearance.sizes.seam

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Appearance.padding.huge
                anchors.rightMargin: Appearance.padding.huge
                spacing: Appearance.padding.normal

                // The one thing the card is about, and the only place the
                // second tier is spent. Capitalised as the client wrote it:
                // "Unlock Login Keyring" is gnome-keyring's own sentence and
                // rewording it would be the shell inventing a fact about
                // somebody else's question.
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Keyring.title || "Keyring"
                    font.pixelSize: Appearance.font.size.normal
                }

                // NO `height` BINDING ON EITHER OF THESE, and that is the fix
                // rather than an omission: a Column already leaves invisible
                // children out of its layout, so `height: visible ?
                // implicitHeight : 0` bought nothing and cost a binding loop -
                // a wrapping Text derives its implicitHeight from the room it
                // has, so feeding that back into its height is a cycle Qt
                // reports and then resolves by guessing.
                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: !!Keyring.message
                    text: Keyring.message
                    color: Appearance.colour.textDim
                }

                StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    visible: !!Keyring.description
                    text: Keyring.description
                    color: Appearance.colour.textFaint
                }

                // -- the field, when there is one to fill in ------------------
                //
                // Absent entirely for a confirm, rather than shown disabled: a
                // question with a yes and a no has nothing to type into and a
                // greyed box would only invite somebody to try.
                Item {
                    id: fieldBlock

                    width: parent.width
                    height: em.height * 3
                    visible: root.asksForSecret

                    Follow {
                        id: focusIn

                        speed: Appearance.anim.revealSpeed
                        target: field.activeFocus ? 1 : 0
                        epsilon: 0.005
                    }

                    G2Rect {
                        anchors.fill: parent
                        topLeftRadius: Appearance.rounding.normal
                        topRightRadius: Appearance.rounding.normal
                        // Square at the bottom, because the bottom edge IS the
                        // active indicator. A true right angle, not a rounding
                        // somebody forgot.
                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                        color: Appearance.colour.fill
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.sizes.seam
                    }

                    // NO ECHO, and no passwordCharacter either. A field full of
                    // asterisks is a font's answer to this question, and it is
                    // the one part of a credential prompt everybody looks at
                    // while they type. The marks below are drawn instead; `text`
                    // still holds the real thing, so this changes only what is
                    // painted. The caret goes with the asterisks, because a
                    // caret in a line that never grows is a caret that never
                    // moves. Verbatim modules/lock/LockFace.qml, which asks the
                    // same question two surfaces away.
                    TextInput {
                        id: field

                        anchors.fill: parent
                        anchors.leftMargin: Appearance.padding.large
                        anchors.rightMargin: Appearance.padding.large
                        anchors.bottomMargin: Appearance.padding.small

                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.NoEcho
                        cursorVisible: false
                        clip: true

                        font.family: Appearance.font.family
                        font.pixelSize: Appearance.font.size.small
                        renderType: Text.NativeRendering
                        color: Appearance.colour.text

                        onAccepted: root.answer()

                        Keys.onEscapePressed: Keyring.refuse()

                        // ASKING for the keyboard and HAVING it are a round trip
                        // apart: this surface gets no key events until its
                        // window asks the compositor, and the compositor hands
                        // them over a frame or more later. Focus taken before
                        // that lands is focus in a surface with no keys to give,
                        // so it is taken again when the surface actually becomes
                        // active. components/PasswordField.qml documents the
                        // same trap; a password field that swallows the first
                        // few characters is the worst thing to ship here.
                        readonly property bool surfaceActive: field.Window.active
                        onSurfaceActiveChanged: if (field.surfaceActive && root.open)
                            field.forceActiveFocus()

                        // A FRESH QUESTION EMPTIES IT, keyed on the serial
                        // rather than on `open`. gnome-keyring answers a wrong
                        // password by asking again down the same conversation,
                        // so the card never closes between the two attempts and
                        // an `open` test would leave the rejected password
                        // sitting in the field.
                        readonly property int serial: Keyring.serial
                        onSerialChanged: {
                            field.text = "";
                            if (root.open)
                                field.forceActiveFocus();
                        }

                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Appearance.padding.large
                        anchors.verticalCenter: field.verticalCenter
                        visible: !field.text
                        text: Keyring.passwordNew ? "new password" : "password"
                        color: Appearance.colour.textGhost
                    }

                    // WHAT YOU TYPED, one mark per character, each one growing
                    // in on the frame it is made.
                    //
                    // THE SHAPE IS THE SHELL'S OWN. Material's password dot is a
                    // circle, and Material 3 answers the same question elsewhere
                    // with its own family of soft shapes; this shell has one
                    // shape primitive and it is the G2 squircle, so a mark here
                    // is a squircle at full reach rather than a circle borrowed
                    // from somebody else's system. A radius of half the side
                    // through the G2 construction is what a circle looks like in
                    // this shell's hand: rounder at the compass points, flatter
                    // on the diagonals, and unmistakably the same corner as the
                    // card it is sitting in. See ~/.claude/rules/g2-corners.md.
                    //
                    // The point of drawing them at all is the ARRIVAL. A mark
                    // that is simply there on the next frame is the machine
                    // reporting a fact; one that grows into place is the machine
                    // answering you, and while a password is being typed that
                    // acknowledgement is the only feedback this card can give.
                    //
                    // Clipped rather than shrunk or scrolled, exactly as the lock
                    // screen's are: a long password runs out of field eventually,
                    // and the honest thing is for it to run off the ends.
                    // Rescaling the marks to fit would turn the LENGTH of what
                    // you typed into something readable from across the room.
                    Item {
                        anchors.fill: field
                        clip: true

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Appearance.padding.small

                            Repeater {
                                model: field.text.length

                                delegate: G2Rect {
                                    width: Appearance.sizes.lockDot
                                    height: width
                                    radius: width / 2
                                    color: Keyring.warning ? Appearance.colour.alarm : Appearance.colour.text

                                    // Grown and faded in from nothing, ONCE, on
                                    // the frame it is created. A Behavior is
                                    // right here and wrong almost everywhere
                                    // else in this shell: nothing is already
                                    // smoothing these, so there is no second
                                    // ramp for it to fight with.
                                    scale: 0
                                    opacity: 0

                                    Component.onCompleted: {
                                        scale = 1;
                                        opacity = 1;
                                    }

                                    Behavior on scale {
                                        NumberAnimation {
                                            duration: Appearance.anim.normal
                                            easing.type: Easing.OutCubic
                                        }
                                    }

                                    Behavior on opacity {
                                        NumberAnimation {
                                            duration: Appearance.anim.normal
                                            easing.type: Easing.OutCubic
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // THE ACTIVE INDICATOR: a hairline at rest, thicker and
                    // coloured on focus, and the alarm colour while the last
                    // answer stands rejected. Smoothed, so focus arrives as a
                    // movement rather than a jump.
                    G2Rect {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: Appearance.font.stem * (1 + focusIn.value)
                        radius: 0
                        color: Keyring.warning ? Appearance.colour.alarm : field.activeFocus ? Appearance.colour.accent : Appearance.colour.separator
                    }
                }

                // -- what went wrong, in a slot that is always there ----------
                //
                // A FIXED HEIGHT, so the card does not grow by a line the moment
                // a password is rejected. The buttons would move out from under
                // the cursor at exactly the moment somebody is about to press
                // one of them again.
                Item {
                    width: parent.width
                    height: em.height

                    StyledText {
                        width: parent.width
                        elide: Text.ElideRight
                        text: Keyring.warning || (root.asksForSecret ? "enter to answer, escape to refuse" : "escape to refuse")
                        color: Keyring.warning ? Appearance.colour.alarm : Appearance.colour.textGhost
                    }
                }

                // -- the tickbox, on the questions that offer one -------------
                //
                // "Automatically unlock this keyring whenever I'm logged in",
                // usually. Absent rather than disabled when the client did not
                // offer it, which is most of the time.
                Item {
                    width: parent.width
                    height: Math.max(choice.height, choiceLabel.implicitHeight)
                    visible: !!Keyring.choiceLabel

                    Toggle {
                        id: choice

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        checked: Keyring.choiceChosen

                        onToggled: Keyring.choose(!Keyring.choiceChosen)
                    }

                    StyledText {
                        id: choiceLabel

                        anchors.left: choice.right
                        anchors.right: parent.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
                        wrapMode: Text.WordWrap
                        text: Keyring.choiceLabel
                        color: Appearance.colour.textDim

                        MouseArea {
                            anchors.fill: parent
                            onClicked: Keyring.choose(!Keyring.choiceChosen)
                        }
                    }
                }

                // -- the two answers ------------------------------------------
                //
                // ONE of them is filled. Two prominent buttons side by side is
                // two primary actions, and there is only ever one here: the
                // thing the application is waiting for.
                Row {
                    anchors.right: parent.right
                    spacing: Appearance.padding.normal

                    G2Rect {
                        width: stopMark.implicitWidth + Appearance.padding.large * 2
                        height: em.height * 2
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.fillStrong
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.sizes.seam
                        opacity: stopHit.containsMouse ? 1 : 0.75

                        StyledText {
                            id: stopMark

                            anchors.centerIn: parent
                            text: root.stopLabel
                            color: Appearance.colour.textDim
                        }

                        MouseArea {
                            id: stopHit

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Keyring.refuse()
                        }
                    }

                    G2Rect {
                        id: go

                        // A confirm is always answerable; a password is not
                        // answerable until there is one.
                        readonly property bool ready: !root.asksForSecret || field.text.length > 0

                        width: goMark.implicitWidth + Appearance.padding.huge * 2
                        height: em.height * 2
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.accent
                        stroke: Appearance.colour.seam
                        strokeWidth: Appearance.sizes.seam
                        opacity: go.ready ? (goHit.containsMouse ? 1 : 0.9) : 0.35

                        StyledText {
                            id: goMark

                            anchors.centerIn: parent
                            text: root.goLabel
                            // On the accent, so the mark is the ground colour.
                            color: Appearance.colour.accentText
                        }

                        MouseArea {
                            id: goHit

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: go.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.answer()
                        }
                    }
                }
            }
        }
    }
}
