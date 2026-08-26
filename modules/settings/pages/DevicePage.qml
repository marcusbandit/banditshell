pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// DEVICE: the machine the shell is running on.
//
// NOTHING ON THIS PAGE IS A SETTING. It is the page a phone calls "About
// phone", split off from About so that About can be about the shell: what
// version is running and where its files are is one subject, what board is
// under it and how warm the processor is are another, and a page that mixed
// the two would have the firmware date sitting between a git hash and a
// config path.
//
// EVERYTHING, IN CARDS, NOTHING FOLDED AWAY. A summary with a "more" behind it
// is the right shape for a hover menu and the wrong one here: the reason to
// open this page is to read the one line you came for, and a page that made
// you guess which card hides it has failed at the only thing it does. So one
// card per subject, one row per fact, every row saying its whole sentence.
//
// Every row is inert. A hostname is not a thing to flip, and a row that lit on
// hover and swallowed the press would promise something it cannot do; see
// ScreensPage for the same argument about monitors.
//
// The live numbers are sampled only while the page is on screen. SysInfo and
// Device both ref-count their watchers, so this page asks on the way in and
// lets go on the way out, and a settings window left open on another page
// costs nothing per second.
//
// WIDTH COMES FROM THE FACE, like every page here: fill what the pager hands
// you and ask only for height.
Item {
    id: root

    implicitHeight: list.implicitHeight

    // A fact not yet known, or not knowable on this machine, is said so. An
    // empty value cell reads as the page having broken, and "unknown" reads
    // as the machine not saying, which is the truth.
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
        spacing: Appearance.padding.large

        SettingsCard {
            title: "This machine"

            // The hostname is the label rather than a value: it is the name
            // of the thing this whole page describes. The make and model sit
            // under it because that is what a person would say next.
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

            // A processor's marketing name is a sentence; SettingsRow puts a
            // long value under the label on its own.
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

            // SysInfo reports 0 when no thermal zone made sense, and "0 °C"
            // is a reading nobody should be shown.
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

            // A machine without swap has nothing to say here, and "0.0 GB"
            // would read as a swap that is full.
            SettingsRow {
                visible: Device.swapTotalGb > 0
                icon: "swap_horiz"
                label: "Swap"
                value: `${Device.swapTotalGb.toFixed(1)} GB`
                interactive: false
            }
        }

        // One row per adapter, so a laptop with two shows two. The card goes
        // with them: no lspci means no rows, and a heading over nothing is
        // worse than no heading.
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

            // The model is the name a person knows the disk by and the device
            // node is how the system does; a disk with no model (a USB bridge
            // that hides it) falls back to the node so the row still has a
            // label.
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

        // The card and its rows hide together, so a desktop does not get a
        // heading with nothing under it.
        SettingsCard {
            title: "Battery"
            visible: Battery.available

            SettingsRow {
                icon: Battery.icon()
                label: "Charge"
                value: `${Battery.percent}% · ${Battery.state}`
                interactive: false
            }

            // Health is what it charges to now over what it charged to new;
            // Battery explains where the number comes from.
            SettingsRow {
                visible: Battery.healthKnown
                icon: "favorite"
                label: "Health"
                value: `${Math.round(Battery.health)}%`
                detail: `${Battery.capacity.toFixed(1)} of ${Battery.designCapacity.toFixed(1)} Wh designed · ${Battery.cycles} cycles`
                interactive: false
            }
        }

        // Connected outputs in plug order, which is fine here because this
        // page is about the hardware: which screen owns which workspaces is
        // ScreensPage's question, and its rows come from the order instead.
        SettingsCard {
            title: "Screens"

            Repeater {
                model: Quickshell.screens

                delegate: SettingsRow {
                    id: screen

                    required property var modelData

                    // A diagonal is the one size anybody quotes a monitor by.
                    // ShellScreen does not hand over the panel's millimetres,
                    // only `physicalPixelDensity`, which Qt works out as the
                    // LOGICAL size over the EDID's physical size, so the edges
                    // come back out of it by dividing the logical size, not
                    // the mode. A screen whose EDID said nothing reports a
                    // density Qt made up, so zero is the guard and the row
                    // just leaves the inches out.
                    readonly property real density: screen.modelData.physicalPixelDensity ?? 0
                    readonly property real mmW: screen.density > 0 ? screen.modelData.width / screen.density : 0
                    readonly property real mmH: screen.density > 0 ? screen.modelData.height / screen.density : 0
                    readonly property real inches: mmW > 0 && mmH > 0 ? Math.sqrt(mmW * mmW + mmH * mmH) / 25.4 : 0

                    icon: "monitor"
                    label: screen.modelData.name
                    // The mode rather than the logical size: through the
                    // device pixel ratio it is the resolution written on the
                    // box, see ScreensPage for the same conversion.
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
