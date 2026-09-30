pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "theme.js" as Theme

ShellRoot {
    id: root

    readonly property string dir: Quickshell.env("BANDITSHELL_ASKPASS_DIR") || `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/banditshell-askpass`

    property bool armed: false
    property bool errorState: false
    property int attempt: 1
    property bool revealed: false

    property string outgoing: ""

    property string secret: ""

    signal focusWanted

    Process {
        command: ["sh", "-c", 'touch "$1/ready"', "_", root.dir]
        running: true
    }

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

                    root.attempt += 1;
                    root.errorState = true;
                } else {
                    root.errorState = false;
                }

                root.secret = "";
                root.armed = true;
                root.focusWanted();
            }
        }
    }

    Process {
        id: reply

        command: ["sh", "-c", 'cat > "$1/rsp"', "_", root.dir]
        stdinEnabled: true

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
        root.secret = "";
    }

    function cancel(): void {
        markCancelled.running = true;
        root.outgoing = "";
        root.secret = "";
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

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win

            required property ShellScreen modelData

            screen: win.modelData
            color: "transparent"

            readonly property bool holdsKeyboard: Quickshell.screens[0]?.name === win.modelData.name

            WlrLayershell.layer: WlrLayer.Overlay

            WlrLayershell.keyboardFocus: win.holdsKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "banditshell-askpass"
            exclusiveZone: 0

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

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

            G2Rect {
                id: card

                anchors.horizontalCenter: parent.horizontalCenter

                width: Math.max(560, Math.min(620, parent.width - Theme.padHuge * 2))
                height: body.implicitHeight + Theme.padHuge * 2
                radius: Theme.rLarge
                color: Theme.body
                stroke: Theme.ramp[5]
                strokeWidth: 1

                opacity: appear.value

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

                    Item {
                        id: fieldBlock

                        width: parent.width
                        height: 76

                        readonly property bool floated: field.activeFocus || root.secret.length > 0

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

                            bottomLeftRadius: 0
                            bottomRightRadius: 0
                            color: Theme.fill

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

                            readonly property bool surfaceActive: field.Window.active
                            onSurfaceActiveChanged: if (field.surfaceActive)
                                field.forceActiveFocus()

                            text: root.secret

                            onAccepted: if (root.secret.length > 0)
                                root.send(root.secret)

                            Keys.onEscapePressed: root.cancel()

                            onTextChanged: {
                                root.secret = field.text;
                                if (field.text.length > 0)
                                    root.errorState = false;
                            }

                            Connections {
                                target: root

                                function onFocusWanted(): void {
                                    field.forceActiveFocus();
                                }
                            }
                        }

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

                        G2Rect {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1 + focusIn.value
                            radius: 0
                            color: root.errorState ? Theme.alarm : (field.activeFocus ? Theme.mid : Theme.ramp[5])
                        }
                    }

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

                    Row {
                        anchors.right: parent.right
                        spacing: Theme.padNormal

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

                        G2Rect {
                            id: submit

                            readonly property bool ready: root.secret.length > 0

                            width: submitLabel.implicitWidth + Theme.padHuge * 2
                            height: 52
                            radius: Theme.rNormal
                            color: Theme.mid
                            opacity: submit.ready ? (submitHit.containsMouse ? 1 : 0.9) : 0.35

                            BsText {
                                id: submitLabel

                                anchors.centerIn: parent
                                text: "unlock"

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
                                onClicked: root.send(root.secret)
                            }
                        }
                    }
                }
            }
        }
    }
}
