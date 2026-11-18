pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components

Column {
    id: root

    property var facts: []
    property real textSize: Appearance.font.size.normal

    readonly property real labelWidth: {
        let widest = 0;
        for (const fact of root.facts)
            widest = Math.max(widest, metrics.advanceWidth(fact[0]));
        return Math.ceil(widest);
    }

    spacing: Appearance.padding.small

    FontMetrics {
        id: metrics

        font.family: Appearance.font.family
        font.pixelSize: root.textSize
    }

    Repeater {
        model: root.facts

        Item {
            id: fact

            required property var modelData

            width: root.width
            height: value.implicitHeight

            StyledText {
                text: fact.modelData[0]
                font.pixelSize: root.textSize
                color: Appearance.colour.textFaint
            }

            StyledText {
                id: value

                x: root.labelWidth + Appearance.padding.large
                width: root.width - x
                text: fact.modelData[1]
                font.pixelSize: root.textSize
                color: fact.modelData[2] === "alarm" ? Appearance.colour.alarm : fact.modelData[2] === "dim" ? Appearance.colour.textDim : Appearance.colour.text
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
    }
}
