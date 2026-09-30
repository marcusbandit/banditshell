pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components

Column {
    id: root

    property var menu: null

    spacing: 0

    property int opened: -1

    QsMenuOpener {
        id: opener

        menu: root.menu
    }

    readonly property var entries: [...opener.children.values]

    Repeater {
        model: ScriptModel {
            values: root.entries
        }

        delegate: Column {
            id: entry

            required property var modelData
            required property int index

            readonly property bool divider: entry.modelData?.isSeparator ?? false
            readonly property bool branch: entry.modelData?.hasChildren ?? false
            readonly property bool showing: root.opened === entry.index
            readonly property int button: entry.modelData?.buttonType ?? QsMenuButtonType.None
            readonly property bool ticked: entry.modelData?.checkState === Qt.Checked

            width: parent.width
            spacing: 0

            Separator {
                width: entry.width
                visible: entry.divider
            }

            MenuRow {
                width: entry.width
                visible: !entry.divider

                iconSource: entry.modelData?.icon ?? ""
                label: entry.modelData?.text ?? ""
                interactive: entry.modelData?.enabled ?? false
                selected: entry.ticked && entry.button !== QsMenuButtonType.None

                onActivated: {
                    if (entry.branch)
                        root.opened = entry.showing ? -1 : entry.index;
                    else
                        entry.modelData?.triggered();
                }

                Toggle {
                    visible: entry.button === QsMenuButtonType.CheckBox
                    checked: entry.ticked
                    onToggled: entry.modelData?.triggered()
                }

                Icon {
                    visible: entry.button === QsMenuButtonType.RadioButton
                    name: entry.ticked ? "radio_button_checked" : "radio_button_unchecked"
                    color: entry.ticked ? Appearance.colour.accent : Appearance.colour.textFaint
                }

                Expander {
                    visible: entry.branch
                    open: entry.showing
                    tip: "more"
                    onToggled: root.opened = entry.showing ? -1 : entry.index
                }
            }

            MenuLayer {
                width: entry.width
                open: entry.showing

                Loader {
                    width: parent.width
                    source: entry.showing ? "TrayEntries.qml" : ""

                    onLoaded: {
                        item.menu = Qt.binding(() => entry.modelData);
                        item.width = Qt.binding(() => width);
                    }
                }
            }
        }
    }
}
