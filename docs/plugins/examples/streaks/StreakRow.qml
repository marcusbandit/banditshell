import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var row: null

    readonly property var props: root.row?.props ?? ({})
    readonly property var days: root.props.days ?? []
    readonly property bool selected: root.row?.selected ?? false

    Icon {
        id: mark

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        size: Appearance.sizes.launcherIcon
        name: root.props.done ? "check_circle" : "radio_button_unchecked"
        fill: root.props.done ? 1 : 0
        color: root.props.done ? Appearance.colour.accent : root.selected ? Appearance.colour.text : Appearance.colour.textDim
    }

    StyledText {
        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: count.left
        anchors.rightMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter
        text: root.row?.item?.title ?? ""
        font.pixelSize: Appearance.font.size.normal
        color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
        elide: Text.ElideRight
    }

    StyledText {
        id: count

        anchors.right: dots.left
        anchors.rightMargin: Appearance.padding.large
        anchors.verticalCenter: parent.verticalCenter
        text: root.props.streak ? `${root.props.streak} days in a row` : "no streak yet"
        font.pixelSize: Appearance.font.size.small
        color: Appearance.colour.textFaint
    }

    Row {
        id: dots

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.small / 2

        Repeater {
            model: root.days

            delegate: SquircleRect {
                required property bool modelData
                required property int index

                width: Appearance.font.size.small
                height: width
                radius: Appearance.rounding.small
                color: modelData ? Appearance.colour.accent : Appearance.colour.fillStrong
                stroke: index === root.days.length - 1 ? Appearance.colour.textFaint : "transparent"
                strokeWidth: Appearance.sizes.seam
            }
        }
    }
}
