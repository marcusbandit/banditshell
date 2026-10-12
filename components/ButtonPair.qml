pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Row {
    id: root

    property var actions: []

    property int primary: 0

    signal triggered(int index)

    spacing: Appearance.button.seam

    Repeater {
        model: root.actions

        delegate: Button {
            id: member

            required property int index
            required property var modelData

            text: member.modelData.text ?? ""
            icon: member.modelData.icon ?? ""
            style: member.index === root.primary ? "filled" : "tonal"
            radiusLeft: member.index > 0 ? Appearance.button.seamRadius : -1
            radiusRight: member.index < root.actions.length - 1 ? Appearance.button.seamRadius : -1

            onClicked: root.triggered(member.index)
        }
    }
}
