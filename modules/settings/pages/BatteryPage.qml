pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components
import qs.services
import qs.modules.settings

// BATTERY: the battery menu, with room to breathe.
//
// Above the menu, the two numbers a settings page is opened for, as rows that
// can be read without decoding a tank: how full, and how worn. The menu draws
// the same facts, but it draws them for a glance at a gauge, and the health
// figure in particular sits under a separator at the bottom of it. Here it is
// the second line.
//
// THIS PAGE DOES HAVE A "NO BATTERY" STATE, which the menu pointedly does not.
// The menu is only reachable through a gauge that exists only on a laptop; a
// settings page is reachable from a list of pages on every machine, and a page
// that is simply empty on a desktop reads as broken. One inert row saying why
// is the difference.
//
// WHAT THE MENU NEEDED TO BE EMBEDDED: only a width. BatteryMenu has no
// `showing`; UPower and the health log are Battery's, and run whether or not
// anything is drawing them.
Item {
    id: root

    implicitHeight: list.implicitHeight

    Column {
        id: list

        width: parent.width
        spacing: Appearance.padding.large

        SettingsCard {
            visible: !Battery.available

            SettingsRow {
                icon: "battery_unknown"
                label: "No battery"
                detail: "this machine runs from the wall"
                interactive: false
            }
        }

        SettingsCard {
            visible: Battery.available
            title: "Battery"

            SettingsRow {
                icon: Battery.icon()
                label: "Charge"
                value: `${Battery.percent}%`
                // The state, then the estimate when there is one. timeLabel
                // already says "2h 10m left" or "to full" and stays quiet while
                // the estimate is not there yet, so it is not reformatted here.
                detail: Battery.timeLabel() ? `${Battery.state}, ${Battery.timeLabel()}` : Battery.state
                interactive: false
            }

            SettingsRow {
                // Hidden rather than "0%" when there is no design figure to
                // measure against; a health number with nothing behind it is
                // worse than none.
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

        Column {
            visible: Battery.available
            width: parent.width
            spacing: Appearance.padding.small

            StyledText {
                text: "History"
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

                    source: Qt.resolvedUrl("../../menu/content/BatteryMenu.qml")
                }
            }
        }
    }
}
