pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property bool showing: false

    property string asking: ""

    property string opened: ""

    function toggleLayer(key: string): void {
        root.opened = root.opened === key ? "" : key;
    }

    readonly property bool takeover: root.opened === "code" || root.opened === "share"

    readonly property real cardMax: Appearance.sizes.menuMaxHeight / 3

    property bool colourful: true

    property string said: ""

    onOpenedChanged: if (root.opened !== "code")
        root.said = ""

    readonly property bool showingCard: root.showing && root.opened === "share"

    onShowingCardChanged: Network.share(root.showingCard)

    function tookCode(text: string): void {
        const trouble = Network.joinQr(text);
        if (trouble) {
            root.said = trouble;
            return;
        }
        root.opened = "";
    }

    spacing: Appearance.padding.small

    readonly property bool busy: !!root.asking || !!root.opened

    property var frozen: []

    readonly property var rows: root.busy ? root.frozen : Network.enabled ? Network.networks : []

    property bool frozenStranded: false
    property bool frozenCaptive: false

    readonly property bool stranded: root.busy ? root.frozenStranded : Network.stranded
    readonly property bool captive: root.busy ? root.frozenCaptive : Network.captive

    onBusyChanged: if (root.busy) {
        root.frozen = root.rows;
        root.frozenStranded = Network.stranded;
        root.frozenCaptive = Network.captive;
    }

    onShowingChanged: if (!root.showing) {
        root.asking = "";
        root.opened = "";
    }

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

    component Act: MenuRow {}

    component Tool: Item {
        id: tool

        property string icon: ""
        property bool on: false
        property string tip: ""

        signal activated

        readonly property bool hovered: press.containsMouse

        implicitWidth: Math.max(Appearance.sizes.minTarget, Appearance.font.iconSize + Appearance.padding.small * 2)
        implicitHeight: implicitWidth

        SquircleRect {
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

    component Notice: Item {
        id: notice

        property string icon: ""
        property string label: ""
        property string detail: ""
        property string action: ""

        signal activated

        implicitWidth: parent ? parent.width : 0
        implicitHeight: line.implicitHeight

        SquircleRect {
            anchors.fill: parent
            radius: Appearance.rounding.normal
            color: Appearance.colour.accentFill
        }

        MenuRow {
            id: line

            label: notice.label
            detail: notice.detail
            onActivated: notice.activated()

            mark: Component {
                Icon {
                    name: notice.icon
                    size: line.iconSize
                    color: Appearance.colour.accent
                }
            }

            Icon {
                name: notice.action
                color: Appearance.colour.accent
            }
        }
    }

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

    MenuRow {
        width: root.width
        visible: Network.wiredShowing
        icon: "lan"
        label: "Ethernet"

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

    Notice {
        width: root.width

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

    Item {
        id: body

        width: root.width
        implicitHeight: root.takeover ? Math.max(list.implicitHeight, media.implicitHeight) : list.implicitHeight

        Column {
            id: list

            width: parent.width

            opacity: root.takeover ? 0 : 1

            enabled: !root.takeover

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.anim.normal
                }
            }

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

                        label: entry.modelData.name
                        detail: Network.stateLabel(entry.modelData)
                        selected: entry.modelData.connected

                        onActivated: {
                            const n = entry.modelData;
                            if (n.connected)
                                return n.disconnect();

                            if (n.known || !Network.secured(n))
                                return n.connect();
                            root.asking = root.asking === n.name ? "" : n.name;
                        }

                        tip: entry.modelData.connected ? "disconnect" : entry.modelData.known || !Network.secured(entry.modelData) ? "join" : Network.enterprise(entry.modelData) ? "needs sign-in" : "needs password"

                        Row {
                            spacing: Appearance.padding.normal

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter

                                visible: Network.secured(entry.modelData)

                                name: entry.modelData.known ? "key" : Network.enterprise(entry.modelData) ? "badge" : "lock"
                                color: Appearance.colour.textFaint

                                HoverTip {
                                    text: entry.modelData.known ? `${Network.securityLabel(entry.modelData)}, saved` : Network.securityLabel(entry.modelData)
                                }
                            }

                            SignalBars {
                                anchors.verticalCenter: parent.verticalCenter
                                strength: Network.percent(entry.modelData)
                                activeColour: entry.modelData.connected ? Appearance.colour.text : Appearance.colour.textDim

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

                    Loader {
                        id: secret

                        width: parent.width

                        active: root.asking === entry.modelData.name
                        visible: secret.active

                        sourceComponent: Network.enterprise(entry.modelData) ? signIn : passphrase
                    }

                    Component {
                        id: passphrase

                        SecretField {
                            claims: true

                            placeholder: `password for ${entry.modelData.name}`

                            onAccepted: psk => {

                                Network.clearFailure(entry.modelData.name);
                                Network.clearEnroll(entry.modelData.name);
                                entry.modelData.connectWithPsk(psk);
                                root.asking = "";
                            }
                            onCancelled: root.asking = ""
                        }
                    }

                    Component {
                        id: signIn

                        IdentityField {
                            placeholder: entry.modelData.name

                            onAccepted: (identity, password, eap, phase2) => {
                                Network.joinEnterprise(entry.modelData.name, identity, password, eap, phase2);
                                root.asking = "";
                            }
                            onCancelled: root.asking = ""
                        }
                    }

                    MenuLayer {
                        id: layer

                        width: parent.width
                        open: entry.showing

                        Loader {
                            id: switches

                            width: parent.width

                            active: layer.visible

                            sourceComponent: Column {
                                width: switches.width
                                spacing: 0

                                Act {
                                    visible: entry.modelData.connected
                                    icon: "link_off"
                                    label: "Disconnect"
                                    tip: "keeps password"
                                    onActivated: entry.modelData.disconnect()
                                }

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
                }
            }

            StyledText {
                visible: Network.enabled && !Network.networks.length
                leftPadding: Appearance.padding.normal
                text: Network.scanning ? "scanning" : "nothing found"
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
            }
        }

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

                        maxHeight: Math.max(0, Math.min(list.implicitHeight, root.cardMax) - (note.visible ? note.implicitHeight + parent.spacing : 0))

                        text: Network.card

                        caption: Network.activeName
                        detail: Network.secret

                        colourful: root.colourful
                        flippable: true
                        tip: root.colourful ? "ink on paper" : "in colour"
                        onFlipped: root.colourful = !root.colourful
                    }

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
