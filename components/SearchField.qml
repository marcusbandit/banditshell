import QtQuick
import qs.config

FocusScope {
    id: root

    property alias text: input.text
    property alias input: input
    property string placeholder: ""
    property string icon: "search"
    property bool clearable: true
    property real zoom: 1

    readonly property real textSize: Math.round(Appearance.font.size.small * root.zoom)
    readonly property real inset: Math.round(Appearance.padding.normal * root.zoom)
    readonly property real markSize: Math.round(Appearance.font.iconSize * root.zoom)

    signal accepted

    function clear(): void {
        input.clear();
        input.forceActiveFocus();
    }

    implicitWidth: Math.round(Appearance.font.size.small * 16 * root.zoom)
    implicitHeight: Math.max(Appearance.sizes.minTarget, Math.round(Appearance.sizes.rowHeight * root.zoom))

    SquircleRect {
        anchors.fill: parent
        pill: "object"
        color: input.activeFocus ? Appearance.colour.fillStrong : Appearance.colour.fill
        stroke: input.activeFocus ? Appearance.colour.separator : "transparent"
        strokeWidth: Appearance.stroke.line
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        onPressed: input.forceActiveFocus()
    }

    Icon {
        id: mark

        x: root.inset
        anchors.verticalCenter: parent.verticalCenter
        visible: root.icon !== ""
        name: root.icon
        size: root.markSize
        color: input.activeFocus ? Appearance.colour.textDim : Appearance.colour.textFaint
    }

    TextInput {
        id: input

        x: mark.visible ? mark.x + mark.width + Math.round(Appearance.padding.small * root.zoom) : root.inset
        width: (wipe.visible ? wipe.x - Math.round(Appearance.padding.small * root.zoom) : root.width - root.inset) - x
        anchors.verticalCenter: parent.verticalCenter
        focus: true
        clip: true
        font.family: Appearance.font.family
        font.pixelSize: root.textSize
        color: Appearance.colour.text
        selectionColor: Qt.alpha(Appearance.colour.chosen, 0.3)
        selectedTextColor: Appearance.colour.text
        selectByMouse: true
        onAccepted: root.accepted()
    }

    StyledText {
        anchors.left: input.left
        anchors.right: input.right
        anchors.verticalCenter: input.verticalCenter
        visible: input.text === "" && !input.inputMethodComposing
        text: root.placeholder
        font.pixelSize: root.textSize
        color: Appearance.colour.textFaint
        elide: Text.ElideRight
    }

    Item {
        id: wipe

        x: root.width - width - Math.round(Appearance.padding.small * root.zoom)
        width: Math.round(root.markSize * 1.4)
        height: wipe.width
        anchors.verticalCenter: parent.verticalCenter
        visible: root.clearable && input.text !== ""

        SquircleRect {
            anchors.fill: parent
            pill: "object"
            color: Appearance.colour.fill
            opacity: wipeHover.hovered ? 1 : 0
        }

        Icon {
            anchors.centerIn: parent
            name: "close"
            size: Math.round(root.markSize * 0.8)
            color: Appearance.colour.textFaint
        }

        HoverHandler {
            id: wipeHover
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clear()
        }
    }
}
