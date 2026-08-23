pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// The network. Both of them, when the machine has both.
//
// The wire leads, because on a machine that has one it is almost always what
// the traffic is on: NetworkManager gives it the lower metric, so an associated
// radio beside a live cable is a spare. The radio used to be the whole of this
// menu, which meant a cabled desktop opened it and read "not connected" about
// the one device that was not carrying anything, with nothing on screen about
// the one that was. A row it never occurred to the shell to draw is worse than
// a wrong one: there is nothing to correct.
//
// EACH ROW IS ONLY ABOUT ITSELF. There is exactly one connectivity answer for
// the machine and two rows it could be written on, so it goes on the carrier's
// row and nowhere else (Network.reachFor): "no internet" beside an idle radio
// names the wrong suspect.
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

    // TWO OF THEM TAKE THE MENU OVER rather than unrolling inside it.
    //
    // A layer is the right shape for a page of switches: it belongs to the row
    // above it, so it pushes the rows below it down and the menu grows. A camera
    // and a card are not that. They are one object each, as wide as the menu and
    // as tall as a third of it, and letting either push a list of networks
    // downward moved every row on screen and shunted the whole panel upward,
    // because a menu is centred on the icon that opened it and half of any
    // growth comes off the top.
    //
    // So the list does not move: it is dimmed out and the object is drawn over
    // the space it was using. Nothing above shifts, nothing below survives, and
    // the panel's height does not change at all. See `body` at the bottom.
    readonly property bool takeover: root.opened === "code" || root.opened === "share"

    // WHICH FACE THE CARD IS SHOWING, kept on the menu rather than on the card,
    // so it survives the card being built and thrown away with its layer. A
    // preference you set by pressing the thing is a preference you should only
    // have to set once.
    property bool colourful: true

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

    // A BUTTON THAT IS ONLY A GLYPH, and says what it is on hover.
    //
    // Built like Expander, for Expander's reason: a round target of its own,
    // which takes the hover away from whatever it sits in, so the boundary
    // between two controls is visible before either one is pressed. What it does
    // NOT have is a label, and that is the point. "Join from a code, with the
    // camera" was two lines and a full row of a four-hundred-pixel menu spent
    // saying something you read once and then recognise by its mark forever.
    //
    // ON IS FILLED, which is the icon set's own way of saying so: Material
    // Symbols treats FILL as a state axis, so the same mark solid is the same
    // mark switched on, and the menu does not need a second colour for it.
    component Tool: Item {
        id: tool

        property string icon: ""
        property bool on: false
        property string tip: ""

        signal activated

        readonly property bool hovered: press.containsMouse

        implicitWidth: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
        implicitHeight: implicitWidth

        G2Rect {
            anchors.fill: parent
            radius: height / 2
            color: tool.on ? Appearance.colour.accentFill : Appearance.colour.fill
            opacity: tool.on || tool.hovered ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Icon {
            anchors.centerIn: parent

            name: tool.icon
            fill: tool.on ? 1 : 0
            color: tool.on ? Appearance.colour.accent : tool.hovered ? Appearance.colour.text : Appearance.colour.textFaint

            Behavior on fill {
                NumberAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        MouseArea {
            id: press

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tool.activated()
        }

        // ASKED THROUGH THE MOUSEAREA above, not through the handler's own
        // hover. See HoverTip: a MouseArea filling its own item takes the hover
        // event before the item's handlers are reached, so on a control like
        // this one the handler is deaf in both directions.
        HoverTip {
            text: tool.tip
            asked: tool.hovered
        }
    }

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

    // THE TWO WAYS A NETWORK IS HANDED OVER, as marks, in the top right.
    //
    // They are the same object pointed in opposite directions: the camera reads
    // a card, the card is one to read, and neither is a setting or a network.
    // Sitting in the list as full rows they read as two more things to join, and
    // they were the two widest sentences in a menu whose actual job is names.
    //
    // Right-aligned and above everything, because a toolbar is where you look
    // for a verb and the rest of this menu is nouns.
    // Wrapped, because a Column owns its children's vertical placement and an
    // anchor is how a child argues with that. The wrapper takes the row's
    // height and the anchor stays inside it, where it is only about x.
    Item {
        width: root.width
        implicitHeight: tools.implicitHeight

        Row {
            id: tools

            anchors.right: parent.right
            anchors.rightMargin: Appearance.padding.small

            spacing: Appearance.padding.small

            Tool {
                visible: Network.enabled
                icon: "qr_code_scanner"
                on: root.opened === "code"
                tip: root.opened === "code" ? "close the camera" : "scan a code"
                onActivated: root.toggleLayer("code")
            }

            Tool {
                visible: Network.enabled && Network.connected
                icon: "qr_code_2"
                on: root.opened === "share"
                tip: root.opened === "share" ? "put it away" : "share"
                onActivated: root.toggleLayer("share")
            }
        }
    }

    // THE WIRE, AND ONLY WHILE THERE IS ONE.
    //
    // Not "this machine has a port": a laptop has a port it has not seen a
    // cable in since it was bought, and a permanent "Ethernet / not connected"
    // over the network you are actually on is the same dead weight the battery
    // gauge was on a desktop. So the row appears when the wire is DOING
    // something and is otherwise not there at all, which on a laptop means the
    // menu is the Wi-Fi menu it always was, and on a desk means the wire is at
    // the top where it belongs.
    //
    // The third case is the one that stops this being a trap. Turning off
    // "Managed by the system" below drops the link, and a row that vanished on
    // the way out would take the switch back with it: the setting would be
    // unreachable by the exact act of using it. So a port that is down BECAUSE
    // OF SOMETHING IN HERE stays on screen. A port that is down because there
    // is no cable in it does not, and there is nothing in this menu that could
    // have caused that.
    //
    // NO SWITCH ON THIS ROW, for the same reason and one more. A toggle that
    // disconnects would hide the row it lives on, which is the trap again with
    // one fewer step; and a hover menu is the wrong place to put a
    // four-hundred-pixel target that drops the link the machine is on. What a
    // wire needs said about it is a fact, and this row says it.
    MenuRow {
        width: root.width
        visible: Network.wiredShowing
        icon: "lan"
        label: "Ethernet"
        // The port, then what the port is worth. Same shape as the Wi-Fi line
        // below it, so the two read as one question asked twice.
        detail: !Network.wiredManaged ? "nothing is driving it" : Network.wiredConnecting ? "connecting" : Network.reachFor("wired") ? `${Network.wiredLabel} · ${Network.reachFor("wired")}` : Network.wiredLabel
        interactive: false

        Expander {
            open: root.opened === "wire"
            tip: "port settings"
            onToggled: root.toggleLayer("wire")
        }
    }

    MenuLayer {
        width: root.width
        visible: Network.wiredShowing
        open: root.opened === "wire"

        // The wire's half of the adapter layer under Wi-Fi. There is no
        // scanning to keep fresh and no radio to hand back, so what is left is
        // the two questions a port can answer: does it come up on its own, and
        // is NetworkManager driving it at all.
        Choice {
            icon: "autorenew"
            label: "Join on its own"
            detail: Network.wiredAutoconnect ? "" : "waits to be told"
            on: Network.wiredAutoconnect
            onFlipped: Network.setWiredAutoconnect(!Network.wiredAutoconnect)
        }

        Choice {
            icon: "cable"
            label: "Managed by the system"
            detail: Network.wiredManaged ? "" : "nothing is driving it"
            on: Network.wiredManaged
            onFlipped: Network.setWiredManaged(!Network.wiredManaged)
        }

        Fact {
            text: Network.wiredDeviceName ? `${Network.wiredDeviceName} · ${Network.wiredAddress}` : Network.wiredAddress
        }
    }

    MenuRow {
        width: root.width
        icon: Network.wifiIcon()
        label: "Wi-Fi"
        // The name AND what it is worth. This used to hand the whole line over
        // to the reach label, so the moment there was something wrong the row
        // stopped saying which network it was wrong about.
        detail: !Network.available ? "no adapter" : !Network.hardwareEnabled ? "blocked by hardware switch" : !Network.enabled ? "off" : !Network.connected ? "not connected" : Network.reachFor("wifi") ? `${Network.activeName} · ${Network.reachFor("wifi")}` : Network.activeName
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
            icon: "radar"
            label: "Keep the list fresh"
            detail: Network.wantScanning ? "" : "only the network you are on"
            on: Network.scanning
            tip: "pauses for a moment"
            onFlipped: Network.setScanning(!Network.wantScanning)
        }

        Choice {
            icon: "autorenew"
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
            icon: "public"
            label: "Check for internet"
            detail: Network.checking ? "" : "otherwise it guesses"
            on: Network.checking
            onFlipped: Network.setChecking(!Network.checking)
        }

        Act {
            visible: Network.canCheck && Network.checking
            icon: "refresh"
            label: "Check now"
            tip: "test internet"
            onActivated: Network.checkNow()
        }

        // The switch that turns the adapter back over to whatever else wants it.
        // Last, and named for what it does rather than for `nmManaged`, because
        // turning it off drops the connection and hands the radio to nobody.
        Choice {
            icon: "cable"
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

    Separator {
        width: parent.width
        visible: Network.enabled
    }

    // WHERE THE MENU IS TAKEN OVER.
    //
    // Everything from here down is the list, and everything from here down is
    // what a camera or a card covers. The height is the LIST'S height whether
    // one is open or not, and that single line is the whole of "it stays put":
    // the panel is centred on the icon that opened it, so any growth here would
    // have come half off the top and shunted every row on screen upward, on the
    // way IN and again on the way out.
    //
    // The list is dimmed rather than hidden, and that is not a shortcut: a
    // hidden child leaves a Column and takes its height with it, which is
    // exactly the movement being avoided. It keeps its place, loses its ink and
    // its input, and the object is drawn over the space it was using.
    //
    // The one case that still grows is a card taller than the list it is
    // covering, which means a street with two networks in it. The card is given
    // the list's height as a ceiling and shrinks into it first; past the point
    // where shrinking would make the code too small to scan, growing the menu is
    // the honest answer.
    Item {
        id: body

        width: root.width
        implicitHeight: root.takeover ? Math.max(list.implicitHeight, media.implicitHeight) : list.implicitHeight

        Column {
            id: list

            width: parent.width

            opacity: root.takeover ? 0 : 1
            // `enabled` is inherited, so this is the whole of "and it cannot be
            // clicked through either". A dimmed row is still a row to a cursor.
            enabled: !root.takeover

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

            // The list. Capped, because a flat is a dozen networks and a street
            // is eighty, and a menu that scrolls forever is worse than one that
            // says how many it left out.
            Repeater {
                model: root.rows

                delegate: Column {
                    id: entry

                    required property var modelData

                    readonly property bool showing: root.opened === entry.modelData.name

                    width: list.width
                    spacing: 0

                    MenuRow {
                        width: parent.width
                        // No icon: the meter on the right says everything an
                        // icon would, and says it comparably down the column.
                        label: entry.modelData.name
                        detail: Network.stateLabel(entry.modelData)
                        selected: entry.modelData.connected

                        onActivated: {
                            const n = entry.modelData;
                            if (n.connected)
                                return n.disconnect();
                            // Known networks already have the secret, and an
                            // open one never needed one. Only a stranger with a
                            // lock has to be asked, and an enterprise network
                            // cannot be joined with an answer to that question
                            // at all.
                            if (n.known || !Network.secured(n) || Network.enterprise(n))
                                return n.connect();
                            root.asking = root.asking === n.name ? "" : n.name;
                        }

                        // What pressing the ROW does, which is not what the row
                        // says. The label is the network's name and the detail
                        // is its state; neither of them is "and this is the
                        // button that joins it".
                        tip: entry.modelData.connected ? "disconnect" : entry.modelData.known || !Network.secured(entry.modelData) ? "join" : Network.enterprise(entry.modelData) ? "needs profile" : "needs password"

                        Row {
                            spacing: Appearance.padding.normal

                            // A LOCK, WHERE THE WORD "WPA2" WAS.
                            //
                            // The state line under a name used to read "wpa2",
                            // or "wpa2, saved", down eight rows: a column of the
                            // same acronym, which nobody chooses a network by
                            // and which is only ever asking one question, "will
                            // this want a password". A mark answers that at a
                            // glance and gives the line back to the states that
                            // are actually different from each other.
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter

                                visible: Network.secured(entry.modelData)
                                // A key for one we already hold, a lock for one
                                // that is going to ask.
                                name: entry.modelData.known ? "key" : "lock"
                                color: Appearance.colour.textFaint

                                HoverTip {
                                    text: entry.modelData.known ? `${Network.securityLabel(entry.modelData)}, saved` : Network.securityLabel(entry.modelData)
                                }
                            }

                            SignalBars {
                                anchors.verticalCenter: parent.verticalCenter
                                strength: Network.percent(entry.modelData)
                                activeColour: entry.modelData.connected ? Appearance.colour.text : Appearance.colour.textDim

                                // The meter is four bars and a percentage is a
                                // number. Reading one off the other is the guess
                                // this saves.
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
                            icon: "link_off"
                            label: "Disconnect"
                            tip: "keeps password"
                            onActivated: entry.modelData.disconnect()
                        }

                        // Forgetting is the only cure for a saved network whose
                        // password has changed: it will keep failing with the
                        // secret it has, and nothing else in this menu can take
                        // that secret away.
                        Act {
                            visible: entry.modelData.known
                            icon: "delete"
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

        // WHAT COVERS IT. One of these at a time, both built with their opening
        // and thrown away with it, which is the opposite of what the menu around
        // them does (see `showing`) and right for the same reason: what a warm
        // menu buys is a hover that costs nothing, and nobody hovers a camera.
        //
        // Loading the scanner opens the QtMultimedia plugin and enumerates the
        // video devices, and the lens is a piece of hardware with a light next
        // to it. Loading the card fetches a passphrase. Neither should happen
        // because a menu exists.
        // A LOADER THAT IS NOT LOADING IS NOT ZERO HIGH, which is the whole of
        // "scan, then share, and the menu comes apart".
        //
        // Qt sizes a Loader from its item and then, on the way out, leaves that
        // size exactly where it was: the size update returns early when there
        // is no item to measure, so an inactive Loader goes on claiming the
        // height of the thing it just destroyed. Going from the camera straight
        // to the card left the camera's three hundred pixels standing in this
        // Column with nothing in them, the card sat underneath the hole, and
        // the menu was that much taller than anything it contained.
        //
        // `visible` is the fix rather than a height override, because a
        // positioner skips a child that is not visible ENTIRELY, spacing and
        // all, and a stale height cannot be believed if nothing is asking.
        Column {
            id: media

            width: parent.width
            spacing: Appearance.padding.small

            Loader {
                id: lens

                width: parent.width

                active: root.showing && root.opened === "code"
                visible: lens.active

                sourceComponent: QrScanner {
                    active: true
                    note: root.said

                    onDecoded: text => root.tookCode(text)
                }
            }

            Loader {
                id: sheet

                width: parent.width

                active: root.showingCard
                visible: sheet.active

                sourceComponent: Column {
                    width: sheet.width
                    spacing: Appearance.padding.small

                    QrCode {
                        id: card

                        width: parent.width
                        // The list's height, less whatever the line below is
                        // using. Reading the LIST rather than the space left in
                        // `body` is what keeps this out of a loop: body's height
                        // is partly this card's.
                        maxHeight: Math.max(0, list.implicitHeight - (note.visible ? note.implicitHeight + parent.spacing : 0))

                        text: Network.card
                        // The network's name, and the passphrase under it. The
                        // code carries both already; this is the same card read
                        // by a person instead of a camera, for the laptop across
                        // the table with no lens pointed this way.
                        caption: Network.activeName
                        detail: Network.secret

                        colourful: root.colourful
                        flippable: true
                        tip: root.colourful ? "ink on paper" : "in colour"
                        onFlipped: root.colourful = !root.colourful
                    }

                    // ONLY WHEN THERE IS SOMETHING TO SAY. What is wrong with
                    // the writer, what is wrong with the network, or that the
                    // passphrase has not arrived yet. A working card explains
                    // itself by being one.
                    StyledText {
                        id: note

                        width: parent.width
                        leftPadding: Appearance.padding.normal

                        visible: !!text
                        text: card.trouble || Network.cardTrouble || (Network.card ? "" : "reading the passphrase")
                        color: card.trouble || Network.cardTrouble ? Appearance.colour.accent : Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
