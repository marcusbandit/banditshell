import QtQuick
import qs.config
import qs.components

Flow {
    id: root

    property var files: []

    signal picked(string path)

    width: parent.width
    leftPadding: Appearance.padding.normal
    rightPadding: Appearance.padding.normal
    spacing: Appearance.padding.small
    visible: root.files.length > 0

    Repeater {
        model: root.files

        Button {
            required property string modelData

            size: 0
            style: "bare"
            icon: "description"
            text: modelData.slice(modelData.lastIndexOf("/") + 1)
            onClicked: root.picked(modelData)
        }
    }
}
