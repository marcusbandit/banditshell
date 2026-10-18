import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property int number: 1
    property var sense: ({})

    readonly property real numberWidth: Appearance.font.size.small * 2

    implicitHeight: lines.implicitHeight
    height: implicitHeight

    StyledText {
        width: root.numberWidth
        text: root.number
        color: Appearance.colour.textFaint
    }

    Column {
        id: lines

        x: root.numberWidth
        width: root.width - root.numberWidth
        spacing: Appearance.padding.hair

        StyledText {
            width: parent.width
            text: root.sense.part ? `${root.sense.part} · ${root.sense.text}` : root.sense.text
            wrapMode: Text.Wrap
        }

        Repeater {
            model: root.sense.examples ?? []

            delegate: StyledText {
                required property string modelData

                width: lines.width
                text: `“${modelData}”`
                color: Appearance.colour.textDim
                wrapMode: Text.Wrap
            }
        }

        StyledText {
            width: parent.width
            visible: (root.sense.synonyms ?? []).length > 0
            text: `Similar: ${(root.sense.synonyms ?? []).join(", ")}`
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }

        StyledText {
            width: parent.width
            visible: (root.sense.antonyms ?? []).length > 0
            text: `Opposite: ${(root.sense.antonyms ?? []).join(", ")}`
            color: Appearance.colour.textFaint
            wrapMode: Text.Wrap
        }
    }
}
