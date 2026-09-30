import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon
    property bool active: false
    property bool alert: false
    property bool alarm: false
    property bool available: true

    property Component mark: null

    signal activated

    readonly property bool hovered: mouse.containsMouse

    readonly property color markColour: !root.available ? Appearance.colour.textFaint : root.alarm ? Appearance.colour.alarm : root.alert ? Appearance.colour.accent : root.hovered || root.active ? Appearance.colour.text : Appearance.colour.textDim

    implicitWidth: drawing.width
    implicitHeight: drawing.height

    Item {
        id: drawing

        anchors.centerIn: parent
        width: Appearance.sizes.statusSlot
        height: Appearance.sizes.statusSlot

        Icon {
            anchors.centerIn: parent
            visible: !root.mark
            name: root.icon
            color: root.markColour

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.anim.fast
                }
            }
        }

        Loader {
            anchors.centerIn: parent
            active: !!root.mark
            sourceComponent: root.mark

            onLoaded: item.colour = Qt.binding(() => root.markColour)
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.topMargin: -Appearance.sizes.statusGap / 2
        anchors.bottomMargin: -Appearance.sizes.statusGap / 2
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

}
