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

    // A real image for the leading slot, which wins over the glyph when it
    // resolves. An application's own icon is how it is recognised; making every
    // app in the launcher wear the same generic mark throws that away and turns
    // the list into text that has to be read.
    property string iconSource: ""
    readonly property bool hasImage: iconSource !== "" && image.status === Image.Ready

    // How present the leading mark is, and how much room the row gives it. A
    // menu wants a quiet glyph beside a label; a launcher is a list you scan by
    // icon, and the same size that reads as tidy in a menu reads as cramped
    // there. Derived from each other, so asking for a bigger icon gives it room
    // rather than jamming it into the old row.
    property real iconSize: Appearance.font.iconSize
    property real rowHeight: Math.max(Appearance.sizes.rowHeight, iconSize + Appearance.padding.normal * 2)

    property string label: ""
    property string detail: ""
    property bool selected: false
    property bool interactive: true

    // Anything declared inside sits on the right, vertically centred.
    default property alias trailing: trailingSlot.data

    signal activated

    readonly property bool hovered: interactive && pointer.containsMouse

    implicitWidth: parent ? parent.width : 0
    implicitHeight: Math.max(root.rowHeight, trailingSlot.childrenRect.height + Appearance.padding.small * 2)

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

    // DECLARED FIRST, deliberately. Declaration order is input order in QML and
    // there is no z anywhere in this shell, so a catch-all that comes last sits
    // on top of the row's own trailing controls and eats their clicks. The
    // Bluetooth "forget" button connected the device instead of forgetting it,
    // and every notification action button dismissed the notification instead of
    // invoking the action. A row-wide target has to be UNDER what it contains.
    MouseArea {
        id: pointer

        anchors.fill: parent
        enabled: root.interactive
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Icon {
        id: glyph

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        visible: !!root.icon && !root.hasImage
        size: root.iconSize
        name: root.icon
        color: root.selected ? Appearance.colour.text : Appearance.colour.textDim
    }

    Image {
        id: image

        anchors.left: parent.left
        anchors.leftMargin: Appearance.padding.normal
        anchors.verticalCenter: parent.verticalCenter

        // Squared on the GLYPH's box, so a row with an image and a row with a
        // glyph put their text in the same place and the column of labels stays
        // straight whatever mix of the two a list happens to contain.
        width: root.iconSize
        height: width
        sourceSize.width: width * Screen.devicePixelRatio
        sourceSize.height: height * Screen.devicePixelRatio

        visible: root.hasImage
        source: root.iconSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
    }

    Column {
        anchors.left: root.icon || root.hasImage ? glyph.right : parent.left
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

}
