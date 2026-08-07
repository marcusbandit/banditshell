pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Wi-Fi. This one is real, and it is as much of it as NetworkManager will hand
// over through Quickshell.
//
// The surface is the question you came with: which network, and is it working.
// Everything else is a layer under the row it belongs to, one open at a time,
// the same shape the bluetooth menu uses: the adapter's own settings under the
// Wi-Fi row, and what little there is to say about a network under its row.
//
// WHAT IS NOT HERE, and why. A hotspot is supported by this radio and permitted
// by policy, but making one means handing NetworkManager a whole nested settings
// profile, and Quickshell exposes the type that carries one without exposing any
// way to build it. The same wall stands in front of static addresses, custom
// DNS, metered marking, MAC randomisation and joining a hidden SSID: all of them
// are profile edits, and a profile is exactly what this API cannot construct.
// The alternative is shelling out to nmcli, which this shell does not do for
// anything else and will not start doing here.
Column {
    id: root

    // WHETHER ANYBODY IS LOOKING AT THIS, set by the panel it is loaded into.
    //
    // The question used to be answered by this menu not existing: it was built
    // when the cursor arrived and destroyed when it left, which is exactly the
    // arrangement that made pointing at the wifi gauge cost fifty vector shapes
    // in one frame (MenuPanel.warm has the whole argument). It is built once now
    // and kept, so everything that costs something while nobody is reading it
    // has to hang off this instead: the radio, below, and any layer or prompt
    // left open, because coming back to a menu should find it the way it starts
    // rather than mid-sentence.
    //
    // DEFAULT FALSE, so a menu incubating at startup cannot switch the scanner
    // on for the frames between being built and being told where it is.
    property bool showing: false

    // A secured network you have never joined needs a password, and the place to
    // ask is the row you just pressed. Only one row can be asking at a time.
    property string asking: ""

    // Which layer is unrolled: a network name, "adapter", or nothing.
    property string opened: ""

    function toggleLayer(key: string): void {
        root.opened = root.opened === key ? "" : key;
    }

    // WHAT THE LAST CODE CAME TO, and "" while the camera is still looking. It
    // is shown under the picture rather than on the row, because the row says
    // what the row does and this is about a thing that just happened.
    property string said: ""

    // Cleared with the camera. A refusal is about the code you just held up, and
    // holding up the next one starts again.
    onOpenedChanged: if (root.opened !== "code")
        root.said = ""

    // WHETHER THE CARD IS ACTUALLY IN FRONT OF SOMEBODY, which is a stricter
    // question than whether its layer is open: a menu built and waiting to be
    // pointed at has `showing` false, and an unread card would still be holding
    // the passphrase.
    //
    // Derived rather than set from the two handlers that could each imply it,
    // because both of them fire and the answer must not depend on which fired
    // last. This is the only thing that switches the secret on and off.
    readonly property bool showingCard: root.showing && root.opened === "share"

    onShowingCardChanged: Network.share(root.showingCard)

    // A CODE, ACTED ON. Joining is an answer, so the camera goes away and takes
    // the layer with it: the list underneath is where the result of a join is
    // legible, and leaving a lens open over it would be the shell carrying on
    // scanning for a network it had already joined. Anything else is a sentence
    // and the camera stays up, because every reason this can fail is one you fix
    // by pointing it at something else.
    function tookCode(text: string): void {
        const trouble = Network.joinQr(text);
        if (trouble) {
            root.said = trouble;
            return;
        }
        root.opened = "";
    }

    spacing: Appearance.padding.small

    // THE LIST HOLDS STILL WHILE YOU ARE USING IT, and the radio does not stop.
    //
    // `networks` is rebuilt by every scan result, and a Repeater over a plain
    // array rebuilds every delegate whenever that array changes identity. So the
    // password field was destroyed mid-word every couple of seconds along with
    // its focus, any open layer restarted its unroll, and rows moved out from
    // under the cursor between aiming and clicking.
    //
    // The first fix was to stop scanning while a prompt was open, and it is the
    // wrong one twice over. NetworkManager ages out access points it has stopped
    // hearing, so a paused scan does not freeze the list, it slowly empties it,
    // taking with it the very row whose password was being typed. And it left
    // the panel announcing that scanning was off because you had opened the
    // panel containing the scanning switch.
    //
    // So the radio keeps scanning and the VIEW freezes: while something is open,
    // `rows` hands back the same array by reference, which is the only thing a
    // Repeater treats as "nothing happened".
    //
    // THE RADIO IS NO LONGER THIS MENU'S TO SWITCH, either. It was, and the
    // switch cost a second and a half of frozen shell each way; Network's own
    // note has the measurements. It is a session-long preference now, so this
    // file only shows it.
    readonly property bool busy: !!root.asking || !!root.opened

    property var frozen: []

    readonly property var rows: root.busy ? root.frozen : Network.enabled ? Network.networks.slice(0, Appearance.sizes.networkListMax) : []

    // THE NOTICES FREEZE TOO, and for the same reason, which is easy to miss
    // because they are not part of the list.
    //
    // They sit ABOVE it, and `visible` on a child of a Column is a layout change
    // rather than a repaint: one of them appearing or vanishing moves every row
    // below it, password field included. And the state they read is not idle
    // while you are typing. Joined-and-going-nowhere is exactly the state that
    // rechecks every eight seconds, so the moment it changes its mind is a
    // moment the field under your cursor jumps a row.
    property bool frozenStranded: false
    property bool frozenCaptive: false

    readonly property bool stranded: root.busy ? root.frozenStranded : Network.stranded
    readonly property bool captive: root.busy ? root.frozenCaptive : Network.captive

    onBusyChanged: if (root.busy) {
        root.frozen = root.rows;
        root.frozenStranded = Network.stranded;
        root.frozenCaptive = Network.captive;
    }

    // Put away on the way out, so what comes back is the menu rather than the
    // half-typed password and the unrolled layer you walked away from. It also
    // gives the keyboard back: PasswordField's claim is released when the field
    // stops being visible, and nothing else would make it stop.
    onShowingChanged: if (!root.showing) {
        root.asking = "";
        root.opened = "";
    }

    // One switch inside a layer, and one thing that happens. Same pair as the
    // bluetooth menu: a toggle on the right for a state, an arrow for an act, so
    // the right edge stays a column and "set this" and "do this" are told apart
    // before either is read.
    component Choice: MenuRow {
        id: choice

        property bool on: false

        signal flipped

        onActivated: choice.flipped()

        Toggle {
            checked: choice.on
            onToggled: choice.flipped()
        }
    }

    // NO ARROW. A chevron pointing right means "there is more through here", and
    // it was sitting on "Disconnect", which does not lead anywhere: it is the
    // whole action, over the moment you press it. Every act in this menu wore
    // one, so the layer read as a list of submenus that turned out to be
    // buttons.
    //
    // What tells an act from a switch is now the absence of the switch. The
    // right edge stays a column, the toggles are the only things in it, and a
    // row with nothing there is a row that does something. The hover fill and
    // the pointer cursor say it is pressable; the verb says what it does.
    component Act: MenuRow {}

    component Fact: StyledText {
        leftPadding: Appearance.padding.normal
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    // SAYING IT, rather than having said it somewhere.
    //
    // "sign in required" already existed, in the row's detail line, in the faint
    // tier, in the same slot that reads "wpa2, saved" on every other row. That
    // slot describes a network; this is the reason nothing works, and setting it
    // in the type reserved for what you do not need to read is how a shell tells
    // you something without telling you.
    //
    // Worse, the sentence had no end. The shell knew a login page was waiting
    // and offered no way to open one, so being informed meant going to find a
    // browser and something to type into it, which is the work the message was
    // supposed to save. A notice that names a problem it cannot act on is only a
    // more articulate silence.
    //
    // So: its own line, the label size, and the shell's one accent, which
    // Appearance reserves for state genuinely worth a colour and which nothing
    // else in this menu spends. Pressing it does the thing.
    component Notice: Item {
        id: notice

        property string icon: ""
        property string label: ""
        property string detail: ""
        property string action: ""

        signal activated

        implicitWidth: parent ? parent.width : 0
        implicitHeight: line.implicitHeight

        // The same radius as the row sitting on it, or the accent tint would
        // show a second, squarer corner just inside the fill's.
        G2Rect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.accentFill
        }

        MenuRow {
            id: line

            label: notice.label
            detail: notice.detail
            onActivated: notice.activated()

            // Through `mark` rather than `icon`, because the glyph has to be the
            // accent and MenuRow's own one is a label tier by definition.
            mark: Component {
                Icon {
                    name: notice.icon
                    size: line.iconSize
                    color: Appearance.colour.accent
                }
            }

            // Unanchored, like every other trailing glyph in this menu. The slot
            // sizes itself from its children, so a child that centres itself on
            // the slot is asking the slot how tall it is in order to say how
            // tall the slot is.
            Icon {
                name: notice.action
                color: Appearance.colour.accent
            }
        }
    }

    MenuRow {
        width: root.width
        icon: Network.icon()
        label: "Wi-Fi"
        // The name AND what it is worth. This used to hand the whole line over
        // to the reach label, so the moment there was something wrong the row
        // stopped saying which network it was wrong about.
        detail: !Network.available ? "no adapter" : !Network.hardwareEnabled ? "blocked by hardware switch" : !Network.enabled ? "off" : !Network.connected ? "not connected" : Network.reachLabel() ? `${Network.activeName} · ${Network.reachLabel()}` : Network.activeName
        interactive: Network.available && Network.hardwareEnabled
        onActivated: Network.setEnabled(!Network.enabled)
        tip: Network.enabled ? "turn off" : "turn on"

        Row {
            spacing: Appearance.padding.normal

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Network.enabled
                onToggled: Network.setEnabled(!Network.enabled)
            }

            Expander {
                anchors.verticalCenter: parent.verticalCenter

                visible: Network.available
                open: root.opened === "adapter"
                tip: "adapter settings"
                onToggled: root.toggleLayer("adapter")
            }
        }
    }

    MenuLayer {
        width: root.width
        open: root.opened === "adapter"

        // THE ONE SWITCH IN THIS SHELL THAT COSTS SOMETHING TO FLIP, and it says
        // so. Off, NetworkManager reports only the network you are on, so this
        // is not "stop refreshing", it is "stop having a list"; and the flip
        // itself pauses the shell for a moment, because the write waits on the
        // radio. Both facts belong on the row rather than in a file: a control
        // that hangs for a second without warning reads as broken, and one that
        // empties a list you were reading reads as a bug.
        Choice {
            label: "Keep the list fresh"
            detail: Network.wantScanning ? "" : "only the network you are on"
            on: Network.scanning
            tip: "pauses for a moment"
            onFlipped: Network.setScanning(!Network.wantScanning)
        }

        Choice {
            label: "Join on its own"
            detail: Network.autoconnect ? "" : "waits to be told"
            on: Network.autoconnect
            onFlipped: Network.setAutoconnect(!Network.autoconnect)
        }

        // Joined and working are different questions, and only this one asks the
        // second. Off, NetworkManager guesses; on, it actually fetches something
        // every minute and can tell a captive portal from the real internet.
        Choice {
            visible: Network.canCheck
            label: "Check for internet"
            detail: Network.checking ? "" : "otherwise it guesses"
            on: Network.checking
            onFlipped: Network.setChecking(!Network.checking)
        }

        Act {
            visible: Network.canCheck && Network.checking
            label: "Check now"
            tip: "test internet"
            onActivated: Network.checkNow()
        }

        // The switch that turns the adapter back over to whatever else wants it.
        // Last, and named for what it does rather than for `nmManaged`, because
        // turning it off drops the connection and hands the radio to nobody.
        Choice {
            label: "Managed by the system"
            detail: Network.managed ? "" : "nothing is driving it"
            on: Network.managed
            onFlipped: Network.setManaged(!Network.managed)
        }

        Fact {
            text: Network.deviceName ? `${Network.deviceName} · ${Network.address}` : Network.address
        }
    }

    // Joined and going nowhere, which is the state this menu exists to catch and
    // the one it used to be quietest about. Two of them, because they are two
    // different problems with two different next moves: a portal is a door you
    // can open from here, and a dead uplink is not.
    Notice {
        width: root.width
        // Both off Network.stranded, by way of the freeze above: it is the same
        // property the status bar raises its alert from, and the bar saying
        // something is wrong is what sends you in here to find out what. If the
        // two could disagree, following the alert into the menu would find
        // nothing waiting.
        visible: root.stranded && root.captive
        icon: "captive_portal"
        label: "Sign in to use this network"
        detail: "it wants a login page before it lets anything through"
        action: "open_in_new"
        onActivated: Network.openPortal()
    }

    Notice {
        width: root.width
        visible: root.stranded && !root.captive
        icon: "cloud_off"
        label: "No internet on this network"
        detail: "joined, but nothing answers on the other side"
        action: "refresh"
        onActivated: Network.checkNow()
    }

    // THE OTHER WAY TO JOIN A NETWORK, which is the one printed on the back of
    // the router and stuck to the wall of the cafe.
    //
    // A wifi password is the worst string anybody is ever asked to retype: it is
    // long, it is deliberately unmemorable, it is usually on a label facing the
    // wrong way, and it is entered into a field that shows dots. The square of
    // dots beside it carries the same string exactly, and reading it is the one
    // job a camera can do better than a person.
    //
    // ABOVE THE LIST rather than at the end of it. It is a way of joining, so it
    // belongs with the header block that says what the radio is doing, not
    // trailing a list that is capped and may have scrolled away from it.
    //
    // WHAT IT CANNOT DO is written down in Network.joinQr and shown in the line
    // under the camera: a card names an SSID, and everything this shell can do
    // with a network it cannot currently hear is nothing, for the reason at the
    // top of this file.
    MenuRow {
        width: root.width
        visible: Network.enabled
        icon: "qr_code_scanner"
        label: "Join from a code"
        detail: "with the camera"
        onActivated: root.toggleLayer("code")
        tip: root.opened === "code" ? "close the camera" : "open the camera"

        // Unanchored, like every other lone trailing control in this menu: the
        // slot sizes itself from its children, so a child that centres itself on
        // the slot is asking the slot how tall it is in order to answer how tall
        // the slot is. See the Notice component above.
        Expander {
            open: root.opened === "code"
            tip: "camera"
            onToggled: root.toggleLayer("code")
        }
    }

    MenuLayer {
        width: root.width
        open: root.opened === "code"

        // BUILT WITH THE LAYER AND THROWN AWAY WITH IT, which is the opposite of
        // what the menu around it now does (see `showing`) and is right for the
        // same reason: what a warm menu buys is a hover that costs nothing, and
        // nobody hovers a camera. Loading it opens the QtMultimedia plugin and
        // enumerates the video devices, and the lens is a piece of hardware with
        // a light next to it. None of that should exist because a menu does.
        Loader {
            width: parent.width

            active: root.showing && root.opened === "code"

            sourceComponent: QrScanner {
                active: true
                note: root.said

                onDecoded: text => root.tookCode(text)
            }
        }
    }

    // THE SAME SQUARE, THE OTHER WAY ROUND.
    //
    // Directly under the camera, because the two are one pair and the pair is
    // the point: a code is how a network is handed over, and a shell that can
    // only read one is half a conversation. This is the answer to being asked
    // "what's the wifi" in your own kitchen, which is a question nobody has ever
    // enjoyed answering out loud.
    //
    // ONLY WHILE YOU ARE ON SOMETHING. There is no card for a network you have
    // not joined: the shell would have to know a passphrase it has never been
    // told. The row is absent rather than dead, because "share the network you
    // are not on" is not a thing that can be explained by greying it out.
    MenuRow {
        width: root.width
        visible: Network.enabled && Network.connected
        icon: "qr_code_2"
        label: "Show the code"
        detail: "for their camera"
        onActivated: root.toggleLayer("share")
        tip: root.opened === "share" ? "put it away" : "show the code"

        Expander {
            open: root.opened === "share"
            tip: "the code"
            onToggled: root.toggleLayer("share")
        }
    }

    MenuLayer {
        width: root.width
        open: root.opened === "share"

        // BUILT WITH THE LAYER AND THROWN AWAY WITH IT, like the camera above
        // and for a sharper reason: what this holds is the passphrase. See
        // Network's note on `sharing`; the secret is fetched when the card goes
        // up and dropped the moment it comes down, and `showingCard` above is
        // the one place that is decided.
        Loader {
            width: parent.width

            active: root.showingCard

            sourceComponent: Column {
                width: parent.width
                spacing: Appearance.padding.small

                QrCode {
                    id: card

                    width: parent.width
                    text: Network.card
                    // The network's own name on the card, because a phone that
                    // has scanned it says nothing back and the person holding
                    // the laptop should be able to see they offered the right
                    // one.
                    caption: Network.activeName
                }

                // THE SAME LINE THE SCANNER HAS, in the same place, saying the
                // same three kinds of thing: what is wrong with the writer, what
                // is wrong with the network, or what to do next.
                StyledText {
                    width: parent.width
                    leftPadding: Appearance.padding.normal
                    text: card.trouble || Network.cardTrouble || (Network.card ? "hold it up to a phone" : "reading the passphrase")
                    color: card.trouble || Network.cardTrouble ? Appearance.colour.accent : Appearance.colour.textFaint
                    font.pixelSize: Appearance.font.size.small
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    Separator {
        width: parent.width
        visible: Network.enabled
    }

    // The list. Capped, because a flat is a dozen networks and a street is
    // eighty, and a menu that scrolls forever is worse than one that says how
    // many it left out.
    Repeater {
        model: root.rows

        delegate: Column {
            id: entry

            required property var modelData

            readonly property bool showing: root.opened === entry.modelData.name

            width: root.width
            spacing: 0

            MenuRow {
                width: parent.width
                // No icon: the meter on the right says everything an icon would,
                // and says it comparably down the column.
                label: entry.modelData.name
                detail: Network.stateLabel(entry.modelData)
                selected: entry.modelData.connected

                onActivated: {
                    const n = entry.modelData;
                    if (n.connected)
                        return n.disconnect();
                    // Known networks already have the secret, and an open one
                    // never needed one. Only a stranger with a lock has to be
                    // asked, and an enterprise network cannot be joined with an
                    // answer to that question at all.
                    if (n.known || !Network.secured(n) || Network.enterprise(n))
                        return n.connect();
                    root.asking = root.asking === n.name ? "" : n.name;
                }

                // What pressing the ROW does, which is not what the row says.
                // The label is the network's name and the detail is its state;
                // neither of them is "and this is the button that joins it".
                tip: entry.modelData.connected ? "disconnect" : entry.modelData.known || !Network.secured(entry.modelData) ? "join" : Network.enterprise(entry.modelData) ? "needs profile" : "needs password"

                Row {
                    spacing: Appearance.padding.normal

                    SignalBars {
                        anchors.verticalCenter: parent.verticalCenter
                        strength: Network.percent(entry.modelData)
                        activeColour: entry.modelData.connected ? Appearance.colour.text : Appearance.colour.textDim

                        // The meter is four bars and a percentage is a number.
                        // Reading one off the other is the guess this saves.
                        HoverTip {
                            text: `${Network.percent(entry.modelData)}%`
                        }
                    }

                    Expander {
                        anchors.verticalCenter: parent.verticalCenter

                        open: entry.showing
                        tip: "more"
                        onToggled: root.toggleLayer(entry.modelData.name)
                    }
                }
            }

            PasswordField {
                width: parent.width
                visible: root.asking === entry.modelData.name
                placeholder: `password for ${entry.modelData.name}`

                onAccepted: secret => {
                    Network.clearFailure(entry.modelData.name);
                    entry.modelData.connectWithPsk(secret);
                    root.asking = "";
                }
                onCancelled: root.asking = ""
            }

            MenuLayer {
                width: parent.width
                open: entry.showing

                Act {
                    visible: entry.modelData.connected
                    label: "Disconnect"
                    tip: "keeps password"
                    onActivated: entry.modelData.disconnect()
                }

                // Forgetting is the only cure for a saved network whose password
                // has changed: it will keep failing with the secret it has, and
                // nothing else in this menu can take that secret away.
                Act {
                    visible: entry.modelData.known
                    label: "Forget it"
                    tip: "drops password"
                    onActivated: {
                        root.opened = "";
                        Network.forget(entry.modelData);
                    }
                }

                Fact {
                    text: `${Network.securityLabel(entry.modelData)} · ${Network.percent(entry.modelData)}%${entry.modelData.known ? " · saved" : ""}`
                }
            }
        }
    }

    StyledText {
        visible: Network.enabled && Network.networks.length > Appearance.sizes.networkListMax
        leftPadding: Appearance.padding.normal
        text: `+${Network.networks.length - Appearance.sizes.networkListMax} more`
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    StyledText {
        visible: Network.enabled && !Network.networks.length
        leftPadding: Appearance.padding.normal
        text: Network.scanning ? "scanning" : "nothing found"
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
