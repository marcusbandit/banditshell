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

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.huge

        SettingsCard {
            visible: Battery.available
            title: "Battery"

            SettingsRow {
                icon: Battery.icon()
                label: "Charge"
                value: `${Battery.percent}%`

                detail: Battery.timeLabel() ? `${Battery.state}, ${Battery.timeLabel()}` : Battery.state
                interactive: false
            }

            SettingsRow {

                visible: Battery.healthKnown
                icon: "monitor_heart"
                label: "Health"
                value: `${Math.round(Battery.health)}%`
                detail: {
                    const bits = [];
                    if (Battery.designCapacity > 0)
                        bits.push(`charges to ${Battery.capacity.toFixed(1)} Wh of ${Battery.designCapacity.toFixed(1)} Wh new`);
                    if (Battery.cycles > 0)
                        bits.push(`${Battery.cycles} cycles`);
                    return bits.join(", ");
                }
                interactive: false
            }
        }

        SettingsGroup {
            visible: Battery.available
            heading: "History"

            G2Rect {
                width: parent.width
                height: menu.implicitHeight + Appearance.padding.small * 2
                radius: Appearance.rounding.normal
                color: Appearance.colour.fill

                Loader {
                    id: menu

                    x: Appearance.padding.small
                    y: Appearance.padding.small
                    width: parent.width - Appearance.padding.small * 2

                    source: Qt.resolvedUrl("../../menu/content/BatteryMenu.qml")
                }
            }
        }
    }
}
