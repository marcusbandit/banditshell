//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme.js" as Theme

// The password receiver, for the install that needs root and has no passwordless
// route to it.
//
// WHAT IT IS. sudo's askpass protocol wants a program that prints a password on
// stdout. installer/askpass.sh is that program; this is the window it puts up,
// and the two talk over a pair of fifos in a 0700 directory under the runtime
// dir. The split exists so this window can OUTLIVE a single call: sudo answers a
// wrong password by running the askpass program again, and a window that was
// torn down and redrawn per attempt would flash away at exactly the moment
// somebody is about to mistype a second time. Instead the helper reconnects to
// the window already on screen and it shows its error in place.
//
// WHAT IT NEVER DOES. The value in `field.text` goes into one Process's stdin
// and nowhere else. It is not logged, not put in an argument, not written to a
// file, and not held after it is sent. Quickshell writes its logs to disk, so a
// stray console.log in this file would be a real leak; there are none, and there
// must not be.
//
// THE LOOK. Material 3's STRUCTURE, because it is the right structure for a
// credential prompt and everybody already knows how to read it: a filled field,
// a label that floats out of the way when the field is in use, an active
// indicator that thickens and takes colour on focus, an explicit error state, a
// reveal toggle, and one prominent primary action. None of Material's SKIN: the
// colours are banditshell's slate ramp and the face is Monocraft, because a
// prompt that showed up in Roboto and purple would be the one part of this
// install that looked like it came from somewhere else.
// See ~/.claude/rules/working-style.md.
//
// It deliberately uses NO icon font. It can be on screen before phase 2 has
// installed Material Symbols, so every control in here is a word.
ShellRoot {
    id: root

    readonly property string dir: Quickshell.env("BANDITSHELL_ASKPASS_DIR") || `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-askpass`

    // A request is outstanding: the helper is blocked reading the response fifo
    // and something has to be sent before it times out.
    property bool armed: false
    property bool errorState: false
    property int attempt: 1
    property bool revealed: false

    // Held only between "send it" and the moment the writer starts.
    property string outgoing: ""

    // -------------------------------------------------------------- the io --

    // Tell the helper the window exists, so it stops waiting and starts asking.
    Process {
        command: ["sh", "-c", 'touch "$1/ready"', "_", root.dir]
        running: true
    }

    // The request side. `cat` on a fifo returns when the writer closes, so this
    // loops: one iteration per question the helper asks.
    Process {
        id: requests

        command: ["sh", "-c", 'while true; do cat "$1/req"; done', "_", root.dir]
        running: true

        stdout: SplitParser {
            onRead: line => {
                const token = line.trim();
                if (!token)
                    return;

                if (token === "retry") {
                    // sudo rejected the last one. Say so, empty the field, and
                    // leave everything else exactly where it was.
                    root.attempt += 1;
                    root.errorState = true;
                } else {
                    root.errorState = false;
                }

                field.text = "";
                root.armed = true;
                field.forceActiveFocus();
            }
        }
    }

    // The response side. One process per answer, because the helper reads a
    // single line and then closes its end.
    Process {
        id: reply

        command: ["sh", "-c", 'cat > "$1/rsp"', "_", root.dir]
        stdinEnabled: true

        // Written on `started` rather than straight after setting running, so
        // the pipe exists before anything is put down it.
        onStarted: {
            reply.write(root.outgoing + "\n");
            root.outgoing = "";
        }
    }

    Process {
        id: markCancelled
        command: ["sh", "-c", 'touch "$1/cancelled"', "_", root.dir]
    }

    function send(secret: string): void {
        if (!root.armed)
            return;
        root.armed = false;
        root.outgoing = secret;
        reply.running = false;
        reply.running = true;
        field.text = "";
    }

    // Escape gives up on the whole install, which is why it is worth being
    // explicit about: the flag is dropped BEFORE the empty answer, so the helper
    // sees the file when it wakes up and exits non-zero instead of handing sudo
    // an empty password to reject three times.
    function cancel(): void {
        markCancelled.running = true;
        root.outgoing = "";
        root.armed = false;
        reply.running = false;
        reply.running = true;
        quitSoon.running = true;
    }

    Timer {
        id: quitSoon
        interval: 250
        onTriggered: Qt.quit()
    }

    // ---------------------------------------------------------- the surface --

    PanelWindow {
        id: win

        color: "transparent"

        WlrLayershell.layer: WlrLayer.Overlay
        // EXCLUSIVE, and this is the one window in the installer that takes the
        // keyboard. A password field that silently drops keystrokes is worse
        // than no password field, and on a layer surface the keyboard is
        // something the window has to ask the compositor for.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        WlrLayershell.namespace: "banditshell-askpass"
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // The scrim. Not a shape, so it has no corner to get wrong.
        Rectangle {
            anchors.fill: parent
            color: Theme.void_
            opacity: 0.88 * appear.value
        }

        Smooth {
            id: appear
            target: 1
            speed: 10
            Component.onCompleted: value = 0
        }

        // -- the card ---------------------------------------------------------
        G2Rect {
            id: card

            // Centred horizontally by anchor, placed vertically by hand. NOT
            // `anchors.centerIn`, which would win against the `y` below and
            // silently drop the rise: an anchor and an assignment to the same
            // axis is a conflict QML resolves in the anchor's favour without
            // saying anything about it.
            anchors.horizontalCenter: parent.horizontalCenter

            // Never wider than the screen it is drawn on, and never narrower
            // than the width the contents were laid out for. The ceiling stops
            // the card running off both edges of a small display; the floor
            // stops the opposite failure, where a card squeezed under about 560
            // pushes the reveal toggle through the input and drops a button off
            // the row. Between them it just centres.
            width: Math.max(560, Math.min(620, parent.width - Theme.padHuge * 2))
            height: body.implicitHeight + Theme.padHuge * 2
            radius: Theme.rLarge
            color: Theme.body
            stroke: Theme.ramp[5]
            strokeWidth: 1

            opacity: appear.value
            // Rises the last few pixels into place rather than arriving at rest.
            y: (parent.height - height) / 2 + (1 - appear.value) * 24

            Column {
                id: body

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.padHuge
                anchors.rightMargin: Theme.padHuge
                spacing: Theme.padNormal

                BsText {
                    text: "banditshell"
                    font.pixelSize: Theme.large
                    color: Theme.text
                }

                BsText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Theme.textFaint
                    text: "The installer needs administrator access to install packages. You will only be asked once."
                }

                Item {
                    width: 1
                    height: Theme.padSmall
                }

                // -- the filled field -----------------------------------------
                //
                // Material 3's filled variant: a tinted container with rounded
                // top corners sitting on an active indicator, the label resting
                // inside it when empty and floating to the top once it is in
                // use. The corners are squircles rather than arcs, which is the
                // one thing about the shape that is not Material's.
                Item {
                    id: fieldBlock

                    width: parent.width
                    height: 76

                    readonly property bool floated: field.activeFocus || field.text.length > 0

                    Smooth {
                        id: floatUp
                        target: fieldBlock.floated ? 1 : 0
                        speed: 13
                    }

                    Smooth {
                        id: focusIn
                        target: field.activeFocus ? 1 : 0
                        speed: 12
                    }

                    G2Rect {
                        id: container

                        anchors.fill: parent
                        topLeftRadius: Theme.rNormal
                        topRightRadius: Theme.rNormal
                        // Square at the bottom, because the active indicator is
                        // the bottom edge. That is the Material shape and it is a
                        // true right angle, not a rounding someone forgot.
                        bottomLeftRadius: 0
                        bottomRightRadius: 0
                        color: Theme.fill

                        // THE STATE LAYER: Material's way of showing a control is
                        // being interacted with, as an overlay on the container
                        // rather than a colour swap.
                        G2Rect {
                            anchors.fill: parent
                            topLeftRadius: Theme.rNormal
                            topRightRadius: Theme.rNormal
                            bottomLeftRadius: 0
                            bottomRightRadius: 0
                            color: root.errorState ? Theme.alarm : Theme.mid
                            opacity: 0.10 * focusIn.value
                        }
                    }

                    // The floated label and the resting label are two items
                    // crossfading, not one item being scaled: Monocraft is a
                    // pixel font and a scaled pixel font is a smeared one. Each
                    // is drawn at one of the three sizes and stays crisp.
                    BsText {
                        x: Theme.padLarge
                        y: Theme.padSmall + (1 - floatUp.value) * 8
                        opacity: floatUp.value
                        font.pixelSize: Theme.small
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 2
                        text: "password"
                        color: root.errorState ? Theme.alarm : (field.activeFocus ? Theme.mid : Theme.textFaint)
                    }

                    BsText {
                        x: Theme.padLarge
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: 1 - floatUp.value
                        font.pixelSize: Theme.normal
                        text: "password"
                        color: Theme.textFaint
                    }

                    TextInput {
                        id: field

                        x: Theme.padLarge
                        y: parent.height - height - Theme.padNormal
                        width: parent.width - Theme.padLarge - reveal.width - Theme.padLarge * 2

                        focus: true
                        clip: true
                        echoMode: root.revealed ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "*"

                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.normal
                        renderType: Text.NativeRendering
                        color: Theme.text
                        selectionColor: Theme.mid
                        selectedTextColor: Theme.ramp[0]

                        // ASKING for the keyboard and HAVING it are a round trip
                        // apart: a layer surface gets no key events at all until
                        // its window asks the compositor for them, and the
                        // compositor hands them over a frame or more later. Focus
                        // taken before that lands is focus in a surface with no
                        // keys to give, so it is taken again the moment the
                        // surface actually becomes active. This is the same trap
                        // components/PasswordField.qml documents, and the same
                        // fix. A password field that silently swallows the first
                        // few characters is the worst possible bug to ship here.
                        readonly property bool surfaceActive: field.Window.active
                        onSurfaceActiveChanged: if (field.surfaceActive)
                            field.forceActiveFocus()

                        onAccepted: if (field.text.length > 0)
                            root.send(field.text)

                        Keys.onEscapePressed: root.cancel()

                        // Typing is the retry: the error goes the moment the
                        // person does something about it.
                        onTextChanged: if (field.text.length > 0)
                            root.errorState = false
                    }

                    // The reveal toggle. A word, not an icon: the icon font may
                    // not be installed yet at the moment this is on screen.
                    BsText {
                        id: reveal

                        anchors.right: parent.right
                        anchors.rightMargin: Theme.padLarge
                        anchors.verticalCenter: field.verticalCenter
                        text: root.revealed ? "hide" : "show"
                        color: revealHit.containsMouse ? Theme.mid : Theme.ramp[7]
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: 2

                        MouseArea {
                            id: revealHit

                            anchors.fill: parent
                            anchors.margins: -Theme.padSmall
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.revealed = !root.revealed;
                                field.forceActiveFocus();
                            }
                        }
                    }

                    // THE ACTIVE INDICATOR: one pixel at rest, two and coloured
                    // on focus, the alarm colour when the last attempt was
                    // rejected. The thickness is smoothed, so focus arrives as a
                    // movement rather than a jump.
                    G2Rect {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1 + focusIn.value
                        radius: 0
                        color: root.errorState ? Theme.alarm : (field.activeFocus ? Theme.mid : Theme.ramp[5])
                    }
                }

                // -- the supporting line ---------------------------------------
                //
                // Material keeps a fixed slot under the field so the card does
                // not resize when an error appears. Same here.
                Item {
                    width: parent.width
                    height: Theme.small * 4 / 3

                    BsText {
                        color: root.errorState ? Theme.alarm : Theme.ramp[6]
                        text: root.errorState ? `Incorrect password. Attempt ${root.attempt} of 3.` : "Enter to unlock, Escape to cancel the install."
                    }
                }

                Item {
                    width: 1
                    height: Theme.padSmall
                }

                // -- the actions ------------------------------------------------
                Row {
                    anchors.right: parent.right
                    spacing: Theme.padNormal

                    // The quiet one. Text only, because two filled buttons side
                    // by side is two primary actions and there is only one here.
                    G2Rect {
                        width: cancelLabel.implicitWidth + Theme.padLarge * 2
                        height: 52
                        radius: Theme.rNormal
                        color: Theme.plate
                        opacity: cancelHit.containsMouse ? 1 : 0.75

                        BsText {
                            id: cancelLabel

                            anchors.centerIn: parent
                            text: "cancel"
                            color: Theme.ramp[8]
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 2
                        }

                        MouseArea {
                            id: cancelHit

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.cancel()
                        }
                    }

                    // The primary action, and the only filled thing on the card.
                    G2Rect {
                        id: submit

                        readonly property bool ready: field.text.length > 0

                        width: submitLabel.implicitWidth + Theme.padHuge * 2
                        height: 52
                        radius: Theme.rNormal
                        color: Theme.mid
                        opacity: submit.ready ? (submitHit.containsMouse ? 1 : 0.9) : 0.35

                        BsText {
                            id: submitLabel

                            anchors.centerIn: parent
                            text: "unlock"
                            // On the accent, so the text is the ground colour.
                            color: Theme.ramp[0]
                            font.capitalization: Font.AllUppercase
                            font.letterSpacing: 2
                        }

                        MouseArea {
                            id: submitHit

                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: submit.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.send(field.text)
                        }
                    }
                }
            }
        }
    }
}
