import QtQuick
import qs.config
import qs.components

Item {
    id: root

    property string icon: ""
    property real iconFill: 0
    property color iconColour: root.selected ? Appearance.colour.text : Appearance.colour.textDim
    property string label: ""
    property string detail: ""
    property color detailColour: Appearance.colour.textFaint
    property int detailLines: 1
    property bool selected: false
    property bool off: false
    property bool interactive: true
    property bool notice: false
    property bool flashing: false
    property real minHeight: Appearance.sizes.rowHeight
    property Component lead: null
    property Component under: null

    default property alias trailing: trail.data

    signal activated
    signal pointed

    readonly property bool hovered: hover.hovered
    readonly property bool hot: root.hovered && root.interactive && !root.off

    readonly property real gapX: Appearance.padding.normal
    readonly property real gapY: Appearance.padding.small
    readonly property real padX: Appearance.padding.normal
    readonly property real padY: Appearance.padding.small

    readonly property real leadWidth: leadSlot.visible ? leadSlot.width + root.gapX : 0
    readonly property real inner: root.width - root.padX * 2
    readonly property real trailWidth: trail.implicitWidth
    readonly property bool wrapped: root.trailWidth > 0 && root.leadWidth + 150 + root.gapX + root.trailWidth > root.inner

    readonly property real lineHeight: Math.max(words.implicitHeight, leadSlot.visible ? leadSlot.height : 0, root.wrapped ? 0 : trail.implicitHeight)

    implicitHeight: root.wrapped ? root.padY * 2 + root.lineHeight + root.gapY + trail.implicitHeight : Math.max(root.minHeight, root.padY * 2 + root.lineHeight)

    SquircleRect {
        id: plate

        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: root.notice ? Appearance.colour.accentFill : Appearance.colour.fill
        opacity: root.notice || root.hot || root.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.animation.fade.fast
            }
        }
    }

    SquircleRect {
        id: flash

        anchors.fill: parent
        radius: Appearance.rounding.normal
        color: Appearance.colour.accentFill
        opacity: 0

        SequentialAnimation {
            id: flashRun

            PropertyAction {
                target: flash
                property: "opacity"
                value: 1
            }

            PauseAnimation {
                duration: 560
            }

            NumberAnimation {
                target: flash
                property: "opacity"
                to: 0
                duration: 840
            }
        }
    }

    onFlashingChanged: if (root.flashing)
        flashRun.restart()

    HoverHandler {
        id: hover

        onHoveredChanged: if (hovered)
            root.pointed()
    }

    MouseArea {
        anchors.fill: parent
        enabled: !root.off && root.interactive
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Item {
        id: leadSlot

        x: root.padX
        y: root.padY + (root.lineHeight - height) / 2
        width: leadLoader.active ? leadLoader.width : Appearance.font.iconSize
        height: leadLoader.active ? leadLoader.height : Appearance.font.iconSize
        visible: leadLoader.active || root.icon !== ""
        opacity: root.off ? 0.4 : 1

        Icon {
            anchors.centerIn: parent
            visible: !leadLoader.active
            name: root.icon
            fill: root.iconFill
            color: root.notice ? Appearance.colour.accent : root.iconColour
        }

        Loader {
            id: leadLoader

            active: !!root.lead
            sourceComponent: root.lead
        }
    }

    Column {
        id: words

        x: root.padX + root.leadWidth
        y: root.padY + (root.lineHeight - implicitHeight) / 2
        width: root.wrapped ? root.inner - root.leadWidth : Math.max(0, root.inner - root.leadWidth - (root.trailWidth > 0 ? root.trailWidth + root.gapX : 0))
        opacity: root.off ? 0.4 : 1

        StyledText {
            width: parent.width
            text: root.label
            elide: Text.ElideRight
            color: root.notice ? Appearance.colour.accent : root.hot || root.selected ? Appearance.colour.text : Appearance.colour.textDim
            visible: root.label !== ""
        }

        StyledText {
            width: parent.width
            text: root.detail
            elide: Text.ElideRight
            wrapMode: root.detailLines > 1 ? Text.Wrap : Text.NoWrap
            maximumLineCount: root.detailLines
            color: root.notice ? Appearance.colour.textDim : root.detailColour
            visible: root.detail !== ""
        }

        Loader {
            width: parent.width
            active: !!root.under
            visible: active
            sourceComponent: root.under
        }
    }

    Row {
        id: trail

        x: root.width - root.padX - width
        y: root.wrapped ? root.padY + root.lineHeight + root.gapY : root.padY + (root.lineHeight - height) / 2
        spacing: Appearance.padding.normal
        opacity: root.off ? 0.4 : 1
        enabled: !root.off
    }
}
