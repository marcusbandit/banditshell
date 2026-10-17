pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.controls
import "catalogue.js" as Catalogue

Item {
    id: root

    signal picked(string key)

    property bool walking: true

    readonly property int slot: Appearance.sizes.statusSlot
    readonly property real naturalHeight: column.implicitHeight + Appearance.padding.normal * 2

    readonly property var zones: ({
            tray: Qt.rect(0, column.y + tray.y, root.width, tray.height),
            workspaces: Qt.rect(0, column.y + spaces.y, root.width, spaces.height),
            update: Qt.rect(0, column.y + bottom.y + update.y, root.width, update.height),
            clock: Qt.rect(0, column.y + bottom.y + clock.y, root.width, clock.height),
            status: Qt.rect(0, column.y + bottom.y + (mode.visible ? mode.y : status.y), root.width, status.y + status.height - (mode.visible ? mode.y : status.y))
        })

    width: SettingsState.v("sidebarW")
    implicitHeight: root.naturalHeight

    SystemClock {
        id: now

        precision: SystemClock.Minutes
    }

    Column {
        id: column

        y: Appearance.padding.normal
        width: root.width
        spacing: Appearance.padding.large

        Column {
            id: tray

            width: root.width
            spacing: 4
            visible: SettingsState.v("tray") && Tray.items.length > 0

            Repeater {
                model: SettingsState.v("tray") ? Tray.items.slice(0, SettingsState.v("trayMax")) : []

                delegate: Item {
                    required property var modelData

                    width: root.width
                    height: root.slot

                    AppMark {
                        anchors.centerIn: parent
                        spec: Tray.markFor(modelData)
                        color: Appearance.colour.textDim
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked("tray")
                    }

                    HoverTip {
                        text: Tray.nameOf(modelData).toLowerCase()
                    }
                }
            }
        }

        Item {
            id: spaces

            width: root.width
            height: plates.implicitHeight + (rack.visible ? Appearance.padding.large + rack.implicitHeight : 0)

            MiniWorkspaces {
                id: plates

                anchors.horizontalCenter: parent.horizontalCenter
                style: SettingsState.v("wsStyle")
                colourful: SettingsState.v("iconMode") === "colour"
                persistent: SettingsState.v("persistent")
                limit: 10
                walking: root.walking
            }

            Column {
                id: rack

                anchors.horizontalCenter: parent.horizontalCenter
                y: plates.implicitHeight + Appearance.padding.large
                spacing: 4
                visible: Hypr.specialDeck.length > 0 && SettingsState.v("wsStyle") === "plates"

                Repeater {
                    model: Hypr.specialDeck

                    delegate: SquircleRect {
                        required property var modelData

                        width: 20
                        height: 20
                        radius: Appearance.rounding.normal
                        color: Appearance.colour.fill

                        Icon {
                            anchors.centerIn: parent
                            name: modelData.windows.length ? Apps.iconFor(Hypr.classOf(modelData.windows[0])) : "stacks"
                            size: Appearance.icon.small
                            color: Appearance.colour.textDim
                        }
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.picked("wsStyles")
            }

            HoverTip {
                text: "workspace style"
            }
        }

        Column {
            id: bottom

            width: root.width
            spacing: Appearance.padding.large

            Item {
                id: update

                readonly property string shows: SettingsState.v("sbUpdate")
                readonly property bool pending: Update.state !== Update.idle || CliMigration.stale
                readonly property var look: Update.state === Update.available ? ["system_update_alt", Appearance.colour.updateAvailable, 20] : Update.state === Update.downloading ? ["cloud_download", Appearance.colour.updateAvailable, 20] : Update.state === Update.downloaded ? ["download_done", Appearance.colour.updateReady, 20] : ["sync", Appearance.colour.textDim, 16]

                width: root.width
                height: root.slot
                visible: update.shows === "always" || (update.shows === "new" && update.pending)

                Icon {
                    anchors.centerIn: parent
                    name: update.look[0]
                    fill: 1
                    size: update.look[2]
                    color: update.look[1]
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.picked("sbUpdate")
                }

                HoverTip {
                    text: `update · ${Update.branch}`
                }
            }

            Column {
                id: clock

                readonly property string style: SettingsState.v("sbClock")
                readonly property string dated: SettingsState.v("sbDate")
                readonly property string hh: TimeFormat.hourPart(now.date)
                readonly property string mm: Qt.formatDateTime(now.date, "mm")

                width: root.width
                visible: clock.style !== "off" || clock.dated !== "off"

                Item {
                    width: root.width
                    height: Math.max(Appearance.sizes.minTarget, clock.style === "one line" ? sideways.implicitWidth : stacked.implicitHeight)
                    visible: clock.style !== "off"

                    Column {
                        id: stacked

                        anchors.centerIn: parent
                        visible: clock.style !== "one line"

                        Repeater {
                            model: [clock.hh, clock.mm]

                            delegate: StyledText {
                                required property string modelData

                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData
                                font.pixelSize: clock.style === "small" ? Appearance.font.size.small : Appearance.font.size.normal
                            }
                        }
                    }

                    StyledText {
                        id: sideways

                        anchors.centerIn: parent
                        visible: clock.style === "one line"
                        text: `${clock.hh}:${clock.mm}`
                        font.pixelSize: Appearance.font.size.small
                        rotation: -90
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked("sbClock")
                    }

                    HoverTip {
                        text: "clock"
                    }
                }

                Item {
                    width: 1
                    height: Appearance.padding.normal
                    visible: clock.style !== "off" && clock.dated !== "off"
                }

                Item {
                    width: root.width
                    height: Math.max(Appearance.sizes.minTarget, dateText.implicitHeight)
                    visible: clock.dated !== "off"

                    StyledText {
                        id: dateText

                        anchors.centerIn: parent
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.size.small
                        text: clock.dated === "day" ? `${now.date.getDate()}` : `${now.date.getDate()}\n${Qt.formatDateTime(now.date, "MMM").toUpperCase()}`
                        color: Appearance.colour.textFaint
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.picked("sbDate")
                    }

                    HoverTip {
                        text: "calendar"
                    }
                }
            }

            Item {
                id: mode

                width: root.width
                height: root.slot
                visible: SettingsState.modeIcon !== ""

                Icon {
                    anchors.centerIn: parent
                    name: SettingsState.modeIcon || "radio_button_unchecked"
                    fill: 1
                    color: Appearance.colour.accent
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: SettingsView.go("modes")
                }
            }

            Column {
                id: status

                width: root.width
                spacing: 4

                readonly property var parts: [["sbSound", "sound", true], ["sbNet", "network", true], ["sbBt", "bluetooth", true], ["sbBatt", "battery", SettingsState.hasBattery]].filter(p => p[2] && SettingsState.v(p[0]))

                Repeater {
                    model: status.parts

                    delegate: Item {
                        id: part

                        required property var modelData

                        width: root.width
                        height: root.slot

                        Icon {
                            anchors.centerIn: parent
                            visible: part.modelData[1] !== "battery" && !(part.modelData[1] === "network" && Network.carrier === "wifi")
                            name: part.modelData[1] === "sound" ? Audio.icon(Audio.volume, Audio.muted) : part.modelData[1] === "network" ? Network.icon() : Bluetooth.statusIcon()
                            color: Appearance.colour.textDim
                        }

                        SignalBars {
                            anchors.centerIn: parent
                            visible: part.modelData[1] === "network" && Network.carrier === "wifi"
                            strength: Network.activeStrength
                            activeColour: Appearance.colour.textDim
                        }

                        BatteryMeter {
                            anchors.centerIn: parent
                            visible: part.modelData[1] === "battery"
                            level: Battery.percentage
                            charging: Battery.charging
                            low: Battery.low
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.picked(part.modelData[0])
                        }

                        HoverTip {
                            text: part.modelData[1]
                        }
                    }
                }
            }
        }
    }
}
