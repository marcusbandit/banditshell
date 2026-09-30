pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.settings

Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

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

        SettingsGroup {
            heading: "Devices"

            SquircleRect {
                width: parent.width
                height: menu.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                Loader {
                    id: menu

                    x: Appearance.padding.small
                    y: Appearance.padding.small
                    width: parent.width - Appearance.padding.small * 2

                    source: Qt.resolvedUrl("../../menu/content/BluetoothMenu.qml")

                    onLoaded: menu.item.showing = Qt.binding(() => root.visible)
                }
            }
        }
    }
}
