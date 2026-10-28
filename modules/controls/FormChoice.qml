import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string label: ""
    property alias options: pick.options
    property alias current: pick.current

    signal picked(int index)

    implicitHeight: visible ? pick.implicitHeight + Appearance.padding.small * 2 : 0

    StyledText {
        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        text: root.label
        color: Appearance.colour.textDim
    }

    Segments {
        id: pick

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        onPicked: i => root.picked(i)
    }
}
