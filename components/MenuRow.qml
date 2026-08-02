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

    // A LEADING SLOT for rows whose mark is neither of those: an application's
    // mark can be a glyph from a second face or a file tinted to the label
    // colour, and a row should not have to know which. Given as a Component so
    // the row can place and size it; when set it replaces the glyph and the
    // image entirely.
    property Component mark: null

    // How present the leading mark is, and how much room the row gives it. A
    // menu wants a quiet glyph beside a label; a launcher is a list you scan by
    // icon, and the same size that reads as tidy in a menu reads as cramped
    // there. Derived from each other, so asking for a bigger icon gives it room
    // rather than jamming it into the old row.
    property real iconSize: Appearance.font.iconSize
    property real rowHeight: Math.max(Appearance.sizes.rowHeight, iconSize + Appearance.padding.normal * 2)

    // Which of the three sizes the label is set in. A menu row is a line in a
    // list of settings and takes the body size; a launcher row is the thing the
    // whole window exists to show you, and takes a bigger one. Still the same
    // three sizes: this picks one, it does not invent a fourth.
    property real labelSize: Appearance.font.size.small

    // Detail BESIDE the label rather than under it.
    //
    // Stacked is right for a menu, where a row is a setting and its explanation
    // and there is no width to spare. A launcher has width to spare and hundreds
    // of rows, so stacking doubles the height of every one of them to carry a
    // line nobody reads until they are already unsure. Beside and right-aligned
    // it costs no height, spends the width on something true, and turns the list
    // into two columns that can be scanned independently.
    property bool inlineDetail: false

    property string label: ""
    property string detail: ""
    property bool selected: false
    property bool interactive: true

    // Anything declared inside sits on the right, vertically centred.
    default property alias trailing: trailingSlot.data

    signal activated

    readonly property bool hovered: interactive && pointer.containsMouse

    implicitWidth: parent ? parent.width : 0

    // The row is as tall as the tallest thing in it, and the LABELS are one of
    // those things. They were missing from this maximum: a label and a detail
    // used to be 24px and 12px of line box, which fitted inside the 44px floor
    // whatever happened, so nothing noticed. Both are 18px type now, 48px of
    // line box together, and a two-line row grew straight through the bottom of
    // its own background and into the row beneath it.
    implicitHeight: Math.max(root.rowHeight, stack.implicitHeight + Appearance.padding.small * 2, trailingSlot.childrenRect.height + Appearance.padding.small * 2)

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

        // Squared on the GLYPH's box, so a row with an image and a row with a
        // glyph put their text in the same place and the column of labels stays
        // straight whatever mix of the two a list happens to contain.
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

        anchors.left: root.mark ? custom.right : root.icon || root.hasImage ? glyph.right : parent.left
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
            // Yields to the detail beside it, never the other way round: the
            // name is what is being looked for, so it keeps whatever it needs
            // and the description takes what is left.
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

            // Capped, so a wordy description cannot squeeze the name it belongs
            // to down to an ellipsis.
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
