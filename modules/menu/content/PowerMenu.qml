pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    property string arming: ""

    readonly property var actions: Power.actions

    spacing: Appearance.padding.small

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
