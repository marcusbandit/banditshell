pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services
import qs.modules.controls

Column {
    id: root

    readonly property var item: PluginStatus.menuItem

    spacing: Appearance.padding.small

    StyledText {
        width: parent.width
        leftPadding: Appearance.padding.normal
        rightPadding: Appearance.padding.normal
        visible: !!text
        text: root.item?.text ?? ""
        color: Appearance.colour.textDim
        wrapMode: Text.WordWrap
    }

    Repeater {
        model: root.item?.lines ?? []

        StyledText {
            required property string modelData

            width: root.width
            leftPadding: Appearance.padding.normal
            rightPadding: Appearance.padding.normal
            text: modelData
            color: Appearance.colour.textFaint
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }

    Separator {
        width: parent.width
        visible: (root.item?.text || root.item?.lines.length) && actions.count > 0
    }

    Repeater {
        id: actions

        model: (root.item?.actions ?? []).concat(root.item?.rows ? [
                {
                    id: "#rows",
                    title: "Open in the launcher",
                    icon: "search"
                }
            ] : [])

        MenuRow {
            required property var modelData

            width: root.width
            icon: modelData.icon || "chevron_right"
            label: modelData.title
            onActivated: PluginStatus.press(root.item?.key ?? "", modelData.id)
        }
    }
}
