import QtQuick
import qs.config
import qs.components
import qs.services

Item {
    id: root

    required property var holder
    property real contentLead: Appearance.padding.card
    property bool joinedAbove: false
    property bool joinedBelow: false

    signal chosen

    readonly property real inset: Appearance.padding.small
    readonly property real seam: Appearance.padding.hair / 2
    readonly property real markSize: Appearance.sizes.notificationBadge
    readonly property real pad: Appearance.padding.normal

    implicitHeight: Math.max(root.markSize, words.implicitHeight) + root.pad * 2

    SquircleRect {
        x: root.inset
        width: root.width - root.inset * 2
        height: root.height
        topLeftRadius: root.joinedAbove ? root.seam : Appearance.rounding.normal
        topRightRadius: root.joinedAbove ? root.seam : Appearance.rounding.normal
        bottomLeftRadius: root.joinedBelow ? root.seam : Appearance.rounding.normal
        bottomRightRadius: root.joinedBelow ? root.seam : Appearance.rounding.normal
        color: area.containsMouse && root.holder?.kind === "mic" ? Appearance.colour.fill : Appearance.colour.tile
    }

    AppMark {
        id: mark

        x: root.contentLead
        anchors.verticalCenter: parent.verticalCenter
        spec: root.holder?.spec ?? ""
        fallback: root.holder?.icon ?? "apps"
        size: root.markSize
        color: Appearance.colour.text
        fits: AppIcons.fits
    }

    Column {
        id: words

        anchors.left: mark.right
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: parent.right
        anchors.rightMargin: root.contentLead
        anchors.verticalCenter: parent.verticalCenter
        spacing: Appearance.padding.hair

        StyledText {
            width: parent.width
            text: root.holder?.name ?? ""
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
            text: root.holder?.line ?? ""
            color: Appearance.colour.textDim
            font.pixelSize: Appearance.font.size.small
            elide: Text.ElideRight
        }
    }

    MouseArea {
        id: area

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.holder?.kind === "mic" ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (root.holder?.kind === "mic")
            root.chosen()
    }
}
