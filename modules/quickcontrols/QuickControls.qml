pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.mixer
import "quick-switches.js" as Switches

Item {
    id: root

    required property real border

    readonly property real grab: Config.values.control.touchEdges ? Math.max(root.border, Appearance.sizes.minTarget) : root.border

    readonly property real step: Config.values.volume.step

    readonly property real iconColumn: Appearance.font.iconSize

    readonly property real columnGap: Appearance.padding.small

    readonly property real rowGap: Appearance.padding.normal

    readonly property real sliderWidth: root.contentWidth - root.iconColumn - root.valueWidth - root.actionColumn - root.columnGap * 3

    readonly property real valueWidth: Appearance.sizes.screenValueWidth

    readonly property real actionColumn: root.iconColumn

    readonly property real levelsWidth: root.iconColumn + root.columnGap + Appearance.sizes.screenSliderWidth + root.columnGap + root.valueWidth + root.columnGap + root.actionColumn

    readonly property real chevronRoom: Math.round(Appearance.sizes.rowHeight * 0.8) + Appearance.button.seam

    readonly property real tileWidth: Math.ceil(Math.max(plainLabel.advanceWidth, Math.max(detailedLabel.advanceWidth, saverLabel.advanceWidth) + root.chevronRoom) + Appearance.padding.normal * 2 + Appearance.font.iconSize + Appearance.padding.small)

    readonly property real contentWidth: Math.max(root.levelsWidth, root.tileWidth * 2 + root.columnGap)

    TextMetrics {
        id: plainLabel

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "Do not disturb"
    }

    TextMetrics {
        id: detailedLabel

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "Performance"
    }

    TextMetrics {
        id: saverLabel

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
        text: "Energy saver"
    }

    readonly property real panelWidth: root.contentWidth + Appearance.padding.large * 2

    readonly property real panelHeight: root.contentHeight + Appearance.padding.large * 2

    readonly property real contentHeight: rows.implicitHeight

    readonly property real panelY: {
        const rest = (root.height - (root.panelHeight - mixerFold.height)) / 2;
        return Math.max(Appearance.padding.large, Math.min(rest, root.height - root.panelHeight - Appearance.padding.large));
    }

    property bool mixing: false

    onActiveChanged: if (!root.active)
        root.mixing = false

    readonly property bool mixerShown: root.mixing || fold.value > 0.001

    onMixerShownChanged: Mixer.watch(root, root.mixerShown)

    Component.onDestruction: Mixer.watch(root, false)

    Follow {
        id: fold

        target: root.mixing ? 1 : 0
        speed: Appearance.animation.resizeSpeed
        epsilon: 0.002
    }

    readonly property real rowHeight: Math.max(root.iconColumn, Appearance.sizes.sliderHeight * 2.2 * 1.35)

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
        }
    }

    function hasMenu(key: string): bool {
        return (QsWindow.window?.statusKeys ?? []).includes(key);
    }

    function openMenu(key: string, keyed: bool): void {
        const win = QsWindow.window;
        root.pinned = false;
        root.mixing = false;
        if (!win?.openMenu(key, true) || !keyed)
            return;
        win.takeKeyboard();
        win.menus.startKeys();
    }

    Item {
        id: keys
    }

    FocusChain {
        id: chain

        scope: rows
        area: cardZone
        holder: keys
    }

    Keys.onPressed: event => {
        if (!root.pinned)
            return;
        if (event.key === Qt.Key_M && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
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

    function warmthHue(k: int): color {
        if (k <= 0)
            return Appearance.colour.textFaint;

        const t = k / 100.0;
        let r, g, b;
        if (t <= 66) {
            r = 255;
            g = 99.4708025861 * Math.log(t) - 161.1195681661;
        } else {
            r = 329.698727446 * Math.pow(t - 60, -0.1332047592);
            g = 288.1221695283 * Math.pow(t - 60, -0.0755148492);
        }
        if (t >= 66)
            b = 255;
        else if (t <= 19)
            b = 0;
        else
            b = 138.5177312231 * Math.log(t - 10) - 305.0447927307;
        const m = Math.max(r, g, b);
        return Appearance.legible(Appearance.rgb(r / m * 0.7 + 0.3, g / m * 0.7 + 0.3, b / m * 0.7 + 0.3));
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

        onWheel: wheel => root.nudge(wheel)

        Column {
            id: rows

            x: Appearance.padding.large
            anchors.verticalCenter: parent.verticalCenter
            width: root.contentWidth
            spacing: 0
            opacity: reveal.value

            Grid {
                id: switches

                readonly property string focusGroup: "switches"

                readonly property real tileWidth: (width - columnSpacing) / 2

                width: parent.width
                columns: 2
                columnSpacing: root.columnGap
                rowSpacing: root.columnGap

                QuickSwitch {
                    width: switches.tileWidth
                    visible: Network.available
                    icon: Network.enabled ? "wifi" : "wifi_off"
                    label: Network.enabled && Network.activeName ? Network.activeName : "Wi-Fi"
                    on: Network.enabled
                    detailed: root.hasMenu("network")

                    onToggled: Network.setEnabled(!Network.enabled)
                    onOpened: keyed => root.openMenu("network", keyed)
                }

                QuickSwitch {
                    width: switches.tileWidth
                    visible: Bluetooth.available
                    icon: Bluetooth.enabled ? "bluetooth" : "bluetooth_disabled"
                    label: Bluetooth.enabled && Bluetooth.anyConnected ? Bluetooth.connectedDevices[0].name || "Bluetooth" : "Bluetooth"
                    on: Bluetooth.enabled
                    detailed: root.hasMenu("bluetooth")

                    onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                    onOpened: keyed => root.openMenu("bluetooth", keyed)
                }

                QuickSwitch {
                    width: switches.tileWidth
                    icon: Notifications.quiet ? "do_not_disturb_on" : "do_not_disturb_off"
                    label: "Do not disturb"
                    on: Notifications.quiet

                    onToggled: Notifications.setQuiet(!Notifications.quiet, "")
                }

                QuickSwitch {
                    width: switches.tileWidth
                    icon: "coffee"
                    label: "Keep awake"
                    on: Idle.awake

                    onToggled: Idle.awake = !Idle.awake
                }

                QuickSwitch {
                    width: switches.tileWidth
                    visible: !!Audio.source
                    icon: Audio.sourceMuted ? "mic_off" : "mic"
                    label: "Microphone"
                    on: !Audio.sourceMuted
                    detailed: root.hasMenu("audio")

                    onToggled: Audio.toggleSourceMute()
                    onOpened: keyed => root.openMenu("audio", keyed)
                }

                QuickSwitch {
                    width: switches.tileWidth
                    visible: PowerProfile.available && PowerProfile.choices.length > 1
                    icon: Switches.powerIcon(PowerProfile.profile)
                    label: Switches.powerLabel(PowerProfile.profile)
                    on: Switches.powerRaised(PowerProfile.profile)
                    detailed: root.hasMenu("battery")

                    onToggled: PowerProfile.set(Switches.nextProfile(PowerProfile.choices, PowerProfile.profile))
                    onOpened: keyed => root.openMenu("battery", keyed)
                }

                QuickSwitch {
                    width: switches.tileWidth
                    icon: Appearance.light ? "light_mode" : "dark_mode"
                    label: "Dark mode"
                    on: !Appearance.light

                    onToggled: DarkMode.choose(Appearance.light ? "dark" : "light")
                }

                QuickSwitch {
                    width: switches.tileWidth
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

                QuickSwitch {
                    width: switches.tileWidth
                    visible: Tunnels.list.length > 0
                    icon: "vpn_lock"
                    label: Tunnels.anyOn && Tunnels.activeName ? Tunnels.activeName : "VPN"
                    on: Tunnels.anyOn

                    onToggled: Tunnels.setFirst(!Tunnels.anyOn)
                }
            }

            Item {
                width: 1
                height: root.rowGap * 1.5
            }

            Item {
                id: soundRow

                width: parent.width
                height: Math.max(root.iconColumn, soundSlider.height)

                Icon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconColumn

                    name: Audio.icon(Audio.volume, Audio.muted)
                    color: Audio.muted ? Appearance.colour.textFaint : Audio.volume > 0 ? Appearance.huedOr(Appearance.hue.sound, Appearance.colour.textDim) : Appearance.colour.textDim

                    readonly property bool keyable: true

                    function press(): void {
                        Audio.toggleMute();
                    }

                    FocusMark {
                        shown: parent.activeFocus
                        pill: "object"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.small
                        cursorShape: Qt.PointingHandCursor

                        onClicked: Audio.toggleMute()
                    }
                }

                Slider {
                    id: soundSlider

                    anchors.left: parent.left
                    anchors.leftMargin: root.iconColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.sliderWidth

                    value: Audio.volume
                    from: 0
                    to: Audio.maxVolume
                    warnAbove: 1
                    step: root.step
                    dimmed: Audio.muted
                    hue: Appearance.hue.sound

                    onMoved: value => Audio.setVolume(value)
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: root.actionColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.valueWidth

                    text: `${Math.round(Audio.volume * 100)}%`
                    color: Appearance.colour.textDim
                }

                Item {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.actionColumn
                    height: root.actionColumn

                    readonly property bool keyable: true

                    function press(): void {
                        root.mixing = !root.mixing;
                    }

                    FocusMark {
                        anchors.margins: -Appearance.padding.small - reach
                        shown: parent.activeFocus
                        pill: "object"
                    }

                    SquircleRect {
                        anchors.centerIn: parent
                        width: parent.width + Appearance.padding.small * 2
                        height: width
                        pill: "object"
                        color: root.mixing ? Appearance.colour.chosen : mixHover.hovered ? Appearance.colour.fill : "transparent"
                    }

                    Icon {
                        anchors.centerIn: parent
                        name: "tune"
                        color: root.mixing ? Appearance.colour.onChosen : Appearance.colour.textDim
                    }

                    HoverHandler {
                        id: mixHover

                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: root.mixing = !root.mixing
                    }
                }
            }

            Item {
                id: mixerFold

                width: parent.width
                height: Math.round((mixerList.implicitHeight + root.rowGap) * fold.value)
                clip: true

                Column {
                    id: mixerList

                    width: parent.width
                    y: root.rowGap + (fold.value - 1) * Appearance.padding.large
                    opacity: fold.value * fold.value
                    spacing: root.rowGap

                    Repeater {
                        model: ScriptModel {
                            values: root.mixerShown ? Mixer.outputApps.map(a => a.key) : []
                        }

                        delegate: MixerQuickRow {
                            required property string modelData

                            width: mixerList.width
                            appKey: modelData
                            iconColumn: root.iconColumn
                            gap: root.columnGap
                            sliderWidth: root.sliderWidth
                            valueWidth: root.valueWidth
                        }
                    }

                    StyledText {
                        visible: !Mixer.outputApps.length
                        x: root.iconColumn + root.columnGap
                        text: "No app has sound open"
                        color: Appearance.colour.textFaint
                        font.pixelSize: Appearance.font.size.small
                    }

                    Button {
                        id: mixerOpen

                        x: root.iconColumn + root.columnGap - mixerOpen.padX
                        style: "bare"
                        text: "Open volume mixer"

                        onClicked: {
                            root.pinned = false;
                            root.mixing = false;
                            Mixer.show();
                        }
                    }
                }
            }

            Item {
                width: 1
                height: root.rowGap
                visible: brightRow.visible
            }

            Item {
                id: brightRow

                width: parent.width
                height: Math.max(root.iconColumn, brightSlider.height)
                visible: Display.brightnessReady

                Icon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconColumn

                    name: "brightness_6"
                    color: Display.levelKnown ? Appearance.huedOr(Appearance.hue.light, Appearance.colour.textDim) : Appearance.colour.textFaint
                }

                Slider {
                    id: brightSlider

                    anchors.left: parent.left
                    anchors.leftMargin: root.iconColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.sliderWidth

                    value: Display.levelKnown ? Display.level : 0
                    from: Display.floor
                    to: 1
                    dimmed: !Display.levelKnown
                    hue: Appearance.hue.light

                    onMoved: value => Display.setLevel(value)
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: root.actionColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.valueWidth

                    text: Display.levelKnown ? `${Math.round(Display.level * 100)}%` : "..."
                    color: Appearance.colour.textDim
                }
            }

            Item {
                width: 1
                height: root.rowGap
            }

            Item {
                id: warmRow

                width: parent.width
                height: Math.max(root.iconColumn, warmSlider.height)

                Icon {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.iconColumn

                    name: "nightlight"
                    color: Display.warm ? root.warmthHue(Display.kelvin) : Appearance.colour.textFaint

                    readonly property bool keyable: true

                    function press(): void {
                        Display.toggleWarm();
                    }

                    FocusMark {
                        shown: parent.activeFocus
                        pill: "object"
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Appearance.padding.small
                        cursorShape: Qt.PointingHandCursor

                        onClicked: Display.toggleWarm()
                    }
                }

                Slider {
                    id: warmSlider

                    anchors.left: parent.left
                    anchors.leftMargin: root.iconColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.sliderWidth

                    value: Display.kelvin > 0 ? Display.kelvin : Display.lastWarm
                    from: Display.warmest
                    to: Display.neutral
                    dimmed: !Display.warm
                    litOverride: root.warmthHue(Display.kelvin > 0 ? Display.kelvin : Display.lastWarm)

                    onMoved: value => Display.setWarmth(Math.round(value))
                }

                StyledText {
                    anchors.right: parent.right
                    anchors.rightMargin: root.actionColumn + root.columnGap
                    anchors.verticalCenter: parent.verticalCenter
                    width: root.valueWidth

                    text: Display.kelvin > 0 ? `${Display.kelvin}K` : "off"
                    color: Appearance.colour.textDim
                }
            }
        }
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
