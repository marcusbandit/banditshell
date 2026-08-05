pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.config
import qs.components

// SOMEBODY ELSE'S MENU, drawn as one of ours.
//
// The rows here are not written, they arrive: a tray item's menu is an arbitrary
// application's own, built on demand and sent over a bus, so what this file
// knows is not what a row says but what a row of theirs looks like in here. A
// check item becomes the shell's switch, a radio becomes the shell's dot, a
// separator becomes the shell's rule, and a submenu becomes the shell's layer.
// Spotify's menu and the Bluetooth menu come out recognisably the same object.
//
// IT CONTAINS ITSELF, which is the only honest way to draw a tree of unknown
// depth: a submenu is a menu, so its rows are these rows, and there is no
// second copy of this file to disagree with the first. Safe from recursing
// forever because the nested one is behind a Loader that is not active until the
// layer it lives in is unrolled.
//
// ASKED FOR ONLY WHEN OPENED. The protocol has the application build a menu when
// something requests it, and QsMenuOpener is that request. One per level, none
// of them alive until you have gone through, so opening a tray icon does not
// wake every nested menu the application has.
Column {
    id: root

    // The handle to draw. A tray item's `menu`, or an entry from one of these.
    property var menu: null

    spacing: 0

    // Which submenu is unrolled, by index, ONE at a time and per level. Anything
    // else is a settings page that grows while you read it.
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

            // A rule the application asked for, in the shell's own weight.
            Separator {
                width: entry.width
                visible: entry.divider
            }

            MenuRow {
                width: entry.width
                visible: !entry.divider

                // The application's own artwork, when it sent any. A brand
                // palette is not a problem here the way it is in the bar: there
                // is one icon per line, beside a label, rather than a column of
                // them being read as a group.
                iconSource: entry.modelData?.icon ?? ""
                label: entry.modelData?.text ?? ""
                interactive: entry.modelData?.enabled ?? false
                selected: entry.ticked && entry.button !== QsMenuButtonType.None

                // A BRANCH OPENS, A LEAF ACTS, and the whole row is the target
                // for either: the chevron says which of the two this is, it is
                // not the only part of the row that can be hit.
                onActivated: {
                    if (entry.branch)
                        root.opened = entry.showing ? -1 : entry.index;
                    else
                        entry.modelData?.triggered();
                }

                // The state, in whichever of the two shapes the application
                // asked for. A radio is one of a set and a switch is not, so
                // they cannot both be a switch: a column of switches that turn
                // each other off is a column that looks broken while it works.
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

            // WHAT IS THROUGH THERE, which is another one of these.
            //
            // BY URL, not as a Component. QML resolves types when it compiles a
            // file, so a file naming itself is a cycle it refuses outright, even
            // behind a Loader that would never have run: "TrayEntries is
            // instantiated recursively". A source url is resolved when the
            // loader activates, which is the moment the tree stops being
            // hypothetical, so the recursion is bounded by how deep you have
            // actually gone rather than by how deep it could go.
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
