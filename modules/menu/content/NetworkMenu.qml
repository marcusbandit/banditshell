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

    // A secured network you have never joined needs a password, and the place to
    // ask is the row you just pressed. Only one row can be asking at a time.
    property string asking: ""

    // Which layer is unrolled: a network name, "adapter", or nothing.
    property string opened: ""

    function toggleLayer(key: string): void {
        root.opened = root.opened === key ? "" : key;
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
    property bool wantScan: true

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

    onWantScanChanged: Network.watch(root.wantScan)
    Component.onCompleted: Network.watch(root.wantScan)
    Component.onDestruction: Network.watch(false)

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

        Choice {
            label: "Keep the list fresh"
            detail: root.wantScan ? "" : "the list is whatever it last saw"
            on: root.wantScan
            onFlipped: root.wantScan = !root.wantScan
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
