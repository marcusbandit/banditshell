import QtQuick
import qs.config

Item {
    id: root

    default property alias content: column.data
    property real bottomPad: Appearance.padding.large
    readonly property real stageHeight: column.implicitHeight + Appearance.padding.large + root.bottomPad

    Column {
        id: column

        anchors.horizontalCenter: parent.horizontalCenter
        y: (root.height - column.implicitHeight - Appearance.padding.large - root.bottomPad) / 2 + Appearance.padding.large
        width: root.width - Appearance.padding.large * 2
        spacing: Appearance.padding.small
    }
}
