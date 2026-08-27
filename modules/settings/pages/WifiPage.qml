pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// WI-FI: the network menu, with room to breathe.
//
// Settings has everything, the way a phone's does, and the bar menu is the same
// questions asked in a hurry. So this page does not rewrite the menu: it
// embeds NetworkMenu whole, and puts above it the one card the menu does not
// lead with, the machine's two ways onto the network as plain facts with the
// radio's master switch beside them.
//
// THE WIRED ROW IS THE ONE THING THE MENU WILL NOT SAY. The menu shows a port
// only while a cable is doing something (Network.wiredShowing), which is right
// for a hover panel and wrong for a settings page: "there is a port and nothing
// is in it" is a fact you come to a settings page to check. So it is here
// whenever the machine has one.
//
// WHAT THE MENU NEEDED TO BE EMBEDDED. Two things, both of which MenuPanel
// would otherwise set on it (the Loader in MenuPanel.qml binds them onLoaded):
// a width, which it lays every row out against, and `showing`, which is how it
// is told whether anybody is looking. `showing` is bound to this page's
// visibility rather than to true because the menu switches real things off
// it: the passphrase behind the share card is fetched while `showing` holds
// (Network.share), the camera Loader is active only while it holds, and a
// half-typed password and any unrolled layer are put away when it drops. A
// settings page that is built and kept behind another page must not keep a
// secret in memory or a lens warm.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        SettingsCard {
            title: "Wi-Fi"

            SettingsRow {
                icon: Network.wifiIcon()
                label: "Wi-Fi"
                // The hardware switch and a missing adapter come first, since a
                // toggle that flips and changes nothing is worse than a row
                // that says why it cannot.
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
                // A fact, not a switch: the port's own settings are in the
                // menu below, under the row that appears once the cable is in.
                interactive: false
            }
        }

        // The menu, in a card of its own so it reads as part of the page rather
        // than a panel pasted onto one. Same eyebrow as SettingsCard's title,
        // same material, and a small inset so the menu's own row highlights
        // sit inside the card's corners instead of on them.
        Column {
            width: parent.width
            spacing: Appearance.padding.small

            StyledText {
                text: "Networks"
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

                    source: Qt.resolvedUrl("../../menu/content/NetworkMenu.qml")

                    // The menu's `showing` follows the page: it drives the radio
                    // (see the menu), and a page that is not on screen should not.
                    onLoaded: menu.item.showing = Qt.binding(() => root.visible)
                }
            }
        }
    }
}
