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
// THE FIELD IS components/SecretField.qml, which is the shell's one field for
// typing a secret into and knows nothing about keyrings. It is placed here with
// `claims` off: that flag is for a field buried inside a menu, which has to tell
// components/Prompts.qml so its surface asks the compositor for the keyboard,
// and this panel is already named in ShellWindow's keyboardFocus term. A claim
// on top of that would be an entry Menus.needsKeyboard then reads.
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

    // THE ANSWER GOES OUT THROUGH THE FIELD, never around it. SecretField hands
    // its contents to nobody except its own `accepted` signal, so the button
    // asks the field to submit rather than reading it and submitting itself;
    // that is the whole reason the component has no readable text.
    function answer(): void {
        if (root.asksForSecret) {
            field.submit();
            return;
        }
        Keyring.confirm();
    }

    // ONE value drives the arrival: the ground going dark, and the card coming
    // forward out of it. Exponential smoothing, the way everything in this shell
    // moves, so it goes fast while it is far and settles rather than stopping.
    //
    // IT COMES FORWARD RATHER THAN RISING. A panel in this shell arrives from
    // the edge it was pulled out of, and this one was pulled out of nothing: it
    // is a question that interrupted you, from an application you were not
    // looking at. Sliding it in from a direction would be claiming a gesture
    // that never happened. So it scales up into place from just behind the
    // screen, which is the one arrival that says "this is in front of
    // everything" rather than "this came from over there".
    //
    // Nothing drives an exit animation, because the answer has already gone over
    // the bus by the time the card starts coming down, and a card lingering over
    // a question that is finished is a card you can type into twice.
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

    // HOW TALL THE CARD IS, chased rather than assigned. gnome-keyring answers a
    // wrong password by asking again down the same conversation, so the card is
    // already on screen when a warning line appears under the field; taking the
    // new height on the next frame would move the buttons out from under a
    // cursor that is on its way to press one of them again.
    //
    // Snapped while the card is closed, so an opening card is the size it should
    // be rather than growing into it, and snapped when the QUESTION changes for
    // the same reason: a new question is a new card as far as the eye is
    // concerned, even when it arrives without the old one leaving.
    Follow {
        id: tall

        speed: Appearance.anim.resizeSpeed
        target: body.implicitHeight + Appearance.padding.huge * 2

        onTargetChanged: if (!root.open)
            tall.snap()
    }

    // WHAT IT SAYS, in the order somebody reads it. Empty lines are absent
    // rather than blank: gnome-keyring fills in different subsets of these
    // depending on what it is asking about, and a card with a hole in it where
    // an unset description would go reads as a broken card.
    // WHERE ESCAPE LANDS WHEN THERE IS NO FIELD.
    //
    // A password question focuses its field and the field answers Escape itself.
    // A CONFIRM has no field, so without this there is nothing focused on the
    // whole surface: the panel holds the compositor's keyboard exclusively and
    // then drops every key on the floor, which is a yes/no question that cannot
    // be said no to. It has no size and is always visible, so it is always
    // focusable - the card is invisible until the reveal has moved off zero, and
    // an invisible item cannot hold focus. SessionMenu's, and its reasoning,
    // unchanged.
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

    // The field takes the caret on its own (SecretField.land), so this is only
    // ever about the question that has no field. Deferred, because the surface
    // is handed the keyboard a round trip after it asks.
    onOpenChanged: if (root.open && !root.asksForSecret)
        Qt.callLater(keys.forceActiveFocus)

    // THE GROUND, going dark. Not decoration: the card is a modal question
    // standing over somebody's desktop, and without it the shell's own
    // translucent material sits on whatever noise happens to be behind it and
    // reads as a panel that failed to load. The lock screen dims and blurs its
    // ground for the same reason; this one cannot blur (there is a whole desktop
    // under it, not a wallpaper) so it dims and stops there.
    //
    // A plain Rectangle, so it has no corner to get wrong, and it takes no input
    // of its own: the catcher below is what answers a click.
    Rectangle {
        anchors.fill: parent
        color: Appearance.colour.scrim
        opacity: reveal.value
        visible: reveal.value > 0.001
    }

    // DECLARED FIRST among the things that take input, so it sits under the
    // card: declaration order is input order. Anywhere that is not the card is a
    // refusal.
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
        y: root.holeY + (root.holeHeight - height) / 2
        width: root.cardWidth
        height: tall.value

        visible: reveal.value > 0.001
        enabled: root.open
        opacity: reveal.value

        // A TWELFTH OF ITSELF, and no more. The card is most of the width of the
        // content area, so a scale that started anywhere near zero would sweep
        // the whole middle of the screen on the way in; from this close it reads
        // as the card settling onto the glass rather than as something flying at
        // you. Centred, because it is not coming from anywhere.
        transformOrigin: Item.Center
        scale: 1 - (1 - reveal.value) / 12

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
                // BALANCED, not greedy, and every one of these strings is the
                // reason why: the title, the message, the description and the
                // tickbox's label are all written by whatever asked for the
                // secret, at whatever length it felt like, so there is no
                // hand-placed break anywhere and no way to add one. Greedy wrap
                // filled the first line and left "logged in" alone on the
                // second, which reads as text that overflowed rather than text
                // that was set. See components/BalancedText.qml.
                BalancedText {
                    width: parent.width
                    visible: !!Keyring.message
                    text: Keyring.message
                    color: Appearance.colour.textDim
                }

                BalancedText {
                    width: parent.width
                    visible: !!Keyring.description
                    text: Keyring.description
                    color: Appearance.colour.textFaint
                }

                // -- the field, when there is one to fill in ------------------
                //
                // Absent entirely for a confirm, rather than shown disabled: a
                // question with a yes and a no has nothing to type into, and a
                // greyed box would only invite somebody to try.
                //
                // components/SecretField.qml, which is the shell's one field for
                // this. It CLAIMS NOTHING: this panel is named directly in
                // ShellWindow's keyboardFocus term, so the surface already asks
                // for the keyboard on its own account, and a Prompts claim on
                // top of that is an entry Menus.needsKeyboard would then read.
                SecretField {
                    id: field

                    width: parent.width
                    visible: root.asksForSecret
                    placeholder: Keyring.passwordNew ? "new password" : "password"
                    alarm: !!Keyring.warning

                    onAccepted: secret => Keyring.submit(secret)
                    onCancelled: Keyring.refuse()

                    // A FRESH QUESTION EMPTIES IT, keyed on the count of
                    // questions rather than on the card opening. gnome-keyring
                    // answers a wrong password by asking again down the same
                    // conversation, so the card never closes between the two
                    // attempts and an `open` test would leave the rejected
                    // password sitting in the field for somebody to press Enter
                    // on a second time.
                    readonly property int asked: Keyring.asked
                    onAskedChanged: field.clear()
                }

                // -- what went wrong ------------------------------------------
                //
                // NOT A RESERVED SLOT, and it was one for a while. The idea was
                // that a fixed height keeps the buttons from moving out from
                // under the cursor when a password is rejected, which is a real
                // thing to want; what it actually produced was a card with a
                // hole in it, because the line that used to fill the slot while
                // there was nothing to report ("enter to answer, escape to
                // refuse") was furniture and had to go. A row of empty air
                // between the field and the tickbox reads as a layout that
                // broke.
                //
                // So the line is simply absent until there is one, and the CARD
                // absorbs the difference: its height is smoothed
                // (`tall`, below), so a warning arriving grows the card into it
                // over a few frames rather than teleporting the buttons. That is
                // the shell's own answer to a panel that changes size - the
                // hotkey sheet does the same thing with its two views - and it
                // is a better one than reserving room for a message that is
                // usually not there.
                StyledText {
                    width: parent.width
                    elide: Text.ElideRight
                    visible: !!Keyring.warning
                    text: Keyring.warning
                    color: Appearance.colour.alarm
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

                    BalancedText {
                        id: choiceLabel

                        anchors.left: choice.right
                        anchors.right: parent.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.verticalCenter: parent.verticalCenter
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
                        readonly property bool ready: !root.asksForSecret || !field.empty

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
