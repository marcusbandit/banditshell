pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import "../../../services/dictionary.js" as Words

Column {
    id: root

    property var sense: ({})
    property bool related: false

    spacing: Appearance.padding.small

    StyledText {
        width: root.width
        text: Words.senseLine(root.sense.part ?? "", root.sense.text ?? "")
        textFormat: Text.StyledText
        font.pixelSize: Appearance.font.size.normal
        wrapMode: Text.Wrap
    }

    Repeater {
        model: root.sense.examples ?? []

        delegate: Item {
            id: quote

            required property string modelData

            width: root.width
            height: said.implicitHeight + Appearance.padding.small * 2

            Rectangle {
                width: Appearance.sizes.seam
                height: parent.height
                color: Appearance.colour.textFaint
            }

            StyledText {
                id: said

                x: Appearance.padding.normal + Appearance.sizes.seam
                y: Appearance.padding.small
                width: quote.width - x
                text: quote.modelData
                font.pixelSize: Appearance.font.size.normal
                color: Appearance.colour.textDim
                wrapMode: Text.Wrap
            }
        }
    }

    StyledText {
        width: root.width
        visible: root.related && (root.sense.synonyms ?? []).length > 0
        text: `Similar: ${(root.sense.synonyms ?? []).join(", ")}`
        color: Appearance.colour.textFaint
        wrapMode: Text.Wrap
    }

    StyledText {
        width: root.width
        visible: root.related && (root.sense.antonyms ?? []).length > 0
        text: `Opposite: ${(root.sense.antonyms ?? []).join(", ")}`
        color: Appearance.colour.textFaint
        wrapMode: Text.Wrap
    }
}
