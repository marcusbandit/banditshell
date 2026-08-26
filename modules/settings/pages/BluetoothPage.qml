pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// BLUETOOTH: the bluetooth menu, with room to breathe.
//
// Same shape as WifiPage: the bar menu embedded whole, and above it the one
// card of page-level facts the menu keeps a layer down. The adapter's own name
// is the thing here; the menu only says it inside "adapter settings", and on a
// page whose job is to answer "which radio is this" it belongs on the first
// line.
//
// WHAT THE MENU NEEDED TO BE EMBEDDED: a width and `showing`, the two things
// MenuPanel's Loader binds onto it. `showing` follows this page's visibility
// rather than being pinned true because the menu derives `discovering` from
// it: discovery runs only while the pairing layer is open AND somebody is
// looking, and discovery is the machine broadcasting itself to the building.
// A page kept built behind another page must not leave that running.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        SettingsCard {
            title: "Bluetooth"

            SettingsRow {
                icon: Bluetooth.statusIcon()
                label: "Bluetooth"
                value: Bluetooth.adapterName
                detail: !Bluetooth.available ? "no adapter" : Bluetooth.anyConnected ? `${Bluetooth.connectedDevices.length} connected` : Bluetooth.enabled ? "on" : "off"
                interactive: Bluetooth.available
                onActivated: Bluetooth.setEnabled(!Bluetooth.enabled)

                Toggle {
                    checked: Bluetooth.enabled
                    onToggled: Bluetooth.setEnabled(!Bluetooth.enabled)
                }
            }
        }

        Column {
            width: parent.width
            spacing: Appearance.padding.small

            StyledText {
                text: "Devices"
                color: Appearance.colour.textFaint
                leftPadding: Appearance.padding.small
            }

            G2Rect {
                width: parent.width
                height: menu.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                // BY FILE, the way MenuPanel loads it: modules/menu/content is a
                // folder of pages the panel picks by name, not a module.
                Loader {
                    id: menu

                    x: Appearance.padding.small
                    y: Appearance.padding.small
                    width: parent.width - Appearance.padding.small * 2

                    source: Qt.resolvedUrl("../../menu/content/BluetoothMenu.qml")

                    // The menu's `showing` follows the page: it drives the radio
                    // (see the menu), and a page that is not on screen should not.
                    onLoaded: menu.item.showing = Qt.binding(() => root.visible)
                }
            }
        }
    }
}
