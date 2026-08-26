pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services

// DEVICE: the machine the shell is running on.
//
// NOTHING ON THIS PAGE IS A SETTING. It is the page a phone calls "About
// phone", split off from About so that About can be about the shell: what
// version is running and where its files are is one subject, what processor
// is under it and how warm it is are another, and a page that mixed the two
// would have the kernel version sitting between a git hash and a config path.
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
        spacing: Appearance.padding.small / 2

        // ---------------------------------------------------- this machine

        StyledText {
            text: "This machine"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
        }

        // The hostname is the label rather than a detail: it is the name of
        // the thing this whole page describes.
        MenuRow {
            width: list.width
            icon: "computer"
            label: Device.hostname || "this machine"
            detail: Device.os
            interactive: false
        }

        // Stacked, not inline: a processor's marketing name is a sentence.
        MenuRow {
            width: list.width
            icon: "memory"
            label: "Processor"
            detail: Device.cpu
            interactive: false
        }

        MenuRow {
            width: list.width
            icon: "terminal"
            label: "Kernel"
            detail: Device.kernel
            inlineDetail: true
            interactive: false
        }

        MenuRow {
            width: list.width
            icon: "schedule"
            label: "Uptime"
            detail: Device.uptime
            inlineDetail: true
            interactive: false
        }

        // ------------------------------------------------------- right now

        StyledText {
            text: "Right now"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        MenuRow {
            width: list.width
            icon: "speed"
            label: "Processor load"
            detail: `${Math.round(SysInfo.cpu * 100)}%`
            inlineDetail: true
            interactive: false
        }

        MenuRow {
            width: list.width
            icon: "memory_alt"
            label: "Memory"
            detail: `${SysInfo.memoryUsedGb.toFixed(1)} of ${SysInfo.memoryTotalGb.toFixed(1)} GB`
            inlineDetail: true
            interactive: false
        }

        // SysInfo reports 0 when no thermal zone made sense, and "0 °C" is a
        // reading nobody should be shown.
        MenuRow {
            width: list.width
            icon: "device_thermostat"
            label: "Temperature"
            detail: `${Math.round(SysInfo.temperature)} °C`
            inlineDetail: true
            interactive: false
            visible: SysInfo.temperature > 0
        }

        // --------------------------------------------------------- battery

        // The eyebrow and its rows hide together, so a desktop does not get a
        // heading with nothing under it.
        Column {
            width: list.width
            spacing: list.spacing
            visible: Battery.available

            StyledText {
                text: "Battery"
                color: Appearance.colour.textFaint
                font.pixelSize: Appearance.font.size.small
                bottomPadding: Appearance.padding.small
                topPadding: Appearance.padding.normal
            }

            MenuRow {
                width: list.width
                icon: "battery_full"
                label: "Charge"
                detail: `${Battery.percent}% · ${Battery.state}`
                inlineDetail: true
                interactive: false
            }

            // Health is what it charges to now over what it charged to new;
            // Battery explains where the number comes from. Cycles only when
            // sysfs actually has a count, because "0 cycles" on a two-year-old
            // cell is a missing number, not a fact.
            MenuRow {
                width: list.width
                icon: "favorite"
                label: "Health"
                detail: `${Math.round(Battery.health)}% of design capacity` + (Battery.cycles > 0 ? ` · ${Battery.cycles} cycles` : "")
                interactive: false
                visible: Battery.healthKnown
            }
        }

        // --------------------------------------------------------- screens

        // Connected outputs in plug order, which is fine here because this
        // page is about the hardware: which screen owns which workspaces is
        // ScreensPage's question, and its rows come from the order instead.
        StyledText {
            text: "Screens"
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            bottomPadding: Appearance.padding.small
            topPadding: Appearance.padding.normal
        }

        Repeater {
            model: Quickshell.screens

            delegate: MenuRow {
                id: screen

                required property var modelData

                width: list.width
                icon: "monitor"
                label: screen.modelData.name
                // The mode rather than the logical size: through the device
                // pixel ratio it is the resolution written on the box, see
                // ScreensPage for the same conversion.
                detail: `${Math.round(screen.modelData.width * screen.modelData.devicePixelRatio)} × ${Math.round(screen.modelData.height * screen.modelData.devicePixelRatio)} · ${screen.modelData.model || "unknown model"}`
                interactive: false
            }
        }
    }
}
