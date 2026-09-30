pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property string heading: ""
    default property alias body: bodyCol.data

    width: parent ? parent.width : 0
    spacing: Appearance.padding.small

    StyledText {
        visible: !!root.heading
        width: parent.width
        text: root.heading.toUpperCase()
        color: Appearance.colour.textFaint
        font.pixelSize: Appearance.font.size.small
        font.letterSpacing: Appearance.font.stem
        leftPadding: Appearance.padding.small
    }

    Column {
        id: bodyCol

        width: parent.width
        spacing: Appearance.padding.normal
    }
}
