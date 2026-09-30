pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    function say(v: string): string {
        return v || "unknown";
    }

    Component.onCompleted: {
        SysInfo.watch(true);
        Device.watch(true);
    }

    Component.onDestruction: {
        SysInfo.watch(false);
        Device.watch(false);
    }

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            title: "This machine"

            SettingsRow {
                icon: "computer"
                label: Device.hostname || "this machine"
                detail: [Device.vendor, Device.product].filter(p => p).join(" ") || Device.os
                interactive: false
            }

            SettingsRow {
                icon: "developer_board"
                label: "Motherboard"
                value: root.say(Device.board)
                interactive: false
            }

            SettingsRow {
                icon: "memory"
                label: "Firmware"
                value: root.say(Device.bios)
                interactive: false
            }
        }

        SettingsCard {
            title: "Processor"

            SettingsRow {
                icon: "memory"
                label: "Model"
                value: root.say(Device.cpu)
                interactive: false
            }

            SettingsRow {
                icon: "grid_view"
                label: "Cores"
                value: Device.threads > 0 ? `${Device.cores} cores, ${Device.threads} threads` : "unknown"
                interactive: false
            }

            SettingsRow {
                icon: "speed"
                label: "Load"
                value: `${Math.round(SysInfo.cpu * 100)}%`
                interactive: false
            }

            SettingsRow {
                visible: SysInfo.temperature > 0
                icon: "device_thermostat"
                label: "Temperature"
                value: `${Math.round(SysInfo.temperature)} °C`
                interactive: false
            }

            SettingsRow {
                visible: Device.cpuMaxMhz > 0
                icon: "bolt"
                label: "Boost"
                value: `${(Device.cpuMaxMhz / 1000).toFixed(1)} GHz`
                interactive: false
            }
        }

        SettingsCard {
            title: "Memory"

            SettingsRow {
                icon: "memory_alt"
                label: "Installed"
                value: `${Device.memoryTotalGb.toFixed(1)} GB`
                interactive: false
            }

            SettingsRow {
                icon: "memory_alt"
                label: "In use"
                value: `${SysInfo.memoryUsedGb.toFixed(1)} GB (${Math.round(SysInfo.memory * 100)}%)`
                interactive: false
            }

            SettingsRow {
                visible: Device.swapTotalGb > 0
                icon: "swap_horiz"
                label: "Swap"
                value: `${Device.swapTotalGb.toFixed(1)} GB`
                interactive: false
            }
        }

        SettingsCard {
            title: "Graphics"
            visible: Device.gpus.length > 0

            Repeater {
                model: Device.gpus

                delegate: SettingsRow {
                    required property string modelData

                    icon: "videogame_asset"
                    label: modelData
                    interactive: false
                }
            }
        }

        SettingsCard {
            title: "Storage"

            Repeater {
                model: Device.disks

                delegate: SettingsRow {
                    required property var modelData

                    icon: "hard_drive"
                    label: modelData.model || modelData.name
                    value: modelData.size
                    detail: `/dev/${modelData.name}`
                    interactive: false
                }
            }

            SettingsRow {
                icon: "folder"
                label: "Root filesystem"
                value: Device.rootTotal ? `${Device.rootUsed} of ${Device.rootTotal} used` : "unknown"
                interactive: false
            }
        }

        SettingsCard {
            title: "Software"

            SettingsRow {
                icon: "terminal"
                label: "Kernel"
                value: Device.kernel ? `${Device.kernel} (${root.say(Device.arch)})` : "unknown"
                interactive: false
            }

            SettingsRow {
                icon: "layers"
                label: "Compositor"
                value: [Compositor.name, Device.compositorVersion].filter(p => p).join(" ")
                interactive: false
            }

            SettingsRow {
                icon: "widgets"
                label: "Quickshell"
                value: root.say(Device.quickshellVersion)
                interactive: false
            }

            SettingsRow {
                icon: "deployed_code"
                label: "banditshell"
                value: Device.version ? `${Device.version} · ${Device.commitDate}` : "unknown"
                interactive: false
            }

            SettingsRow {
                icon: "schedule"
                label: "Uptime"
                value: Device.uptime
                interactive: false
            }
        }

        SettingsCard {
            title: "Battery"
            visible: Battery.available

            SettingsRow {
                icon: Battery.icon()
                label: "Charge"
                value: `${Battery.percent}% · ${Battery.state}`
                interactive: false
            }

            SettingsRow {
                visible: Battery.healthKnown
                icon: "favorite"
                label: "Health"
                value: `${Math.round(Battery.health)}%`
                detail: `${Battery.capacity.toFixed(1)} of ${Battery.designCapacity.toFixed(1)} Wh designed · ${Battery.cycles} cycles`
                interactive: false
            }
        }

        SettingsCard {
            title: "Screens"

            Repeater {
                model: Quickshell.screens

                delegate: SettingsRow {
                    id: screen

                    required property var modelData

                    readonly property real density: screen.modelData.physicalPixelDensity ?? 0
                    readonly property real mmW: screen.density > 0 ? screen.modelData.width / screen.density : 0
                    readonly property real mmH: screen.density > 0 ? screen.modelData.height / screen.density : 0
                    readonly property real inches: mmW > 0 && mmH > 0 ? Math.sqrt(mmW * mmW + mmH * mmH) / 25.4 : 0

                    icon: "monitor"
                    label: screen.modelData.name

                    value: `${Math.round(screen.modelData.width * screen.modelData.devicePixelRatio)} × ${Math.round(screen.modelData.height * screen.modelData.devicePixelRatio)}`
                    detail: {
                        const bits = [screen.modelData.model || "unknown model"];
                        if (screen.inches > 0)
                            bits.push(`${screen.inches.toFixed(1)}"`);
                        bits.push(`scale ${screen.modelData.devicePixelRatio}`);
                        return bits.join(" · ");
                    }
                    interactive: false
                }
            }
        }
    }
}
