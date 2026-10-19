import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property string word: ""
    property string phonetic: ""
    property string note: ""

    spacing: Appearance.padding.hair

    Flow {
        width: root.width
        spacing: Appearance.padding.normal

        StyledText {
            id: headword

            text: root.word
            font.pixelSize: Appearance.font.size.large
            font.bold: true
        }

        StyledText {
            visible: text !== ""
            height: headword.height
            verticalAlignment: Text.AlignVCenter
            text: root.phonetic
            font.pixelSize: Appearance.font.size.normal
            color: Appearance.colour.textDim
        }
    }

    StyledText {
        width: root.width
        visible: text !== ""
        text: root.note
        color: Appearance.colour.textFaint
        wrapMode: Text.Wrap
    }
}
