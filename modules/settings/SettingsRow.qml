import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""
    property string label: ""

    property string detail: ""

    property string value: ""

    property bool interactive: true
    property bool selected: false

    property bool chevron: false

    default property alias trailing: trailingSlot.data

    signal activated

    readonly property bool hovered: root.interactive && pointer.containsMouse

    readonly property bool first: root.Positioner.isFirstItem
    readonly property bool last: root.Positioner.isLastItem

    readonly property real inset: Appearance.padding.normal
    readonly property real gap: Appearance.padding.small

    readonly property real trailingWidth: trailingSlot.childrenRect.width
    readonly property bool stacked: root.trailingWidth > 0 && root.trailingWidth > root.width * 0.4

    readonly property real textX: root.inset + (root.icon ? Appearance.font.iconSize + root.inset : 0)
    readonly property real textWidth: root.width - root.textX - root.inset - (root.stacked ? 0 : (root.trailingWidth > 0 ? root.trailingWidth + root.inset : 0) + (root.chevron ? Appearance.font.iconSize + root.gap : 0))

    readonly property bool valueBeside: root.value !== "" && valueText.implicitWidth <= root.textWidth * 0.5

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(Appearance.sizes.rowHeight, body.implicitHeight + root.gap * 2 + (root.stacked ? trailingSlot.childrenRect.height + root.gap : 0), root.stacked ? 0 : trailingSlot.childrenRect.height + root.gap * 2)

    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        topLeftRadius: root.first ? radius : 0
        topRightRadius: root.first ? radius : 0
        bottomLeftRadius: root.last ? radius : 0
        bottomRightRadius: root.last ? radius : 0
        color: root.selected ? Appearance.colour.fillStrong : Appearance.colour.fill
        opacity: root.hovered || root.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Rectangle {
        visible: !root.first
        x: root.textX
        width: parent.width - x
        height: Appearance.font.stem
        color: Appearance.colour.separator
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Icon {
        x: root.inset
        y: root.gap + (title.implicitHeight - height) / 2
        visible: !!root.icon
        name: root.icon
        color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
    }

    Column {
        id: body

        x: root.textX
        y: root.gap
        width: root.textWidth

        Item {
            width: parent.width
            height: Math.max(title.implicitHeight, root.valueBeside ? valueText.implicitHeight : 0)

            StyledText {
                id: title

                width: parent.width - (root.valueBeside ? valueText.width + root.inset : 0)
                text: root.label
                wrapMode: Text.Wrap
                color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
            }

            StyledText {
                id: valueText

                anchors.right: parent.right
                visible: root.valueBeside
                text: root.value
                color: Appearance.colour.textFaint
            }
        }

        StyledText {
            width: parent.width
            visible: root.value !== "" && !root.valueBeside
            text: root.value
            wrapMode: Text.Wrap
            color: Appearance.colour.textFaint
        }

        StyledText {
            width: parent.width
            visible: !!root.detail
            text: root.detail
            wrapMode: Text.Wrap
            color: Appearance.colour.textFaint
        }
    }

    Icon {
        anchors.right: parent.right
        anchors.rightMargin: root.inset
        anchors.verticalCenter: parent.verticalCenter
        visible: root.chevron
        name: "chevron_right"
        color: Appearance.colour.textFaint
    }

    Item {
        id: trailingSlot

        x: root.stacked ? root.textX : root.width - root.inset - (root.chevron ? Appearance.font.iconSize + root.gap : 0) - width
        y: root.stacked ? body.y + body.implicitHeight + root.gap : (root.height - height) / 2
        width: childrenRect.width
        height: childrenRect.height
    }
}
