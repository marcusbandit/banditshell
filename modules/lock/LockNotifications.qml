pragma ComponentBehavior: Bound

import QtQuick
import qs.config
import qs.components
import qs.services

Column {
    id: root

    readonly property int limit: 3
    readonly property var latest: Notifications.history.slice(0, root.limit)
    readonly property int more: Notifications.history.length - root.latest.length

    visible: root.latest.length > 0
    spacing: Appearance.padding.small

    Repeater {
        model: root.latest

        delegate: Column {
            id: card

            required property var modelData

            readonly property bool showBody: !!card.modelData.body && Notifications.ruleFor(card.modelData).lock

            width: root.width

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: [card.modelData.appName, card.modelData.summary].filter(part => part).join(" · ")
                color: Appearance.colour.textDim
            }

            StyledText {
                width: parent.width
                visible: card.showBody
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: card.modelData.body
                color: Appearance.colour.textFaint
            }
        }
    }

    StyledText {
        width: parent.width
        visible: root.more > 0
        horizontalAlignment: Text.AlignHCenter
        text: `${root.more} more`
        color: Appearance.colour.textGhost
    }
}
