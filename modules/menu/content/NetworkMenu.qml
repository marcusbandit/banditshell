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

    // THE LIST HOLDS STILL WHILE YOU ARE USING IT.
    //
    // `networks` is derived from every AP's signal strength, so each scan result
    // re-evaluates it and a Repeater over a plain array rebuilds every delegate.
    // That destroyed the password field mid-word every couple of seconds along
    // with its focus, restarted the unroll of any open layer, and moved the row
    // under the cursor out from under it between aiming and clicking. Freshness
    // is worth nothing while someone is answering a prompt or reading a panel.
    //
    // The switch below is therefore INTENT, not the radio: it says whether this
    // menu wants a fresh list, and stays where you put it while a layer is open.
    // Reporting the device's own state there instead would have the panel
    // announce that scanning was off because you opened the panel containing the
    // scanning switch.
    property bool wantScan: true

    readonly property bool busy: !!root.asking || !!root.opened

    function applyScan(): void {
        Network.watch(root.wantScan && !root.busy);
    }

    onWantScanChanged: root.applyScan()
    onBusyChanged: root.applyScan()
    Component.onCompleted: root.applyScan()
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

    component Act: MenuRow {
        Icon {
            name: "chevron_right"
            color: Appearance.colour.textFaint
        }
    }

    component Fact: StyledText {
        leftPadding: Appearance.padding.normal
        topPadding: Appearance.padding.small
        bottomPadding: Appearance.padding.normal
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }

    MenuRow {
        width: root.width
        icon: Network.icon()
        label: "Wi-Fi"
        detail: !Network.available ? "no adapter" : !Network.hardwareEnabled ? "blocked by hardware switch" : !Network.enabled ? "off" : Network.connected ? Network.reachLabel() || Network.activeName : "not connected"
        interactive: Network.available && Network.hardwareEnabled
        onActivated: Network.setEnabled(!Network.enabled)

        Row {
            spacing: Appearance.padding.normal

            Toggle {
                anchors.verticalCenter: parent.verticalCenter
                checked: Network.enabled
                onToggled: Network.setEnabled(!Network.enabled)
            }

            Icon {
                anchors.verticalCenter: parent.verticalCenter

                visible: Network.available
                name: "expand_more"
                color: root.opened === "adapter" ? Appearance.colour.text : Appearance.colour.textFaint
                rotation: root.opened === "adapter" ? 180 : 0

                Behavior on rotation {
                    NumberAnimation {
                        duration: Appearance.anim.fast
                        easing.type: Easing.OutBack
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -Appearance.padding.small
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleLayer("adapter")
                }
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

    Separator {
        width: parent.width
        visible: Network.enabled
    }

    // The list. Capped, because a flat is a dozen networks and a street is
    // eighty, and a menu that scrolls forever is worse than one that says how
    // many it left out.
    Repeater {
        model: Network.enabled ? Network.networks.slice(0, Appearance.sizes.networkListMax) : []

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

                Row {
                    spacing: Appearance.padding.normal

                    SignalBars {
                        anchors.verticalCenter: parent.verticalCenter
                        strength: Network.percent(entry.modelData)
                        activeColour: entry.modelData.connected ? Appearance.colour.text : Appearance.colour.textDim
                    }

                    Icon {
                        anchors.verticalCenter: parent.verticalCenter

                        name: "expand_more"
                        color: entry.showing ? Appearance.colour.text : Appearance.colour.textFaint
                        rotation: entry.showing ? 180 : 0

                        Behavior on rotation {
                            NumberAnimation {
                                duration: Appearance.anim.fast
                                easing.type: Easing.OutBack
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Appearance.padding.small
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.toggleLayer(entry.modelData.name)
                        }
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
                    onActivated: entry.modelData.disconnect()
                }

                // Forgetting is the only cure for a saved network whose password
                // has changed: it will keep failing with the secret it has, and
                // nothing else in this menu can take that secret away.
                Act {
                    visible: entry.modelData.known
                    label: "Forget it"
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
