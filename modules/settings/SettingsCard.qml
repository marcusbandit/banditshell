import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property string title: ""

    default property alias rows: body.data

    width: parent ? parent.width : 0
    spacing: Appearance.padding.small

    StyledText {
        visible: !!root.title
        text: root.title.toUpperCase()
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        font.letterSpacing: Appearance.font.stem
        leftPadding: Appearance.padding.small
    }

    G2Rect {
        width: parent.width
        height: body.implicitHeight
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill

        Column {
            id: body

            width: parent.width
        }
    }
}
