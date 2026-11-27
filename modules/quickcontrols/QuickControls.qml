pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.menu.content
import "quick-switches.js" as Switches

Item {
    id: root

    required property real border

    readonly property real grab: Config.values.control.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    readonly property real step: Config.values.volume.step

    readonly property real gap: Appearance.padding.small

    readonly property real sectionGap: Appearance.padding.large

    readonly property bool hasNetwork: Network.available || Network.wiredAvailable
    readonly property bool hasBluetooth: Bluetooth.available
    readonly property bool hasSound: !!Audio.sink
    readonly property bool hasPower: PowerProfile.available && PowerProfile.choices.length > 1 || Battery.available

    readonly property real tileNeed: Math.max(root.hasNetwork ? network.implicitWidth : 0, root.hasBluetooth ? bluetooth.implicitWidth : 0, root.hasSound ? sound.implicitWidth : 0, root.hasPower ? power.implicitWidth : 0)

    readonly property real switchNeed: Math.max(quiet.implicitWidth, awake.implicitWidth, Audio.source ? microphone.implicitWidth : 0, dark.implicitWidth, ScreenRecorder.enabled && ScreenRecorder.ready ? record.implicitWidth : 0, Tunnels.list.length > 0 ? vpn.implicitWidth : 0)

    readonly property real contentWidth: Math.max(Appearance.sizes.menuWidth - Appearance.padding.large * 2, root.tileNeed * 2 + root.gap, root.switchNeed * 2 + root.gap)

    readonly property real panelWidth: root.contentWidth + Appearance.padding.large * 2

    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

    readonly property real mainHeight: main.implicitHeight

    readonly property real pageRoom: Math.max(Appearance.sizes.rowHeight * 4, Math.min(Appearance.sizes.menuMaxHeight, root.height - Appearance.padding.large * 4) - Appearance.padding.large * 2)

    readonly property real pageHeight: Math.min(root.pageRoom, header.height + root.sectionGap + (pageBody.item?.implicitHeight ?? pageBody.item?.height ?? 0))

    readonly property real contentHeight: Math.round(root.mainHeight + (root.pageHeight - root.mainHeight) * paging.value)

    readonly property real panelY: {
        const rest = (root.height - root.panelHeight) / 2;
        return Math.max(Appearance.padding.large, Math.min(rest, root.height - root.panelHeight - Appearance.padding.large));
    }

    property string page: ""

    property string shownPage: ""

    onPageChanged: if (root.page !== "")
        root.shownPage = root.page

    readonly property var pages: ({
            network: {
                title: "Network",
                body: networkPage
            },
            bluetooth: {
                title: "Bluetooth",
                body: bluetoothPage
            },
            sound: {
                title: "Sound",
                body: soundPage
            },
            power: {
                title: Battery.available ? "Battery" : "Power mode",
                body: powerPage
            }
        })

    function openPage(key: string): void {
        root.pinned = true;
        root.page = key;
    }

    function back(): void {
        root.page = "";
    }

    Follow {
        id: paging

        target: root.page !== "" ? 1 : 0
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.002
        onValueChanged: if (paging.value === 0 && root.page === "")
            root.shownPage = ""
    }

    onActiveChanged: if (!root.active)
        root.page = ""

    readonly property bool active: root.pinned || linger.running || rail.pressed || root.dwelt && (root.held || grace.running)

    readonly property bool held: rail.containsMouse || rail.pressed || cardZone.containsMouse

    property bool dwelt: false

    onHeldChanged: {
        if (!root.held) {
            grace.restart();
            return;
        }
        grace.stop();
        if (reveal.value > 0.5)
            root.dwelt = true;
    }

    readonly property Item maskItem: root.pinned ? catcher : cardZone

    readonly property Item grabItem: rail

    property bool pinned: false

    onPinnedChanged: {
        if (root.pinned) {
            keys.forceActiveFocus();
            chain.start();
        } else {
            chain.reset();
            root.page = "";
        }
    }

    Item {
        id: keys
    }

    FocusChain {
        id: chain

        scope: root.page !== "" ? pageColumn : main
        area: cardZone
        holder: keys
    }

    Keys.onPressed: event => {
        if (!root.pinned)
            return;
        if (event.key === Qt.Key_Escape && root.page !== "") {
            root.back();
            event.accepted = true;
        } else if (root.page === "" && event.key === Qt.Key_M && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
            Audio.toggleMute();
            event.accepted = true;
        } else if (chain.handle(event)) {
            event.accepted = true;
        }
    }

    readonly property var blobs: [
        {
            x: root.width - root.panelWidth + (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value),
            y: root.panelY,
            w: root.panelWidth,
            h: root.panelHeight,
            radius: Appearance.rounding.large,
            smooth: Math.min(Appearance.sizes.melt, Math.min(root.panelWidth, root.panelHeight) / 2)
        }
    ]

    function nudge(wheel: var): void {
        const touchpad = wheel.pixelDelta.x !== 0 || wheel.pixelDelta.y !== 0;
        const natural = wheel.inverted || (touchpad ? Compositor.naturalScrollTouchpad : Compositor.naturalScrollMouse);
        const notches = wheel.angleDelta.y / 120 * (natural ? -1 : 1);
        Audio.setVolume(Audio.volume + notches * root.step);
    }

    Follow {
        id: reveal

        speed: Appearance.animation.revealSpeed
        target: root.active ? 1 : 0
        epsilon: 0.005
    }

    LevelCover {
        active: reveal.value > 0.2
        kinds: ["volume", "brightness"]
    }

    Timer {
        id: dwell

        interval: Appearance.animation.dwell
        running: rail.containsMouse && !root.dwelt
        onTriggered: root.dwelt = true
    }

    Timer {
        id: grace

        interval: Appearance.animation.grace
        onTriggered: root.dwelt = false
    }

    Timer {
        id: linger

        interval: Config.values.screen.linger
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            linger.restart();
        }
    }

    Connections {
        target: Display

        function onLevelChanged(): void {
            linger.restart();
        }

        function onKelvinChanged(): void {
            linger.restart();
        }
    }

    MouseArea {
        id: catcher

        anchors.fill: parent
        enabled: root.pinned
        visible: root.pinned

        onClicked: mouse => {
            if (!cardZone.contains(catcher.mapToItem(cardZone, mouse.x, mouse.y)))
                root.pinned = false;
        }
    }

    MouseArea {
        id: cardZone

        anchors.right: parent.right
        y: root.panelY
        width: Math.max(root.border, root.panelWidth - (root.panelWidth + Appearance.sizes.melt) * (1 - reveal.value))
        height: root.panelHeight

        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        enabled: reveal.value > 0.01

        onWheel: wheel => {
            if (root.page === "")
                root.nudge(wheel);
        }

        Item {
            id: stage

            x: Appearance.padding.large
            y: Appearance.padding.large
            width: root.contentWidth
            height: root.contentHeight
            clip: paging.value > 0 && paging.value < 1
            opacity: reveal.value

            Column {
                id: main

                readonly property real tileWidth: (root.contentWidth - root.gap) / 2

                x: -paging.value * Appearance.padding.huge * 2
                width: root.contentWidth
                spacing: root.sectionGap
                opacity: (1 - paging.value) * (1 - paging.value)
                visible: paging.value < 0.999
                enabled: root.page === ""

                Flow {
                    id: tiles

                    readonly property int count: [root.hasNetwork, root.hasBluetooth, root.hasSound, root.hasPower].filter(v => v).length

                    function span(last: bool): real {
                        return last && tiles.count % 2 === 1 ? root.contentWidth : main.tileWidth;
                    }

                    width: parent.width
                    spacing: root.gap
                    visible: tiles.count > 0

                    QuickTile {
                        id: network

                        width: tiles.span(!root.hasBluetooth && !root.hasSound && !root.hasPower)
                        visible: root.hasNetwork
                        icon: !Network.available ? "lan" : Network.enabled ? "wifi" : "wifi_off"
                        label: Network.available ? "Wi-Fi" : "Ethernet"
                        detail: Switches.networkState(Network.available, Network.enabled, Network.activeName, Network.wiredConnected)
                        on: Network.available ? Network.enabled : Network.wiredConnected

                        onToggled: if (Network.available)
                            Network.setEnabled(!Network.enabled)
                        onOpened: root.openPage("network")
                    }

                    QuickTile {
                        id: bluetooth

                        width: tiles.span(!root.hasSound && !root.hasPower)
                        visible: root.hasBluetooth
                        icon: Bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
                        label: "Bluetooth"
                        detail: !Bluetooth.enabled ? "Off" : Bluetooth.anyConnected ? Bluetooth.connectedDevices[0].name || "Connected" : "On"
                        on: Bluetooth.enabled

                        onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                        onOpened: root.openPage("bluetooth")
                    }

                    QuickTile {
                        id: sound

                        width: tiles.span(!root.hasPower)
                        visible: root.hasSound
                        icon: Audio.icon(Audio.volume, Audio.muted)
                        label: "Sound"
                        detail: Audio.muted ? "Muted" : Audio.deviceLabel(Audio.sink)
                        on: !Audio.muted

                        onToggled: Audio.toggleMute()
                        onOpened: root.openPage("sound")
                    }

                    QuickTile {
                        id: power

                        width: tiles.span(true)
                        visible: root.hasPower
                        icon: PowerProfile.icon(PowerProfile.profile)
                        label: Battery.available ? "Battery" : "Power mode"
                        detail: Switches.powerDetail(PowerProfile.available ? PowerProfile.label(PowerProfile.profile) : "", Battery.available, Battery.percentage)
                        on: Switches.powerRaised(PowerProfile.profile)

                        onToggled: if (PowerProfile.available)
                            PowerProfile.set(Switches.nextProfile(PowerProfile.choices, PowerProfile.profile))
                        onOpened: root.openPage("power")
                    }
                }

                Grid {
                    id: toggles

                    columns: 2
                    width: parent.width
                    columnSpacing: root.gap
                    rowSpacing: 0

                    readonly property real cell: (root.contentWidth - root.gap) / 2

                    QuickToggle {
                        id: quiet

                        width: toggles.cell
                        icon: Notifications.quiet ? "do_not_disturb_on" : "do_not_disturb_off"
                        label: "Do not disturb"
                        on: Notifications.quiet

                        onToggled: Notifications.setQuiet(!Notifications.quiet, "")
                    }

                    QuickToggle {
                        id: awake

                        width: toggles.cell
                        icon: "coffee"
                        label: "Keep awake"
                        on: Idle.awake

                        onToggled: Idle.awake = !Idle.awake
                    }

                    QuickToggle {
                        id: microphone

                        width: toggles.cell
                        visible: !!Audio.source
                        icon: Audio.sourceMuted ? "mic_off" : "mic"
                        label: "Microphone"
                        on: !Audio.sourceMuted

                        onToggled: Audio.toggleSourceMute()
                    }

                    QuickToggle {
                        id: dark

                        width: toggles.cell
                        icon: Appearance.light ? "light_mode" : "dark_mode"
                        label: "Dark mode"
                        on: !Appearance.light

                        onToggled: DarkMode.choose(Appearance.light ? "dark" : "light")
                    }

                    QuickToggle {
                        id: record

                        width: toggles.cell
                        visible: ScreenRecorder.enabled && ScreenRecorder.ready
                        icon: ScreenRecorder.recording ? "stop_circle" : "screen_record"
                        label: ScreenRecorder.recording ? ScreenRecorder.clock : "Record"
                        on: ScreenRecorder.busy

                        onToggled: {
                            if (ScreenRecorder.recording) {
                                ScreenRecorder.stop();
                                return;
                            }
                            if (ScreenRecorder.busy)
                                return;
                            const screen = QsWindow.window?.screen?.name ?? "";
                            root.pinned = false;
                            ScreenRecorder.start("screen", false, screen, "");
                        }
                    }

                    QuickToggle {
                        id: vpn

                        width: toggles.cell
                        visible: Tunnels.list.length > 0
                        icon: "vpn_lock"
                        label: Tunnels.anyOn && Tunnels.activeName ? Tunnels.activeName : "VPN"
                        on: Tunnels.anyOn

                        onToggled: Tunnels.setFirst(!Tunnels.anyOn)
                    }
                }

                Column {
                    width: parent.width
                    spacing: root.gap

                    LevelBar {
                        width: parent.width
                        icon: Audio.icon(Audio.volume, Audio.muted)
                        value: Audio.volume
                        from: 0
                        to: Audio.maxVolume
                        warnAbove: 1
                        step: root.step
                        dimmed: Audio.muted
                        reading: `${Math.round(Audio.volume * 100)}%`

                        onMoved: value => Audio.setVolume(value)
                    }

                    LevelBar {
                        width: parent.width
                        visible: Display.brightnessReady
                        icon: "brightness_6"
                        value: Display.levelKnown ? Display.level : 0
                        from: Display.floor
                        to: 1
                        dimmed: !Display.levelKnown
                        reading: Display.levelKnown ? `${Math.round(Display.level * 100)}%` : "..."

                        onMoved: value => Display.setLevel(value)
                    }

                    LevelBar {
                        width: parent.width
                        icon: "nightlight"
                        value: Display.kelvin > 0 ? Display.kelvin : Display.lastWarm
                        from: Display.warmest
                        to: Display.neutral
                        step: (Display.neutral - Display.warmest) / 20
                        dimmed: !Display.warm
                        toggles: true
                        reading: Display.kelvin > 0 ? `${Display.kelvin}K` : "Off"

                        onMoved: value => Display.setWarmth(Math.round(value))
                        onToggled: Display.toggleWarm()
                    }
                }
            }

            Column {
                id: pageColumn

                x: (1 - paging.value) * Appearance.padding.huge * 2
                width: root.contentWidth
                spacing: root.sectionGap
                opacity: paging.value * paging.value
                visible: root.shownPage !== ""
                enabled: root.page !== ""

                Item {
                    id: header

                    width: parent.width
                    height: Appearance.sizes.rowHeight

                    Item {
                        id: backButton

                        readonly property bool keyable: true

                        function press(): void {
                            root.back();
                        }

                        width: parent.height
                        height: parent.height
                        scale: backPress.value

                        Follow {
                            id: backPress

                            target: backPointer.pressed ? Appearance.press.plate : 1
                            speed: Appearance.animation.revealSpeed
                            epsilon: Appearance.animation.fadeEpsilon
                            startsAtTarget: true
                        }

                        SquircleRect {
                            anchors.fill: parent
                            pill: "object"
                            color: backPointer.containsMouse ? Appearance.colour.fillStronger : Appearance.colour.fillStrong
                            rim: 1
                        }

                        FocusMark {
                            shown: backButton.activeFocus
                            pill: "object"
                        }

                        Icon {
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: -Appearance.padding.hair
                            name: "chevron_left"
                            color: Appearance.colour.text
                        }

                        MouseArea {
                            id: backPointer

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onClicked: root.back()
                        }
                    }

                    StyledText {
                        anchors.left: backButton.right
                        anchors.leftMargin: Appearance.padding.normal
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.pages[root.shownPage]?.title ?? ""
                        color: Appearance.colour.text
                        font.pixelSize: Appearance.font.size.large
                        elide: Text.ElideRight
                    }
                }

                Flickable {
                    id: pageView

                    width: parent.width
                    height: Math.max(0, root.pageHeight - header.height - root.sectionGap)
                    contentWidth: width
                    contentHeight: pageBody.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: pageView.contentHeight > pageView.height

                    WheelStep {
                        flick: pageView
                    }

                    Loader {
                        id: pageBody

                        width: pageView.width
                        active: root.shownPage !== ""
                        sourceComponent: root.pages[root.shownPage]?.body ?? null

                        onLoaded: {
                            pageBody.item.width = Qt.binding(() => pageBody.width);
                            if (pageBody.item.showing !== undefined)
                                pageBody.item.showing = Qt.binding(() => root.page !== "" && root.active);
                        }
                    }
                }
            }
        }
    }

    Component {
        id: networkPage

        NetworkMenu {}
    }

    Component {
        id: bluetoothPage

        BluetoothMenu {}
    }

    Component {
        id: soundPage

        SoundMenu {}
    }

    Component {
        id: powerPage

        BatteryMenu {}
    }

    MouseArea {
        id: rail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.grab
        height: parent.height * Config.values.screen.grabFraction

        property real fromY: 0
        property real fromVolume: 0

        hoverEnabled: true

        acceptedButtons: Qt.LeftButton

        onPressed: mouse => {
            rail.fromY = mouse.y;
            rail.fromVolume = Audio.volume;
        }

        onPositionChanged: mouse => {
            if (rail.pressed)
                Audio.setVolume(rail.fromVolume + (rail.fromY - mouse.y) * root.perPixel);
        }

        onWheel: wheel => root.nudge(wheel)
    }

    readonly property real perPixel: Audio.maxVolume / Math.max(1, rail.height)
}
