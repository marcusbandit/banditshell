pragma ComponentBehavior: Bound

import QtQuick
import qs.config

Column {
    id: root

    property var lines: []
    property color hue: Appearance.colour.textDim
    property bool major: false
    property real unreadDot: 6

    spacing: Appearance.padding.hair

    Repeater {
        model: root.lines

        delegate: UpdateChangeLine {
            required property var modelData

            width: root.width
            text: modelData.text
            hue: root.hue
            major: root.major
            unread: modelData.unread === true
            unreadDot: root.unreadDot
        }
    }
}
