import QtQuick
import qs.config

Item {
    id: root

    property string icon: ""

    property string iconSource: ""
    readonly property bool hasImage: iconSource !== "" && image.status === Image.Ready

    property Component mark: null

    property real iconSize: Appearance.font.iconSize
    property real rowHeight: Math.max(Appearance.sizes.rowHeight, iconSize + Appearance.padding.normal * 2)

    property real labelSize: Appearance.font.size.small

    property bool inlineDetail: false

    property string label: ""
    property string detail: ""
    property bool selected: false
    property bool interactive: true

    property string tip: ""

    default property alias trailing: trailingSlot.data

    signal activated

    readonly property bool hovered: interactive && pointer.containsMouse

    implicitWidth: parent ? parent.width : 0

    implicitHeight: Math.max(root.rowHeight, stack.implicitHeight + Appearance.padding.small * 2, trailingSlot.childrenRect.height + Appearance.padding.small * 2)

    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.fill
        opacity: root.hovered || root.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    HoverTip {
        host: root
        asked: pointer.containsMouse
        text: pointer.containsMouse ? root.tip || (title.truncated || detail.truncated ? (root.detail ? `${root.label} · ${root.detail}` : root.label) : "") : ""
    }

    Loader {
        id: custom

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        active: !!root.mark
        visible: active
        sourceComponent: root.mark
    }

    Icon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        visible: !!root.icon && !root.hasImage && !root.mark
        size: root.iconSize
        name: root.icon
        color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
    }

    Image {
        id: image

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        width: root.iconSize
        height: width
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio

        visible: root.hasImage && !root.mark
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    Item {
        id: stack

        anchors.left: root.mark ? custom.right : root.hasImage ? image.right : root.icon ? glyph.right : parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: trailingSlot.left
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        implicitHeight: root.inlineDetail ? Math.max(title.implicitHeight, detail.implicitHeight) : title.implicitHeight + (detail.visible ? detail.implicitHeight : 0)
        height: implicitHeight

        StyledText {
            id: title

            anchors.left: parent.left
            anchors.top: parent.top

            width: root.inlineDetail ? parent.width - detail.width - Appearance.padding.large : parent.width

            text: root.label
            font.pixelSize: root.labelSize
            color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
            elide: Text.ElideRight
        }

        StyledText {
            id: detail

            anchors.right: root.inlineDetail ? parent.right : undefined
            anchors.left: root.inlineDetail ? undefined : parent.left
            anchors.top: root.inlineDetail ? undefined : title.bottom
            anchors.verticalCenter: root.inlineDetail ? parent.verticalCenter : undefined

            width: root.inlineDetail ? Math.min(implicitWidth, parent.width * 0.4) : parent.width
            horizontalAlignment: root.inlineDetail ? Text.AlignRight : Text.AlignLeft

            visible: !!root.detail
            text: root.detail
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
            elide: Text.ElideRight
        }
    }

    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
        width: implicitWidth
        height: implicitHeight
    }

}
