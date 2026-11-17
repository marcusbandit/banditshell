pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property var entry: null

    readonly property var facts: root.entry?.facts ?? []
    readonly property string text: root.entry?.text ?? ""

    readonly property real labelWidth: Math.min(Math.round(body.width * 0.45), Math.ceil(labels.implicitWidth))

    width: Math.round(Appearance.sizes.launcherWidth * 0.55)
    height: Math.min(body.implicitHeight + Appearance.padding.normal * 2, Math.round(Appearance.sizes.launcherWidth * 0.8))
    clip: true

    Column {
        id: labels

        visible: false

        Repeater {
            model: root.facts

            StyledText {
                required property var modelData

                text: modelData.label
                font.pixelSize: Appearance.font.size.small
            }
        }
    }

    Column {
        id: body

        x: Appearance.padding.normal
        y: Appearance.padding.normal
        width: root.width - Appearance.padding.normal * 2
        spacing: Appearance.padding.small

        StyledText {
            width: body.width
            visible: root.text !== ""
            bottomPadding: Appearance.padding.small
            text: root.text
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textDim
            wrapMode: Text.Wrap
            maximumLineCount: 32
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        Repeater {
            model: root.facts

            delegate: Row {
                id: fact

                required property var modelData

                width: body.width
                spacing: Appearance.padding.normal

                StyledText {
                    width: root.labelWidth
                    text: fact.modelData.label
                    font.pixelSize: Appearance.font.size.small
                    color: Appearance.colour.textFaint
                    elide: Text.ElideRight
                }

                StyledText {
                    width: body.width - root.labelWidth - Appearance.padding.normal
                    text: fact.modelData.value
                    font.pixelSize: Appearance.font.size.small
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                }
            }
        }
    }
}
