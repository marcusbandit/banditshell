pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

// Power, as a menu: the same choices the right-edge panel offers, in the shape a
// menu takes. Parked for the dashboard; the panel is what a keybind opens.
//
// Every entry asks first. Not a modal, not an "are you sure" that trains people
// to click yes: the row itself becomes the confirmation, in place, and anything
// else you do cancels it. A power menu that acts on the first click is one
// mis-hover away from ending your session, and this one opens on hover.
//
// WHICH actions exist, and what each one runs, is in services/Power.qml. This
// file decides only what asking looks like here.
Column {
    id: root

    property string arming: ""

    readonly property var actions: Power.actions

    spacing: Appearance.padding.small

    // Disarm as soon as attention moves elsewhere.
    Component.onDestruction: root.arming = ""

    function activate(entry: var): void {
        if (entry.safe || root.arming === entry.key) {
            Power.run(entry);
            root.arming = "";
        } else {
            root.arming = entry.key;
        }
    }

    Repeater {
        model: root.actions

        delegate: MenuRow {
            id: row

            required property var modelData

            readonly property bool armed: root.arming === modelData.key

            width: root.width
            icon: row.armed ? "check" : modelData.icon
            label: row.armed ? `${modelData.label}, really?` : modelData.label
            detail: row.armed ? "press again" : modelData.detail
            selected: row.armed

            onActivated: root.activate(row.modelData)
        }
    }

    StyledText {
        text: "hover elsewhere to cancel"
        visible: !!root.arming
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
    }
}
