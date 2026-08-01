import QtQuick
import qs.config

// One line in a menu: an icon, a label, and whatever the row is actually for.
//
// The whole row is the hit target, not the icon. A 16px glyph is a bad thing to
// ask anyone to hit, and rows that only respond in part of themselves feel
// broken in a way that is hard to name.
Item {
    id: root

    property string icon: ""
    property string label: ""
    property string detail: ""
    property bool selected: false
    property bool interactive: true

    // Anything declared inside sits on the right, vertically centred.
    default property alias trailing: trailingSlot.data

    signal activated

    readonly property bool hovered: interactive && pointer.containsMouse

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(Appearance.sizes.rowHeight, trailingSlot.childrenRect.height + Appearance.padding.small * 2)

    G2Rect {
        anchors.fill: parent
        radius: Appearance.rounding.small
        color: Appearance.colour.fill
        opacity: root.hovered || root.selected ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.anim.fast
            }
        }
    }

    Icon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        visible: !!root.icon
        name: root.icon
        color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
    }

    Column {
        anchors.left: root.icon ? glyph.right : parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.right: trailingSlot.left
        anchors.rightMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        spacing: 0

        StyledText {
            width: parent.width
            text: root.label
            color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
            elide: Text.ElideRight
        }

        StyledText {
            width: parent.width
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

    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
