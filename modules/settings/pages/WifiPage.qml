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
            title: "Wi-Fi"

            SettingsRow {
                icon: Network.wifiIcon()
                label: "Wi-Fi"

                detail: !Network.available ? "no adapter" : !Network.hardwareEnabled ? "blocked by hardware switch" : Network.connected ? `connected to ${Network.activeName}` : Network.enabled ? "on, not connected" : "off"
                interactive: Network.available && Network.hardwareEnabled
                onActivated: Network.setEnabled(!Network.enabled)

                Toggle {
                    checked: Network.enabled
                    onToggled: Network.setEnabled(!Network.enabled)
                }
            }

            SettingsRow {
                visible: Network.wiredAvailable
                icon: "lan"
                label: "Wired"
                value: Network.wiredLabel
                detail: !Network.wiredManaged ? "nothing is driving it" : Network.wiredConnecting ? "connecting" : Network.wiredConnected ? "connected" : "no cable"

                interactive: false
            }
        }

        SettingsGroup {
            heading: "Networks"

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

                    source: Qt.resolvedUrl("../../menu/content/NetworkMenu.qml")

                    onLoaded: menu.item.showing = Qt.binding(() => root.visible)
                }
            }
        }
    }
}
