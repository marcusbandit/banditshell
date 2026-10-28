import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""

    property string iconSource: ""
    property string glyph: ""
    readonly property bool hasImage: iconSource !== "" && image.status === Image.Ready

    property Component mark: null

    property real iconSize: Appearance.font.iconSize
    property real rowHeight: Math.max(Appearance.sizes.rowHeight, iconSize + Appearance.padding.normal * 2)

    property real labelSize: Appearance.font.size.small

    property bool inlineDetail: false

    property string label: ""
    property string detail: ""
    property var columns: []
    property real trailingRoom: 0
    property bool selected: false
    property bool interactive: true

    property string tip: ""

    default property alias trailing: trailingSlot.data

    property bool askable: false

    signal activated
    signal asked(real x, real y)

    readonly property bool keyable: root.interactive

    function press(): void {
        root.activated();
    }

    readonly property bool held: root.Window.activeFocusItem?.keyable === true

    readonly property bool hovered: interactive && pointer.containsMouse && !root.held

    implicitWidth: parent ? parent.width : 0

    implicitHeight: Math.max(root.rowHeight, stack.implicitHeight + Appearance.padding.small * 2, trailingSlot.childrenRect.height + Appearance.padding.small * 2)

    SquircleRect {
        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: plate.value
    }

    FocusMark {
        shown: root.activeFocus
    }

    FollowColour {
        id: plate

        target: root.selected ? Appearance.colour.fillStrong : root.hovered ? Appearance.colour.fill : "transparent"
        speed: Appearance.animation.revealSpeed
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: root.askable ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onClicked: mouse => mouse.button === Qt.RightButton ? root.asked(mouse.x, mouse.y) : root.activated()
    }

    HoverTip {
        host: root
        asked: pointer.containsMouse && !root.held
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

        visible: (!!root.icon || !!root.glyph) && !root.hasImage && !root.mark
        width: root.glyph ? root.iconSize : implicitWidth
        size: root.iconSize
        name: root.icon
        glyph: root.glyph
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

        anchors.left: root.mark ? custom.right : root.hasImage ? image.right : root.icon || root.glyph ? glyph.right : parent.left
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

            width: root.columns.length ? Math.min(parent.width, fields.x - stack.x - Appearance.padding.large) : root.inlineDetail ? parent.width - detail.width - Appearance.padding.large : parent.width

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

            width: root.inlineDetail ? Math.min(implicitWidth, Math.max(parent.width * 0.3, parent.width - title.implicitWidth - Appearance.padding.large)) : parent.width
            horizontalAlignment: root.inlineDetail ? Text.AlignRight : Text.AlignLeft

            visible: !!root.detail && !root.columns.length
            text: root.detail
            font.pixelSize: Appearance.font.size.small
            color: Appearance.colour.textFaint
            elide: Text.ElideRight
        }
    }

    FontMetrics {
        id: digits

        font.family: Appearance.font.family
        font.pixelSize: Appearance.font.size.small
    }

    Row {
        id: fields

        anchors.right: parent.right
        anchors.rightMargin: Appearance.padding.normal + root.trailingRoom
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.large
        visible: root.columns.length > 0

        Repeater {
            model: root.columns

            delegate: StyledText {
                id: field

                required property var modelData

                width: Math.ceil(digits.advanceWidth("0") * (field.modelData.chars ?? field.modelData.text.length))
                opacity: fields.x + field.x + field.width <= trailingSlot.x - Appearance.padding.normal ? 1 : 0
                text: field.modelData.text
                font.pixelSize: Appearance.font.size.small
                color: field.modelData.tone === "lit" ? Appearance.colour.accent : field.modelData.tone === "dim" ? Appearance.colour.textGhost : Appearance.colour.textFaint
                elide: Text.ElideRight
            }
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
