pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

Item {
    id: root

    property real reach: 0

    property string openKey: ""

    readonly property real panelHeight: Appearance.sizes.streamHeight
    readonly property real pad: Appearance.padding.card
    readonly property real columnGap: Appearance.padding.huge

    readonly property var screens: Quickshell.screens.map(s => s.name).sort((a, b) => Hypr.bandFor(a) - Hypr.bandFor(b))

    readonly property real sectionWidth: (top.width - root.columnGap * (root.screens.length - 1)) / Math.max(1, root.screens.length)

    readonly property var rows: ({
            network: networkRow,
            audio: soundRow,
            bluetooth: bluetoothRow,
            battery: batteryRow
        })

    signal menuRequested(string key)

    function anchorFor(key: string): Item {
        const row = root.rows[key] ?? null;
        return row?.visible ? row : null;
    }

    visible: root.reach > 0

    SystemClock {
        id: time

        precision: SystemClock.Minutes
    }

    Item {
        id: band

        y: root.reach - root.panelHeight
        width: root.width
        height: root.panelHeight
        opacity: root.reach / root.panelHeight

        StudioControls {
            id: studio

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.pad
        }

        Row {
            id: top

            anchors.top: studio.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: status.top
            anchors.leftMargin: root.pad
            anchors.rightMargin: root.pad
            anchors.topMargin: Appearance.padding.normal
            anchors.bottomMargin: Appearance.padding.normal

            spacing: root.columnGap

            Repeater {
                model: root.screens

                delegate: Item {
                    id: section

                    required property string modelData

                    readonly property int first: Hypr.bandFor(section.modelData)
                    readonly property int active: Hypr.activeOn(section.modelData)
                    readonly property var special: Hypr.specials.find(s => s.name === Hypr.specialOn(section.modelData)) ?? null
                    readonly property var windows: [...(section.special?.windows ?? []), ...Hypr.clientsIn(section.active)]

                    readonly property int rowsFit: Math.max(1, Math.floor(listArea.height / Appearance.sizes.rowHeight))
                    readonly property int columns: section.windows.length > section.rowsFit ? 2 : 1
                    readonly property int capacity: section.rowsFit * section.columns
                    readonly property var shown: section.windows.length > section.capacity ? section.windows.slice(0, section.capacity - 1) : section.windows
                    readonly property real cellWidth: (section.width - Appearance.padding.small * (section.columns - 1)) / section.columns

                    width: root.sectionWidth
                    height: top.height
                    clip: true

                    Row {
                        id: header

                        spacing: Appearance.padding.normal

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            leftPadding: Appearance.padding.normal
                            text: section.modelData.toUpperCase()
                            color: Appearance.colour.textFaint
                            font.letterSpacing: Appearance.font.stem
                        }

                        Row {
                            spacing: Appearance.padding.small

                            Repeater {
                                model: Hypr.count

                                delegate: SquircleRect {
                                    id: chip

                                    required property int index

                                    readonly property int workspace: section.first + chip.index
                                    readonly property bool current: chip.workspace === section.active
                                    readonly property bool busy: Hypr.clientsIn(chip.workspace).length > 0

                                    width: Appearance.sizes.workspaceSlot
                                    height: Appearance.sizes.workspaceSlot
                                    radius: Appearance.rounding.normal
                                    color: chip.current ? Appearance.colour.fillStronger : press.containsMouse ? Appearance.colour.fill : "transparent"

                                    StyledText {
                                        anchors.centerIn: parent
                                        text: `${chip.workspace}`
                                        color: chip.current ? Appearance.colour.text : chip.busy ? Appearance.colour.textDim : Appearance.colour.textFaint
                                    }

                                    MouseArea {
                                        id: press

                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Hypr.switchTo(chip.workspace)
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: listArea

                        anchors.top: header.bottom
                        anchors.topMargin: Appearance.padding.small
                        anchors.bottom: parent.bottom
                        width: parent.width
                    }

                    Grid {
                        anchors.top: listArea.top

                        flow: Grid.TopToBottom
                        rows: section.rowsFit
                        columnSpacing: Appearance.padding.small

                        Repeater {
                            model: section.shown

                            delegate: MenuRow {
                                id: windowRow

                                required property var modelData

                                readonly property string appClass: Hypr.classOf(windowRow.modelData)
                                readonly property bool overlaid: section.special?.windows.includes(windowRow.modelData) ?? false

                                width: section.cellWidth
                                label: Apps.nameFor(windowRow.appClass) || windowRow.modelData.title
                                detail: windowRow.overlaid ? section.special.label : ""
                                inlineDetail: true
                                selected: Hypr.isFocused(windowRow.modelData)
                                tip: windowRow.modelData.title

                                mark: Component {
                                    AppMark {
                                        spec: AppIcons.markFor(windowRow.appClass, "")
                                    }
                                }

                                onActivated: Hypr.focusClient(windowRow.modelData)
                            }
                        }

                        StyledText {
                            visible: section.shown.length < section.windows.length
                            width: section.cellWidth
                            height: Appearance.sizes.rowHeight
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: Appearance.padding.normal
                            text: `+${section.windows.length - section.shown.length} more`
                            color: Appearance.colour.textFaint
                        }
                    }
                }
            }
        }

        Item {
            id: status

            readonly property var items: [networkRow, soundRow, bluetoothRow, batteryRow]
            readonly property int shown: status.items.filter(row => row.visible).length
            readonly property real slot: Math.min(Appearance.sizes.menuWidth, (status.width - clock.width - root.columnGap) / Math.max(1, status.shown))
            readonly property real lineHeight: Math.max(clock.implicitHeight, ...status.items.filter(row => row.visible).map(row => row.implicitHeight))

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.pad
            height: status.lineHeight

            Column {
                id: clock

                anchors.right: parent.right
                anchors.rightMargin: Appearance.padding.normal
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(time.date, "HH:mm")
                    font.pixelSize: Appearance.font.size.large
                }

                StyledText {
                    anchors.right: parent.right
                    text: Qt.formatDateTime(time.date, "ddd d MMMM")
                    color: Appearance.colour.textDim
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter

                MenuRow {
                    id: networkRow

                    width: status.slot
                    height: status.lineHeight
                    icon: Network.icon()
                    mark: Network.carrier === "wifi" ? signalMark : null
                    label: Network.carrier === "wired" ? Network.wiredLabel || "Wired" : Network.carrier === "wifi" ? Network.activeName : "Offline"
                    detail: Network.reachLabel()
                    selected: root.openKey === "network"

                    onActivated: root.menuRequested("network")
                }

                MenuRow {
                    id: soundRow

                    width: status.slot
                    height: status.lineHeight
                    icon: Audio.icon(Audio.volume, Audio.muted)
                    label: Audio.muted ? "Muted" : `${Math.round(Audio.volume * 100)}%`
                    detail: Audio.deviceLabel(Audio.sink)
                    selected: root.openKey === "audio"

                    onActivated: root.menuRequested("audio")

                    Icon {
                        name: Audio.sourceMuted ? "mic_off" : "mic"
                        color: Audio.sourceMuted ? Appearance.colour.alarm : Appearance.colour.textFaint
                    }
                }

                MenuRow {
                    id: bluetoothRow

                    width: status.slot
                    height: status.lineHeight
                    visible: Bluetooth.anyConnected
                    icon: Bluetooth.statusIcon()
                    label: Bluetooth.connectedDevices.map(d => d.name || d.address).join(", ")
                    selected: root.openKey === "bluetooth"

                    onActivated: root.menuRequested("bluetooth")
                }

                MenuRow {
                    id: batteryRow

                    width: status.slot
                    height: status.lineHeight
                    visible: Battery.available
                    mark: batteryMark
                    label: `${Battery.percent}%`
                    detail: Battery.charging ? "charging" : ""
                    selected: root.openKey === "battery"

                    onActivated: root.menuRequested("battery")
                }
            }
        }
    }

    Component {
        id: signalMark

        SignalBars {
            strength: Network.activeStrength
        }
    }

    Component {
        id: batteryMark

        BatteryMeter {
            level: Battery.percentage
            charging: Battery.charging
            low: Battery.low
        }
    }
}
